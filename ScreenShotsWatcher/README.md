# macOS-ScreenShotsWatcher

A simple script that watches for new screenshots on macOS.

Copy it to clipboard, then ask to delete or trash it.

Helpful for who needs edit the image right after taking a screenshot.

## How to use

1. run `./settings.sh` to set the path to save screenshots.

2. run `./build.sh` to build the script.

3. run `./run.sh` to start watching for new screenshots.

4. Allow the access of Downloads Folder when a popup appears.

5. Take a screenshot and the script will copy the image to clipboard.

## Appearance

The built-in `Screenshot.app` supports three situations:

1. Save directly to the clipboard
   (<kbd>Command+Shift+5</kbd> → Options → [Save To Section] → Clipboard)

3. Save directly to a file
   (<kbd>Command+Shift+5</kbd> → Options → [Options Section] → [] Show Floating Thumbnail)

4. Show the preview window before saving to a file
   (<kbd>Command+Shift+5</kbd> → Options → [Options Section] → [x] Show Floating Thumbnail)

There are two ways to edit the picture:

1. When the `Screenshot.app` uses option 2, locate the folder, find the screenshot file, and open it with the `Preview.app`.

2. When the `Screenshot.app` uses option 3, click the thumbnail in the lower-right corner, and the `Preview.app` will open automatically.

Neither method supports copying directly to the clipboard.

This is where the tool comes in: when the `Screenshot.app` uses option 3, the file will appear in the folder after the `Preview.app` is closed.
