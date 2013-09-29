#!/usr/bin/ruby

require "osx/cocoa"
include OSX
OSX.require_framework 'ScriptingBridge'

class Rect
	attr_reader :left, :top, :right, :bottom

	def initialize(left, top, right, bottom)
		@left = left
		@top = top
		@right = right
		@bottom = bottom
	end

	def width
		@right - @left
	end

	def height
		@bottom - @top
	end

	def intersects(other)
		other.left <= @right && other.right >= @left && other.top <= @bottom && other.bottom >= @top
	end

	def area
		width()**2 + height()**2
	end

	def to_s()
		"Rect(#{@left}, #{@top}, #{@right}, #{@bottom})"
	end
end

targetArg = ARGV[0].split(',')
target = Rect.new(targetArg[0].to_f, targetArg[1].to_f, targetArg[2].to_f, targetArg[3].to_f)

screens = []
mainHeight = OSX::NSScreen.mainScreen().frame().size.height
OSX::NSScreen.screens().each do |screen|
	visibleFrame = screen.visibleFrame()
	screens << Rect.new(visibleFrame.origin.x, mainHeight - visibleFrame.size.height - visibleFrame.origin.y,
						visibleFrame.origin.x + visibleFrame.size.width, mainHeight - visibleFrame.origin.y)
end

systemevents = OSX::SBApplication.applicationWithBundleIdentifier_("com.apple.systemevents")
systemevents.processes().select { |process| process.frontmost() }.each do |process|
	windows = process.windows().select { |win| win.properties()["subrole"] == "AXStandardWindow" }
	if windows.empty?
		window = process.windows().first
	else
		window = windows.first
	end
	properties = window.properties()
	appRect = Rect.new(properties['position'][0].to_i, properties['position'][1].to_i, 
					   properties['position'][0].to_i + properties['size'][0].to_i, properties['position'][1].to_i + properties['size'][1].to_i)
	appScreens = screens.select { |screen| screen.intersects(appRect) }
	appScreens = appScreens.sort { |a, b| a.intersection(appRect).area <=> b.intersection(appRect).area }
	appScreen = appScreens.first

	window.setProperties_({'position' => [0,0]})
	window.setProperties_({'size' => [appScreen.width() * target.width(), appScreen.height() * target.height()]})
	window.setProperties_({'position' => [appScreen.left + appScreen.width() * target.left, appScreen.top + appScreen.height() * target.top]})
end
