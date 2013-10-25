#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby

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

	def intersection(other)
		Rect.new([@left, other.left].max, [@top, other.top].max, [@right, other.right].min, [@bottom, other.bottom].min)
	end

	def area
		width()**2 + height()**2
	end

	def to_s()
		"Rect(#{@left}, #{@top}, #{@right}, #{@bottom})"
	end
end

targetArg = ARGV[0].split(',')

screens = []
mainHeight = OSX::NSScreen.mainScreen().frame().size.height
OSX::NSScreen.screens().each do |screen|
	visibleFrame = screen.visibleFrame()
	screens << Rect.new(visibleFrame.origin.x, mainHeight - visibleFrame.size.height - visibleFrame.origin.y,
						visibleFrame.origin.x + visibleFrame.size.width, mainHeight - visibleFrame.origin.y)
end
systemevents = OSX::SBApplication.applicationWithBundleIdentifier_("com.apple.systemevents")

frontmostPredicate = OSX::NSPredicate.predicateWithFormat("frontmost == true")
frontmost = systemevents.processes().filteredArrayUsingPredicate_(frontmostPredicate).first
window = frontmost.attributes().objectWithName_("AXMainWindow").value().get()
properties = window.properties()
appRect = Rect.new(properties['position'][0].to_i, properties['position'][1].to_i, 
				   properties['position'][0].to_i + properties['size'][0].to_i, properties['position'][1].to_i + properties['size'][1].to_i)
appScreens = screens.select { |screen| screen.intersects(appRect) }
appScreens = appScreens.sort { |a, b| b.intersection(appRect).area <=> a.intersection(appRect).area }
appScreen = appScreens.first


case targetArg.size
when 2
	target_x = appScreen.left + appScreen.width * targetArg[0].to_f
	target_y = appScreen.top + appScreen.height * targetArg[1].to_f
	pos_x = target_x - appRect.width * 0.5
	pos_y = target_y - appRect.height * 0.5
	if pos_x < appScreen.left
		pos_x = appScreen.left
	end
	if pos_y < appScreen.top
		pos_y = appScreen.top
	end
	if pos_x + appRect.width > appScreen.right
		pos_x = appScreen.right - appRect.width
	end
	if pos_y + appRect.height > appScreen.bottom
		pos_y = appScreen.bottom - appRect.height
	end
	window.setPosition_([pos_x, pos_y])
when 4
	target = Rect.new(targetArg[0].to_f, targetArg[1].to_f, targetArg[2].to_f, targetArg[3].to_f)

	# these properties can be found in /System/Library/CoreServices/System Events.app/Contents/Resources/SystemEvents.sdef
	# there is a little issue if the window is too big (i.e. partly outside screen), therefore we first move to 0,0
	windowPosition = window.propertyWithCode_(0x706f736e) # this is "posn" in hexcode
	windowSize = window.propertyWithCode_(0x7074737a) # this is "ptsz" in hexcode
	windowPosition.setTo_([0, 0])
	windowSize.setTo_([appScreen.width * target.width, appScreen.height * target.height])

	# After this we do it anew since there might be some events swallowed otherwide
	window = frontmost.attributes().objectWithName_("AXMainWindow").value().get()
	windowPosition = window.propertyWithCode_(0x706f736e) # this is "posn" in hexcode
	windowPosition.setTo_([appScreen.left + appScreen.width * target.left, appScreen.top + appScreen.height * target.top])
end
