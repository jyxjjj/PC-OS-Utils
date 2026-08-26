import Darwin
import Foundation
import IOKit

let arguments = CommandLine.arguments.dropFirst()

let source = arguments.first ?? ""
let target = arguments.dropFirst().first ?? ""
let channel = Int(arguments.dropFirst(2).first ?? "0") ?? 0

guard
    ["HID", "SP"].contains(source),
    !target.isEmpty,
    source == "HID" || [-1, 0, 1].contains(channel)
else {
    fputs(
        "Usage: DeviceBattery <HID|SP> <device-name> [-1|0|1]    (SP: -1=left, 0=case, 1=right)\n",
        stderr)
    exit(EX_USAGE)
}

func getHIDDevice() -> Int? {
    var iterator: io_iterator_t = 0

    guard let matching = IOServiceMatching("AppleDeviceManagementHIDEventService") else {
        return nil
    }

    guard
        IOServiceGetMatchingServices(
            kIOMainPortDefault,
            matching,
            &iterator
        ) == KERN_SUCCESS
    else {
        return nil
    }

    defer {
        IOObjectRelease(iterator)
    }

    while true {
        let service = IOIteratorNext(iterator)

        if service == 0 {
            break
        }

        let product =
            IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String

        let transport =
            IORegistryEntryCreateCFProperty(
                service, "Transport" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            as? String

        var matched = false

        if transport == "Bluetooth" {
            matched = product == target
        }

        if transport == "USB" {
            if target.contains("Magic Trackpad"), product == "Magic Trackpad" {
                matched = true
            }

            if target.contains("Magic Keyboard"),
                product == "Magic Keyboard with Touch ID and Numeric Keypad"
            {
                matched = true
            }
        }

        if matched {
            let battery =
                IORegistryEntryCreateCFProperty(
                    service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber

            if let battery {
                let value = battery.intValue
                IOObjectRelease(service)
                return value
            }
        }
        IOObjectRelease(service)
    }

    return nil
}

func getSPDevice(_ channel: Int) -> Int? {
    let process = Process()
    let output = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    process.arguments = ["SPBluetoothDataType", "-json"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }

    guard process.terminationStatus == EXIT_SUCCESS else {
        return nil
    }

    let data = output.fileHandleForReading.readDataToEndOfFile()

    guard let json = try? JSONSerialization.jsonObject(with: data),
        let root = json as? [String: Any],
        let bluetooth = root["SPBluetoothDataType"] as? [[String: Any]]
    else {
        return nil
    }

    for controller in bluetooth {
        let devices =
            (controller["device_connected"] as? [[String: Any]] ?? [])
            + (controller["device_not_connected"] as? [[String: Any]] ?? [])

        for device in devices {
            guard let info = device[target] as? [String: Any] else {
                continue
            }

            let left = Int(
                (info["device_batteryLevelLeft"] as? String)?.filter(\.isNumber) ?? ""
            )

            let right = Int(
                (info["device_batteryLevelRight"] as? String)?.filter(\.isNumber) ?? ""
            )

            let `case` = Int(
                (info["device_batteryLevelCase"] as? String)?.filter(\.isNumber) ?? ""
            )

            return switch channel {
                case -1: left
                case 1: right
                default: `case`
            }
        }
    }

    return nil
}

let battery: Int?

switch source {
    case "HID":
        battery = getHIDDevice()

    case "SP":
        battery = getSPDevice(channel)

    default:
        battery = nil
}

guard let battery else {
    exit(EX_UNAVAILABLE)
}

print(battery)
