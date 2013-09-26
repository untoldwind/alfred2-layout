#!/usr/bin/python

import sys
from AppKit import *
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
target = Rect(float(targetArg[0]), float(targetArg[1]), float(targetArg[2]), float(targetArg[3]))

screens = []

# For some reason NSScreen's origin is at left bottom, while windows work with left top
mainHeight = NSScreen.mainScreen().frame().size.height
for screen in NSScreen.screens():
	visibleFrame = screen.visibleFrame()
	screens.append(
		Rect(visibleFrame.origin.x, mainHeight - visibleFrame.size.height - visibleFrame.origin.y, 
			visibleFrame.origin.x + visibleFrame.size.width, mainHeight - visibleFrame.origin.y))

appBundleId = next(app for app in NSWorkspace.sharedWorkspace().runningApplications() if app.isActive()).bundleIdentifier()

blacklist = ["com.adiumX.adiumX"]

app = SBApplication.applicationWithBundleIdentifier_(appBundleId)

if not appBundleId in blacklist and "windows" in dir(app) and callable(getattr(app, "windows")):
	window = app.windows()[0]
	bounds = window.bounds()
	appRect = Rect(bounds.origin.x, bounds.origin.y, bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height)
	appScreens = [s for s in screens if s.intersects(appRect)]
	appScreens = sorted(appScreens, key=lambda s: s.intersection(appRect).area())
	appScreen = next(reversed(appScreens))
	window.setBounds_([[appScreen.left + appScreen.width() * target.left, appScreen.top + appScreen.height() * target.top], [appScreen.width() * target.width(), appScreen.height() * target.height()]])
else:
	systemevents = SBApplication.applicationWithBundleIdentifier_("com.apple.systemevents")

	for process in systemevents.processes():
		if process.frontmost():
			window = next((win for win in process.windows() if win.properties()["subrole"] == "AXStandardWindow"), process.windows()[0])
			properties = window.properties()
			appRect = Rect(properties['position'][0], properties['position'][1], properties['position'][0] + properties['size'][0], properties['position'][1] + properties['size'][1])
			appScreens = [s for s in screens if s.intersects(appRect)]
			appScreens = sorted(appScreens, key=lambda s: s.intersection(appRect).area())
			appScreen = next(reversed(appScreens))

			window.setProperties_({'position':[0,0]})
			window.setProperties_({'size':[appScreen.width() * target.width(), appScreen.height() * target.height()]})
			window.setProperties_({'position':[appScreen.left + appScreen.width() * target.left, appScreen.top + appScreen.height() * target.top]})
			break