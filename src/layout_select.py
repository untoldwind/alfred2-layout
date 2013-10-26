#!/usr/bin/python

import sys
import xml.etree.ElementTree as ET

class Layout:
	def __init__(self, name, title, arg):
		self.name = name
		self.title = title
		self.arg = arg
		self.uid = "layout." + name

layouts = [
    Layout("togglefullscreen", "Toggle full screen mode", "togglefullscreen"),
	Layout("full", "Full", "set:0,0,1,1"),
	Layout("left", "Left", "set:0,0,0.5,1"),
	Layout("top", "Top", "set:0,0,1,0.5"),
	Layout("bottom", "Bottom", "set:0,0.5,1,1"),
	Layout("right", "Right", "set:0.5,0,1,1"),
	Layout("topleft", "Top left", "set:0,0,0.5,0.5"),
	Layout("bottomleft", "Bottom left", "set:0,0.5,0.5,1"),
	Layout("topright", "Top right", "set:0.5,0,1,0.5"),
	Layout("bottomright", "Bottom right", "set:0.5,0.5,1,1"),
    Layout("center", "Center", "set:0.1,0.1,0.9,0.9"),
    Layout("movecenter", "Move to center", "move:0.5,0.5"),
    Layout("movetopleft", "Move to top left", "move:0,0"),
    Layout("movebottomleft", "Move to bottom left", "move:0,1"),
    Layout("movetopright", "Move to top right", "move:1,0"),
    Layout("movebottomright", "Move to bottom right", "move:1,1"),
    Layout("grow", "Grow window", "resizeAll:0.1667"),
    Layout("shrink", "Shrink window", "resizeAll:-0.1667"),
    Layout("growleft", "Grow left side of window", "resize:0.1667,0,0,0"),
    Layout("shrinkleft", "Shrink left side of window", "resize:-0.1667,0,0,0"),
    Layout("growtop", "Grow top side of window", "resize:0,0.1667,0,0"),
    Layout("shrinktop", "Shrink top side of window", "resize:0,-0.1667,0,0"),
    Layout("growright", "Grow right side of window", "resize:0,0,0.1667,0"),
    Layout("shrinkright", "Shrink right side of window", "resize:0,0,-0.1667,0"),
    Layout("growbottom", "Grow bottom side of window", "resize:0,0,0,0.1667"),
    Layout("shrinkbottom", "Shrink bottom side of window", "resize:0,0,0,-0.1667")
]

for x1 in range(1, 4):
	for y1 in range(1, 4):
		for x2 in range(x1, 4):
			for y2 in range(y1, 4):
				if x1 == x2 and y1 == y2:
					layouts.append(Layout("%d%d" % (x1, y1), "(%d %d)" % (x1, y1), "set:%f,%f,%f,%f" % ((x1 - 1) / 3.0, (y1 - 1) / 3.0, x1 / 3.0, y1 / 3.0)))
				else:
					layouts.append(Layout("%d%d-%d%d" % (x1, y1, x2, y2), "(%d %d) - (%d %d)" % (x1, y1, x2, y2), "set:%f,%f,%f,%f" % ((x1 -1) / 3.0, (y1 - 1) / 3.0, x2 / 3.0, y2 / 3.0)))

query = sys.argv[1]
if len(query) > 0:
	layouts = [n for n in layouts if query.lower() in n.name.lower()]
layouts = sorted(layouts, key=lambda l: len(l.name))

root = ET.Element('items')
for layout in layouts:
	ie = ET.Element('item', valid="yes", arg=layout.arg, uid=layout.uid)
	te = ET.Element('title')
	te.text = layout.title
	ie.append(te)
	icon = ET.Element('icon')
	icon.text="icon_%s.png" % layout.name
	ie.append(icon)
	root.append(ie)
print '<?xml version="1.0"?>'
print ET.tostring(root)
print ""
