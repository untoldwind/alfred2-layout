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

targetArg = sys.argv[1].split(",")

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

if len(targetArg) == 2:
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
elif len(targetArg) == 4:
	target = Rect(float(targetArg[0]), float(targetArg[1]), float(targetArg[2]), float(targetArg[3]))

	window.propertyWithCode_(0x706f736e).setTo_([0, 0])
	window.propertyWithCode_(0x7074737a).setTo_([appScreen.width() * target.width(), appScreen.height() * target.height()])
	window = frontmost.attributes().objectWithName_("AXMainWindow").value().get()
	window.propertyWithCode_(0x706f736e).setTo_([appScreen.left + appScreen.width() * target.left, appScreen.top + appScreen.height() * target.top])
