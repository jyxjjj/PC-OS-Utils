#!/bin/bash
# Create Folder
mkdir -p ~/Downloads/ScreenShots
echo "Creating Folder '~/Downloads/ScreenShots'"
# location = "~/Downloads/ScreenShots";
defaults write com.apple.screencapture location "~/Downloads/ScreenShots"
echo "Updated settings to set screenshot save location to '~/Downloads/ScreenShots'"
# showsCursor = 1;
defaults write com.apple.screencapture showsCursor 1
echo "Updated settings to show cursor when capturing a video"
# style = selection;
defaults write com.apple.screencapture style selection
echo "Updated settings to let user choose a specific area to capture"
# "save-selections" = 0;
defaults write com.apple.screencapture "save-selections" 0
echo "Updated settings to disable saving previous capture selections"
# "show-thumbnail" = 1;
defaults write com.apple.screencapture "show-thumbnail" 1
echo "Updated settings to show preview thumbnail in the bottom-right corner of the screen"
# target = file;
defaults write com.apple.screencapture target file
echo "Updated settings to save screenshots to file"
# video
defaults write com.apple.screencapture video 0
echo "Updated settings to disable video capture by default"
# Restart SystemUIServer
killall SystemUIServer
echo "Settings updated. If didn't take effect, please restart your computer, "
echo " or you can manually set these settings in /System/Applications/Utilities/Screenshot.app ."
