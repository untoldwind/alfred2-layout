#!/usr/bin/python

import sys
from AppKit import *

info = NSBundle.mainBundle().infoDictionary()
info["LSBackgroundOnly"] = "1"

from Foundation import *
from ScriptingBridge import *

class Rect:
	def __init__(self, left, top, right, bottom):
		self.left = left
		self.top = top
		self.right = right
		self.bottom = bottom

	def width(self):
		return self.right - self.left

	def height(self):
		return self.bottom - self.top

	def contains(self, position):
		return position.x >= self.left and position.y >= self.top and position.x <= self.right and position.y <= self.bottom

	def intersects(self, other):
		return other.left <= self.right and other.right >= self.left and other.top <= self.bottom and other.bottom >= self.top

	def intersection(self, other):
		return Rect(max(self.left, other.left), max(self.top, other.top), min(self.right, other.right), min(self.bottom, other.bottom)) 

	def area(self):
		return self.width()**2 + self.height()**2

	def __repr__(self):
		return "Rect(%d, %d, %d, %d)" % (self.left, self.top, self.right, self.bottom)

def setWindowBounds(process, window, bounds):
	window.propertyWithCode_(0x706f736e).setTo_([0, 0])
	window.propertyWithCode_(0x7074737a).setTo_([bounds.width(), bounds.height()])
	window = process.attributes().objectWithName_("AXMainWindow").value().get()
	window.propertyWithCode_(0x706f736e).setTo_([bounds.left, bounds.top])

commandAndTarget = sys.argv[1].split(':')
if len(commandAndTarget) == 2:
	command = commandAndTarget[0]
	targetArg = commandAndTarget[1].split(',')
else:
	command = 'set'
	targetArg = commandAndTarget[0].split(',')

screens = []

# For some reason NSScreen's origin is at left bottom, while windows work with left top
mainHeight = NSScreen.mainScreen().frame().size.height
for screen in NSScreen.screens():
	visibleFrame = screen.visibleFrame()
	screens.append(
		Rect(visibleFrame.origin.x, mainHeight - visibleFrame.size.height - visibleFrame.origin.y, 
			visibleFrame.origin.x + visibleFrame.size.width, mainHeight - visibleFrame.origin.y))

systemevents = SBApplication.applicationWithBundleIdentifier_("com.apple.systemevents")

frontmostPredicate = NSPredicate.predicateWithFormat_("frontmost == true")
frontmost = systemevents.processes().filteredArrayUsingPredicate_(frontmostPredicate)[0]
window = frontmost.attributes().objectWithName_("AXMainWindow").value().get()

properties = window.properties()
appRect = Rect(properties['position'][0], properties['position'][1], properties['position'][0] + properties['size'][0], properties['position'][1] + properties['size'][1])
appScreens = [s for s in screens if s.intersects(appRect)]
appScreens = sorted(appScreens, key=lambda s: s.intersection(appRect).area())
appScreen = next(reversed(appScreens))

if command == 'resize':
	target = Rect(0,0,0,0)
	target.left = appRect.left - appScreen.width() * float(targetArg[0])
	target.top = appRect.top - appScreen.height() * float(targetArg[1])
	target.right = appRect.right + appScreen.width() * float(targetArg[2])
	target.bottom = appRect.bottom + appScreen.height() * float(targetArg[3])
	target = target.intersection(appScreen)

	setWindowBounds(frontmost, window, target)
elif command == 'resizeAll':
	# Single value => resize in all directions with sticks screen borders
	resize_x = appScreen.width() * float(targetArg[0])
	resize_y = appScreen.height() * float(targetArg[0])
	target = Rect(0,0,0,0)
	if abs(appRect.left - appScreen.left) < 0.01 * appScreen.width():
		if abs(appRect.right - appScreen.right) < 0.01 * appScreen.width():
			target.left = appScreen.left
			target.right = appRect.right
		else:
			target.left = appScreen.left
			target.right = appRect.right + resize_x
	elif abs(appRect.right - appScreen.right) < 0.01 * appScreen.width():
		target.left = appRect.left - resize_x
		target.right = appScreen.right
	else:
		target.left = appRect.left - resize_x * 0.5
		target.right = appRect.right + resize_x * 0.5
	if abs(appRect.top - appScreen.top) < 0.01 * appScreen.height():
		if abs(appRect.bottom - appScreen.bottom) < 0.01 * appScreen.height():
			target.top = appScreen.top
			target.bottom = appRect.bottom
		else:
			target.top = appScreen.top
			target.bottom = appRect.bottom + resize_y
	elif abs(appRect.bottom - appScreen.bottom) < 0.01 * appScreen.height():
		target.top = appRect.top - resize_y
		target.bottom = appScreen.bottom
	else:
		target.top = appRect.top - resize_y * 0.5
		target.bottom = appRect.bottom + resize_y * 0.5
	target = target.intersection(appScreen)

	setWindowBounds(frontmost, window, target)	
elif command == 'move':
	target_x = appScreen.left + appScreen.width() * float(targetArg[0])
	target_y = appScreen.top + appScreen.height() * float(targetArg[1])
	pos_x = target_x - appRect.width() * 0.5
	pos_y = target_y - appRect.height() * 0.5
	if pos_x < appScreen.left:
		pos_x = appScreen.left
	if pos_y < appScreen.top:
		pos_y = appScreen.top
	if pos_x + appRect.width() > appScreen.right:
		pos_x = appScreen.right - appRect.width()
	if pos_y + appRect.height() > appScreen.bottom:
		pos_y = appScreen.bottom - appRect.height()
	window.setPosition_([pos_x, pos_y])
elif command == 'set':
	target = Rect(
		appScreen.left + appScreen.width() * float(targetArg[0]), 
		appScreen.top + appScreen.height() * float(targetArg[1]), 
		appScreen.left + appScreen.width() * float(targetArg[2]), 
		appScreen.top + appScreen.height() * float(targetArg[3]))

	setWindowBounds(frontmost, window, target)
