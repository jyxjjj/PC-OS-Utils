#!/bin/bash
if [ ! -d ~/Downloads/ScreenShots ]; then
    echo "Folder ~/Downloads/ScreenShots not found, Please create it first."
    echo "And make sure your /System/Applications/Utilities/Screenshot.app's save location is set to save to ~/Downloads/ScreenShots"
    exit 1
fi
if [ "$(pwd)" != "$HOME/Downloads/ScreenShots" ]; then
    echo "Current working directory is not ~/Downloads/ScreenShots."
    echo "Please navigate to ~/Downloads/ScreenShots and run this script again."
    exit 1
fi
swiftc -O $HOME/Downloads/ScreenShots/ScreenShotsWatcher.swift -o $HOME/Downloads/ScreenShots/ScreenShotsWatcher
