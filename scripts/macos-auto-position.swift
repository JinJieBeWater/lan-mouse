import CoreGraphics
import Foundation

let lanMouse = NSString(
    string: "~/Applications/Lan Mouse.app/Contents/MacOS/lan-mouse"
).expandingTildeInPath

func desiredPosition(displayCount: UInt32) -> String {
    displayCount > 1 ? "left" : "right"
}

func activeDisplayCount() -> UInt32? {
    var count: UInt32 = 0
    return CGGetActiveDisplayList(0, nil, &count) == .success ? count : nil
}

func applyPosition(_ position: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: lanMouse)
    process.arguments = ["cli", "set-position", "0", position]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

if CommandLine.arguments.contains("--self-test") {
    precondition(desiredPosition(displayCount: 1) == "right")
    precondition(desiredPosition(displayCount: 2) == "left")
    print("self-test passed")
    exit(0)
}

if CommandLine.arguments.contains("--once") {
    guard let count = activeDisplayCount() else { exit(1) }
    let position = desiredPosition(displayCount: count)
    exit(applyPosition(position) ? 0 : 1)
}

// ponytail: 2s polling also handles Lan Mouse login/restart races; use a
// CGDisplay callback only if these idle wakeups ever matter.
var appliedPosition: String?
while true {
    if let count = activeDisplayCount() {
        let position = desiredPosition(displayCount: count)
        if position != appliedPosition, applyPosition(position) {
            appliedPosition = position
            print("display_count=\(count) position=\(position)")
        }
    }
    Thread.sleep(forTimeInterval: 2)
}
