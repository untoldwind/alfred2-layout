Alfred 2 layout workflow
========================

A simple window layouter based on an Alfred 2 workflow.

# Installation

* [v1.0 for 10.8 Mountain Lion](https://github.com/untoldwind/alfred2-layout/raw/1.0_Mountain_Lion/Layout.alfredworkflow)
* [v1.1 for 10.9 Mavericks](https://github.com/untoldwind/alfred2-layout/raw/1.1_Mavericks/Layout.alfredworkflow)
* [v1.2 for 10.10 Yosemite](https://github.com/untoldwind/alfred2-layout/raw/1.2_Yosemite/Layout.alfredworkflow)

## Experimental

* [bleeding edge for Mavericks/Yosemite](https://github.com/untoldwind/alfred2-layout/raw/master/Layout.alfredworkflow)

Also via Packal:

* http://www.packal.org/workflow/alfred2-layout

# Description

The workflow itself is quite simple just typ in the keyword "lay" (or chose another of your liking) followed by:
* full = Maximize
* left, right, top, bottom = Halves of screen
* topleft, topright, bottomleft, bottomright = Quaters of screen
* center = Center of screen (with 10% border)
* 11,12,13,21,22,23,31,32,33 = Thrids of screen
* 11-12,11-13,11-21,11-22 ... = Some other sizes based on thrids
* togglefullscreen = Toggle full screen mode of active window (if possible)
* movecenter = Move window to center of screen (no resize)
* movetopleft, movetopright, movebottomleft, movebottomright = Move window to edges of screen (no resize)
* grow, shrink = resize window by 1/6 of screen size with sticky screen edges
* ... well the script is quite flexible, so I'm waiting for suggestions

It is multi-screen-able. Even though you cannot move windows from one screen to another (yet?) the scripts tries to figure out with screen you mean (depending on the size of the visible area).

## Additional notes for the Mavericks version

The Mavericks version now additionally support the "layother" keyword that moves and layout the current window to the other/next screen.

Examples:
* layother full = Move the current window to the other screen full size
* layother topleft = Move the current window to the top-left quarter of the other screen
* ... and so on

# Screenshots

![Screenshot1](https://dl.dropboxusercontent.com/u/3815280/Bildschirmfoto%202013-09-24%20um%2013.54.58.png)
![Screenshot2](https://dl.dropboxusercontent.com/u/3815280/Bildschirmfoto%202013-09-24%20um%2013.55.22.png)

# Implementation notes

* The script is written in python using PyObjC and the ScriptingBridge. This should be no problem as both is shiped as part of MacOS since 10.5.
* It the application supports scripting, the window is moved "directly". Unluckily some Applications do not support this, so there is a fallback using "SystemEvents". This only works if you have UI scripting enabled: [Graphic User Interface (GUI) Scripting](http://www.macosxautomation.com/applescript/uiscripting/)
* At the moment there are no hotkeys defined, which should be straight forward though ...

# Hacking

If you are keen on adventures feel free to tweak the workflow any way you like. As a starter refer to the following wiki pages:
* [Hacking the Mountain Lion version](https://github.com/untoldwind/alfred2-layout/wiki/Hacking-the-Mountain-Lion-version)
* [Hacking the Mavericks version](https://github.com/untoldwind/alfred2-layout/wiki/Hacking-the-Mavericks-version)

Also take a look at the corresponding thread on the Alfred forums: http://www.alfredforum.com/topic/3154-yet-another-window-layout-workflow

# Licence

[MIT Licence](http://opensource.org/licenses/MIT)

