#!/usr/bin/perl

use strict;
use feature 'switch';
use Foundation;
use Sys::Syslog qw(:standard :macros);

my $debug = 0;

$debug && Sys::Syslog::setlogsock("unix"); 
$debug && openlog("Alfred2 Layout", "ndelay,pid", LOG_USER);

$debug && syslog(LOG_NOTICE, "Starting");

# Load the Scripting-Bridge
@NSScreen::ISA = @SBApplication::ISA = qw(PerlObjCBridge);

NSBundle->bundleWithPath_(
    '/System/Library/Frameworks/ScriptingBridge.framework' # Loads AppKit too
)->load;

# Define helper class: Rect

package Rect;
sub new {
	my $class = shift;
	my $self = {
		_left => shift,
		_top => shift,
		_right => shift,
		_bottom => shift
	};
	bless $self, $class;
	$self;
}

sub intersects {
	my ($self, $other) = @_;
	$other->{_left} <= $self->{_right} && $other->{_right} >= $self->{_left} && $other->{_top} <= $self->{_bottom} && $other->{_bottom} >= $self->{_top};
}

sub intersection {
	my ($self, $other) = @_;
	Rect->new(max($self->{_left}, $other->{_left}), max($self->{_top}, $other->{_top}), min($self->{_right}, $other->{_right}), min($self->{_bottom}, $other->{_bottom}));
}

sub left {
	my $self = shift;
	$self->{_left};
}

sub right {
	my $self = shift;
	$self->{_right};
}

sub top {
	my $self = shift;
	$self->{_top};
}

sub bottom {
	my $self = shift;
	$self->{_bottom};
}

sub width {
	my $self = shift;
	$self->{_right} - $self->{_left};
}

sub height {
	my $self = shift;
	$self->{_bottom} - $self->{_top};
}

sub area {
	my $self = shift;
	$self->width ** 2 + $self->height ** 2;
}

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

# Helper class ObjCStruct to handle NSPoint, NSSize and NSRect
# Quite an ugly mess actually

package ObjCStruct;
my %heap; # Used to maintain references to temp perl data structures

sub Pointer  () { 'L!' }
sub CGFloat  () { 'd'  }
sub CGFloatS () { length(pack CGFloat,'0') }

sub unpack {
    my ($obj, $struct) = @_;
    my $int_ptr = ref($obj) ? $$obj : $$struct;
    my $pac_ptr = pack($obj->Pointer, $int_ptr);
    my $mem = unpack($obj->_ptr_pack_str, $pac_ptr);
    return unpack($obj->_mem_pack_str, $mem);
}

sub new {
    my ($pack, @vals) = @_;
    my $mem = pack($pack->_mem_pack_str, @vals);
    my $pac_ptr = pack($pack->_ptr_pack_str, $mem);
    my $int_ptr = CORE::unpack($pack->Pointer, $pac_ptr);
    $heap{$int_ptr} = $mem;
    bless my $obj = \$int_ptr, ref($pack) || $pack;
    return $obj;
}
    
sub DESTROY { delete $heap{${$_[0]}} }

package ObjCStruct::NSPoint;
# typedef struct _NSPoint { CGFloat x; CGFloat y; } NSPoint;
use base qw(ObjCStruct);
sub _mem_pack_str { $_[0]->CGFloat.'2' }
sub _ptr_pack_str { 'P'.$_[0]->CGFloatS*2 }

package ObjCStruct::NSSize;
# typedef struct _NSSize { CGFloat width; CGFloat height; } NSSize;
use base qw(ObjCStruct);
sub _mem_pack_str { $_[0]->CGFloat.'2' }
sub _ptr_pack_str { 'P'.$_[0]->CGFloatS*2 }

package ObjCStruct::NSRect;
# typedef struct _NSRect { NSPoint origin; NSSize size; } NSRect;
use base qw(ObjCStruct);
sub _mem_pack_str { $_[0]->CGFloat.'4' }
sub _ptr_pack_str { 'P'.$_[0]->CGFloatS*4 }


# And here comes the actual layouting stuff

package main;

# Find the main window of a process (i.e. the window that should be layouted)
sub findMainWindow {
	my ($process) = @_;
	my $window = $process->attributes()->objectWithName_("AXMainWindow")->value()->get();
	if ( !$$window ) {
		# For some resone there is no AXMainWindow so we try AXFocusedWindow
		$window = $process->attributes()->objectWithName_("AXFocusedWindow")->value()->get();
	}
	if ( !$$window ) {
		my $enumerator = $process->windows()->objectEnumerator();
		my $obj;

		while($obj = $enumerator->nextObject() and $$obj) {
			$window = $obj->get();
			if ($window->focused()) {
				last;
			}
		}
	}
	$window;
}

# Set the new bounds of a window (i.e. layout it)
sub setWindowBounds {
	my ($process, $window, $screen, $bounds) = @_;
	my $pos = NSMutableArray->arrayWithCapacity_(2);
	$pos->addObject_(NSNumber->numberWithFloat_($bounds->{_left}));
	$pos->addObject_(NSNumber->numberWithFloat_($bounds->{_top}));
	my $smallersize = NSMutableArray->arrayWithCapacity_(2);
	$smallersize->addObject_(NSNumber->numberWithFloat_($bounds->width * 0.9));
	$smallersize->addObject_(NSNumber->numberWithFloat_($bounds->height * 0.9));
	my $size = NSMutableArray->arrayWithCapacity_(2);
	$size->addObject_(NSNumber->numberWithFloat_($bounds->width));
	$size->addObject_(NSNumber->numberWithFloat_($bounds->height));

	# these properties can be found in /System/Library/CoreServices/System Events.app/Contents/Resources/SystemEvents.sdef
	# there is a little issue if the window is too big (i.e. partly outside screen), therefore we first move to 0,0
	$debug && syslog(LOG_NOTICE, sprintf("Set size: %d %d", $bounds->width, $bounds->height));
	$window->size()->setTo_($smallersize);

	# Don't know why the $window becomes invalid after this, it just does (sometimes)
	my $windowPosition = $window->propertyWithCode_(unpack("N", "posn"));
	$debug && syslog(LOG_NOTICE, sprintf("Set size: %d %d", $bounds->{_left}, $bounds->{_top}));
	$window->position()->setTo_($pos);
	# Don't know why the $window becomes invalid after this, it just does (sometimes)
	$debug && syslog(LOG_NOTICE, sprintf("Set size: %d %d", $bounds->width, $bounds->height));
	$window->size()->setTo_($size);
}

# Extract commandline parameters to: $command, $targetArg and $screenOffset
# Usually separated by ':', but we support some legacy
my $command;
my @targetArg;
my $screenOffset = 0;
my @commandAndTarget = split(/:/, @ARGV[0]);
if (scalar(@commandAndTarget) == 2) {
	$command = @commandAndTarget[0];
	@targetArg = split(/,/, @commandAndTarget[1]);
} elsif (scalar(@commandAndTarget) == 3) {
	$command = @commandAndTarget[0];
	@targetArg = split(/,/, @commandAndTarget[1]);
	$screenOffset = @commandAndTarget[2];
} else {
	$command = "set";
	@targetArg = split(/,/, @commandAndTarget[0]);
}

# Here we extract all information about the available screens (and their visiable frames)
my @screens;
my @mainScreenFrame = ObjCStruct::NSRect->unpack(NSScreen->mainScreen()->frame());
my $enumerator = NSScreen->screens()->objectEnumerator();
my $obj;
while($obj = $enumerator->nextObject() and $$obj) {
	my @rect = ObjCStruct::NSRect->unpack($obj->visibleFrame());
	my $screen = Rect->new(@rect[0], @mainScreenFrame[3] - @rect[1] - @rect[3], @rect[0] + @rect[2], @mainScreenFrame[3] - @rect[1]);
	push(@screens, $screen);
	$debug && syslog(LOG_NOTICE, sprintf("Screen frame: %d %d %d %d %d %d %d %d", @mainScreenFrame[0], @mainScreenFrame[1], @mainScreenFrame[2], @mainScreenFrame[3], @rect[0], @rect[1], @rect[2], @rect[3]));
	$debug && syslog(LOG_NOTICE, sprintf("Screen rect: %d %d %d %d", $screen->left, $screen->top, $screen->right, $screen->bottom));
}

# Now we query the System-Events for the frontmost process and its main window
my $systemevents = SBApplication->applicationWithBundleIdentifier_("com.apple.systemevents");
my $frontmostPredicate = NSPredicate->predicateWithFormat_("frontmost == true");
my $frontmost = $systemevents->processes()->filteredArrayUsingPredicate_($frontmostPredicate)->firstObject();

$debug && syslog(LOG_NOTICE, sprintf("Frontmost process: %s", $frontmost->name()->cString()));

my $window = findMainWindow($frontmost);

$debug && syslog(LOG_NOTICE, sprintf("Window title: %s", $window->title()->cString()));

my $position = $window->position()->get();
my $size = $window->size()->get();
my $appRect = Rect->new($position->objectAtIndex_(0)->floatValue(), 
						$position->objectAtIndex_(1)->floatValue(),
						$position->objectAtIndex_(0)->floatValue() + $size->objectAtIndex_(0)->floatValue(),
						$position->objectAtIndex_(1)->floatValue() + $size->objectAtIndex_(1)->floatValue());

$debug && syslog(LOG_NOTICE, sprintf("Window rect: %d %d %d %d", $appRect->left, $appRect->top, $appRect->right, $appRect->bottom));

# ... and figure out on which screen it is (largest visible area wins)
my $appScreenIdx = 0;
my $maxIntersectionArea = -1;
for my $index (0 .. $#screens) {
	if ( @screens[$index]->intersects($appRect) ) {
		my $area = @screens[$index]->intersection($appRect)->area;
		if ( $area > $maxIntersectionArea ) {
			$maxIntersectionArea = $area;
			$appScreenIdx = $index;
		}		
	}
}
# ... and add a screen offset (if there is one, i.e. move window to some different screen)
$appScreenIdx = ($appScreenIdx + $screenOffset) % scalar(@screens);
my $appScreen = @screens[$appScreenIdx];

$debug && syslog(LOG_NOTICE, sprintf("Selected screen rect: %d %d %d %d", $appScreen->left, $appScreen->top, $appScreen->right, $appScreen->bottom));

given($command) {
	when('fullscreen') {
		# Toggle fullscreen
		my $isFullScreen = $window->attributes()->objectWithName_('AXFullScreen')->value()->get()->boolValue();

		$window->attributes()->objectWithName_('AXFullScreen')->value()->setTo_(NSNumber->numberWithBool_(!$isFullScreen));		
	};
	when('resize') {
		# Simple resize of the window (grow/shrink any desired corner)
		my $target = Rect->new(
						$appRect->left - $appScreen->width * @targetArg[0],
						$appRect->top - $appScreen->height * @targetArg[1],
						$appRect->right + $appScreen->width * @targetArg[2],
						$appRect->bottom + $appScreen->height * @targetArg[3]);

		setWindowBounds($frontmost, $window, $appScreen, $target);
	};
	when('resizeAll') {
		# Single value => resize in all directions with sticks screen borders
		my $resize_x = $appScreen->width * @targetArg[0];
		my $resize_y = $appScreen->height * @targetArg[0];
		my $target = Rect->new($appRect->left, $appRect->top, $appRect->right, $appRect->bottom);
		if ( abs($appRect->left - $appScreen->left) < 0.01 * $appScreen->width ) {
			if ( abs($appRect->right - $appScreen->right) < 0.01 * $appScreen->width ) {
				$target->{_left} = $appScreen->left;
				$target->{_right} = $appScreen->right;
			} else {
				$target->{_left} = $appScreen->left;
				$target->{_right} = $appRect->right + $resize_x;
			}
		} elsif ( abs($appRect->right - $appScreen->right) < 0.01 * $appScreen->width ) {
			$target->{_left} = $appRect->left - $resize_x;
			$target->{_right} = $appScreen->right;
		} else {
			$target->{_left} = $appRect->left - $resize_x * 0.5;
			$target->{_right} = $appRect->right + $resize_x * 0.5;
		}
		if ( abs($appRect->top - $appScreen->top) < 0.01 * $appScreen->height ) {
			if ( abs($appRect->bottom - $appScreen->bottom) < 0.01 * $appScreen->height ) {
				$target->{_top} = $appScreen->top;
				$target->{_bottom} = $appScreen->bottom;
			} else {
				$target->{_top} = $appScreen->top;
				$target->{_bottom} = $appRect->bottom + $resize_y;
			}
		} elsif ( abs($appRect->bottom - $appScreen->bottom) < 0.01 * $appScreen->height ) {
			$target->{_top} = $appRect->top - $resize_y;
			$target->{_bottom} = $appScreen->bottom;
		} else {
			$target->{_top} = $appRect->top - $resize_y * 0.5;
			$target->{_bottom} = $appRect->bottom + $resize_y * 0.5;
		}

		setWindowBounds($frontmost, $window, $appScreen, $target);
	};
	when('move') {
		# Two values => Move window to coords (center_x, center_y), prevent window from moving out of screen
		my $target_x = $appScreen->left + $appScreen->width * @targetArg[0];
		my $target_y = $appScreen->top + $appScreen->height * @targetArg[1];
		my $pos_x = $target_x - $appRect->width * 0.5;
		my $pos_y = $target_y - $appRect->height * 0.5;
		if ($pos_x < $appScreen->left) {
			$pos_x = $appScreen->left;
		}
		if ( $pos_y < $appScreen->top) {
			$pos_y = $appScreen->top;
		}
		if ($pos_x + $appRect->width > $appScreen->right) {
			$pos_x = $appScreen->right - $appRect->width;
		}
		if ($pos_y + $appRect->height > $appScreen->bottom) {
			$pos_y = $appScreen->bottom - $appRect->height;			
		}
		my $pos = NSMutableArray->arrayWithCapacity_(2);
		$pos->addObject_(NSNumber->numberWithFloat_($pos_x));
		$pos->addObject_(NSNumber->numberWithFloat_($pos_y));

		$window->setPosition_($pos);
	};
	when('set') {
		# Four values => Move and resize window to coords (left, top, right, bottom)
		my $target = Rect->new(
						$appScreen->left + $appScreen->width * @targetArg[0], 
						$appScreen->top + $appScreen->height * @targetArg[1], 
						$appScreen->left + $appScreen->width * @targetArg[2], 
						$appScreen->top + $appScreen->height * @targetArg[3]);

		setWindowBounds($frontmost, $window, $appScreen, $target);
	}
}
