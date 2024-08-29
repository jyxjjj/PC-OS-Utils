import AppKit
import ApplicationServices
import CoreServices
import Foundation

func CopyDataToClipboard(_ data: Data) {
    let clipboard = NSPasteboard.general
    clipboard.clearContents()
    clipboard.setData(data as Data, forType: .png)
}

func askForConfirmation(_ filename: String) -> Bool {
    let message: CFString = "Do you want to move \(filename) to the clipboard?" as CFString
    var responseFlags: CFOptionFlags = 0
    CFUserNotificationDisplayAlert(
        0, kCFUserNotificationNoteAlertLevel,
        nil, nil, nil,
        "Confirmation" as CFString,
        message,
        "Yes"as CFString, "No"as CFString, nil,
        &responseFlags
    )
    return responseFlags == kCFUserNotificationDefaultResponse
}

func moveToTrash(_ path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
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
        if filename.hasPrefix(".") || !filename.hasPrefix("Screenshot") || !filename.hasSuffix(".png") || !FileManager.default.fileExists(atPath: filename) {
            continue
        } else {
            print("Processing \(filename)")
        }
        if let data = FileManager.default.contents(atPath: filename) {
            CopyDataToClipboard(data)
            print("Copied \(filename) to clipboard")
            if askForConfirmation(filename) {
                moveToTrash(path)
                print("Moved \(filename) to trash")
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
