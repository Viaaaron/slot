import AppKit
import CryptoKit
import Foundation

@main
struct PasteboardTrace {
    static func main() {
        let pasteboard = NSPasteboard.general
        var lastChangeCount = -1
        let deadline = Date().addingTimeInterval(90)

        while Date() < deadline {
            let changeCount = pasteboard.changeCount
            if changeCount != lastChangeCount {
                lastChangeCount = changeCount
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let items = pasteboard.pasteboardItems ?? []
                print("[\(timestamp)] change=\(changeCount) items=\(items.count)")

                for (itemIndex, item) in items.enumerated() {
                    print("  item=\(itemIndex + 1) types=\(item.types.count)")
                    for type in item.types {
                        guard let data = item.data(forType: type) else {
                            print("    type=\(type.rawValue) data=nil")
                            continue
                        }
                        let digest = SHA256.hash(data: data).prefix(6).map { String(format: "%02x", $0) }.joined()
                        var dimensions = ""
                        if type == .png || type == .tiff,
                           let representation = NSBitmapImageRep(data: data) {
                            dimensions = " dimensions=\(representation.pixelsWide)x\(representation.pixelsHigh)"
                        }
                        print("    type=\(type.rawValue) bytes=\(data.count) sha=\(digest)\(dimensions)")
                    }
                }
                fflush(stdout)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        print("TRACE_COMPLETE")
    }
}
