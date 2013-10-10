tell application "System Events"
   try
      tell front window of (first process whose frontmost is true)
          set isFullScreen to get value of attribute "AXFullScreen"
          set value of attribute "AXFullScreen" to not isFullScreen
      end tell
   end try
end tell