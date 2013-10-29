#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby

require "osx/cocoa"
include OSX
OSX.require_framework 'ScriptingBridge'

class Rect
	attr_accessor :left, :top, :right, :bottom

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

def setWindowBounds(process, window, screen, bounds)
	# these properties can be found in /System/Library/CoreServices/System Events.app/Contents/Resources/SystemEvents.sdef
	# there is a little issue if the window is too big (i.e. partly outside screen), therefore we first move to 0,0
	windowPosition = window.propertyWithCode_(0x706f736e) # this is "posn" in hexcode
	windowSize = window.propertyWithCode_(0x7074737a) # this is "ptsz" in hexcode
	windowPosition.setTo_([screen.left, screen.top])
	windowSize.setTo_([bounds.width, bounds.height])

	# After this we do it anew since there might be some events swallowed otherwide
	window = process.attributes().objectWithName_("AXMainWindow").value().get()
	windowPosition = window.propertyWithCode_(0x706f736e) # this is "posn" in hexcode
	windowPosition.setTo_([bounds.left, bounds.top])
end

commandAndTarget = ARGV[0].split(':')
if commandAndTarget.size == 2
	command = commandAndTarget[0]
	targetArg = commandAndTarget[1].split(',')
else
	command = "set"
	targetArg = commandAndTarget[0].split(',')
end

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

case command
when 'resize'
	target = appRect.clone
	target.left = appRect.left - appScreen.width * targetArg[0].to_f
	target.top = appRect.top - appScreen.height * targetArg[1].to_f
	target.right = appRect.right + appScreen.width * targetArg[2].to_f
	target.bottom = appRect.bottom + appScreen.height * targetArg[3].to_f
	target = target.intersection(appScreen)

	setWindowBounds(frontmost, window, appScreen, target)
when 'resizeAll'
	# Single value => resize in all directions with sticks screen borders
	resize_x = appScreen.width * targetArg[0].to_f
	resize_y = appScreen.height * targetArg[0].to_f
	target = appRect.clone
	if (appRect.left - appScreen.left).abs < 0.01 * appScreen.width
		if (appRect.right - appScreen.right).abs < 0.01 * appScreen.width
			target.left = appScreen.left
			target.right = appRect.right
		else
			target.left = appScreen.left
			target.right = appRect.right + resize_x
		end
	elsif (appRect.right - appScreen.right).abs < 0.01 * appScreen.width
		target.left = appRect.left - resize_x
		target.right = appScreen.right
	else
		target.left = appRect.left - resize_x * 0.5
		target.right = appRect.right + resize_x * 0.5
	end
	if (appRect.top - appScreen.top).abs < 0.01 * appScreen.height
		if (appRect.bottom - appScreen.bottom).abs < 0.01 * appScreen.height
			target.top = appScreen.top
			target.bottom = appRect.bottom
		else
			target.top = appScreen.top
			target.bottom = appRect.bottom + resize_y
		end
	elsif (appRect.bottom - appScreen.bottom).abs < 0.01 * appScreen.height
		target.top = appRect.top - resize_y
		target.bottom = appScreen.bottom
	else
		target.top = appRect.top - resize_y * 0.5
		target.bottom = appRect.bottom + resize_y * 0.5
	end
	target = target.intersection(appScreen)

	setWindowBounds(frontmost, window, appScreen, target)
when 'move'
	# Two values => Move window to coords (center_x, center_y), prevent window from moving out of screen
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
when 'set'
	# Four values => Move and resize window to coords (left, top, right, bottom)
	target = Rect.new(
		appScreen.left + appScreen.width * targetArg[0].to_f, 
		appScreen.top + appScreen.height * targetArg[1].to_f, 
		appScreen.left + appScreen.width * targetArg[2].to_f, 
		appScreen.top + appScreen.height * targetArg[3].to_f)

	setWindowBounds(frontmost, window, appScreen, target)
end
