#!/bin/bash
if [ ! -d ~/Downloads/ScreenShots ]; then
    echo "Folder ~/Downloads/ScreenShots not found, Please create it first."
    echo "And make sure your /System/Applications/Utilities/Screenshot.app's save location is set to save to ~/Downloads/ScreenShots"
    echo "Maybe you can set defaults of /System/Applications/Utilities/Screenshot.app via settings.sh"
    exit 1
fi
cat <<EOF > $HOME/Library/LaunchAgents/ScreenShotsWatcher.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.desmg.ScreenShotsWatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/Downloads/ScreenShots/ScreenShotsWatcher</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload $HOME/Library/LaunchAgents/ScreenShotsWatcher.plist 2>/dev/null
launchctl load $HOME/Library/LaunchAgents/ScreenShotsWatcher.plist 2>/dev/null

ls -al $HOME/Library/LaunchAgents/ScreenShotsWatcher.plist
ps -ef | grep ScreenShotsWatcher | grep -v grep
