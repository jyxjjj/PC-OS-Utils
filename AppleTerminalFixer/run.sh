#!/bin/bash

cd /Library/LaunchDaemons

sudo cat <<EOF > com.desmg.zshrc_Apple_Terminal_Remover.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.desmg.zshrc_Apple_Terminal_Remover</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/rm</string>
        <string>-f</string>
        <string>/etc/zshrc_Apple_Terminal</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

sudo launchctl bootout system com.desmg.zshrc_Apple_Terminal_Remover.plist 2>/dev/null
sudo launchctl bootstrap system com.desmg.zshrc_Apple_Terminal_Remover.plist 2>/dev/null

ls -al com.desmg.zshrc_Apple_Terminal_Remover.plist
ls -al /etc/zshrc_Apple_Terminal
