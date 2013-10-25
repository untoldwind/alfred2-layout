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
	Layout("full", "Full", "0,0,1,1"),
	Layout("left", "Left", "0,0,0.5,1"),
	Layout("top", "Top", "0,0,1,0.5"),
	Layout("bottom", "Bottom", "0,0.5,1,1"),
	Layout("right", "Right", "0.5,0,1,1"),
	Layout("topleft", "Top left", "0,0,0.5,0.5"),
	Layout("bottomleft", "Bottom left", "0,0.5,0.5,1"),
	Layout("topright", "Top right", "0.5,0,1,0.5"),
	Layout("bottomright", "Bottom right", "0.5,0.5,1,1"),
    Layout("center", "Center", "0.1,0.1,0.9,0.9"),
    Layout("movecenter", "Move to center", "0.5,0.5"),
    Layout("movetopleft", "Move to top left", "0,0"),
    Layout("movebottomleft", "Move to bottom left", "0,1"),
    Layout("movetopright", "Move to top right", "1,0"),
    Layout("movebottomright", "Move to bottom right", "1,1"),
    Layout("grow", "Grow window", "0.1667"),
    Layout("shrink", "Shrink window", "-0.1667")
]

for x1 in range(1, 4):
	for y1 in range(1, 4):
		for x2 in range(x1, 4):
			for y2 in range(y1, 4):
				if x1 == x2 and y1 == y2:
					layouts.append(Layout("%d%d" % (x1, y1), "(%d %d)" % (x1, y1), "%f,%f,%f,%f" % ((x1 - 1) / 3.0, (y1 - 1) / 3.0, x1 / 3.0, y1 / 3.0)))
				else:
					layouts.append(Layout("%d%d-%d%d" % (x1, y1, x2, y2), "(%d %d) - (%d %d)" % (x1, y1, x2, y2), "%f,%f,%f,%f" % ((x1 -1) / 3.0, (y1 - 1) / 3.0, x2 / 3.0, y2 / 3.0)))

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
