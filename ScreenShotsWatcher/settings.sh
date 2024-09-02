#!/bin/bash
defaults write com.apple.screencapture location "~/Downloads/ScreenShots"
echo "Updated the ScreenShot Settings 'location' to '~/Downloads/ScreenShots'"
defaults write com.apple.screencapture showsCursor 1
echo "Updated the ScreenShot Settings 'showsCursor' to 1"
defaults write com.apple.screencapture style selection
echo "Updated the ScreenShot Settings 'style' to 'selection'"
defaults write com.apple.screencapture target file
echo "Updated the ScreenShot Settings 'target' to 'file'"
defaults write com.apple.screencapture video 0
echo "Updated the ScreenShot Settings 'video mode' to 0"
killall SystemUIServer
echo "Settings updated. If didn't take effect, please restart your computer, "
echo " or you can manually set these settings in /System/Applications/Utilities/Screenshot.app ."
