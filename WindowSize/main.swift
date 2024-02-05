import Cocoa
import Foundation

func requestAccessibilityPermission() {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
    let status = AXIsProcessTrustedWithOptions(options)

    if status != true {
        print("Requesting Accessibility Permission...")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    } else {
        print("Accessibility Permission is already granted.")
    }
}

// 调用函数请求权限
requestAccessibilityPermission()

func printJson(data: Any) {
    if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}

let appElement = NSRunningApplication.runningApplications(withBundleIdentifier: "com.TEST.TEST").first
if let appPID = appElement?.processIdentifier {
    let appRef = AXUIElementCreateApplication(appPID)
    var windowList: AnyObject?
    AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
    if let windowList = windowList as? [AXUIElement] {
        for window in windowList {
            var windowTitle: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitle)
            if let title = windowTitle as? String {
                if title == "TEST" {
                    var size: CFTypeRef
                    var newSize = CGSize(width: 320, height: 480)
                    size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &newSize)!
                    while true {
                        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)
                    }
                }
            }
        }
    }
}
