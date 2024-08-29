import AppKit
import ApplicationServices
import CoreServices
import Foundation

func CopyDataToClipboard(_ data: Data) {
    let clipboard = NSPasteboard.general
    clipboard.clearContents()
    clipboard.setData(data as Data, forType: .png)
}

func askForConfirmation(_ filename: String) -> Int {
    var responseFlags: CFOptionFlags = 0
    CFUserNotificationDisplayAlert(
        0, // Timeout
        kCFUserNotificationCautionAlertLevel, // Alert Level
        nil, // iconURL
        nil, // soundURL
        nil, // localizationURL
        "Trash" as CFString, // alertHeader
        filename as CFString, // alertMessage
        "Trash" as CFString, // defaultButtonTitle
        "Cancel" as CFString, // alternateButtonTitle
        "Delete" as CFString, // otherButtonTitle
        &responseFlags // Response Flags
    )
    if responseFlags == kCFUserNotificationDefaultResponse {
        return 1
    }
    if responseFlags == kCFUserNotificationAlternateResponse {
        return 0
    }
    if responseFlags == kCFUserNotificationOtherResponse {
        return 2
    }
    return 0
}

func callback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    let pathsPointer = eventPaths.bindMemory(to: UnsafePointer<CChar>.self, capacity: numEvents)
    let paths = UnsafeBufferPointer(start: pathsPointer, count: numEvents).compactMap { String(validatingUTF8: $0) }

    for i in 0 ..< numEvents {
        let path = paths[i]
        let filename = path.components(separatedBy: "/").last!
        if filename.hasPrefix(".") || !filename.hasPrefix("Screenshot") || !filename.hasSuffix(".png") || !FileManager.default.fileExists(atPath: path) {
            continue
        } else {
            print("Processing '\(filename)'")
        }
        if let data = FileManager.default.contents(atPath: path) {
            CopyDataToClipboard(data)
            print("Copied '\(filename)' to clipboard")
            let askResult = askForConfirmation(path)
            if askResult == 1 {
                try? FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                print("Moved '\(filename)' to trash")
            }
            if askResult == 2 {
                try? FileManager.default.removeItem(atPath: path)
                print("Deleted '\(filename)'")
            }
            if askResult == 0 {
                print("Did not trash or delete '\(filename)'")
            }
        }
    }
}

let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/ScreenShots").path
let pathsToWatch = [folder] as CFArray
if let stream = FSEventStreamCreate(
    nil,
    callback,
    nil,
    pathsToWatch,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
    0.5,
    FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents)
) {
    let queue = DispatchQueue(label: "com.desmg.ScreenShotsWatcher")
    FSEventStreamSetDispatchQueue(stream, queue)
    FSEventStreamStart(stream)
    print("Watching for screenshots in \(folder)")
    RunLoop.current.run()
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
} else {
    print("Failed to create FSEventStream")
}
