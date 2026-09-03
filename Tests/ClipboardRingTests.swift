import AppKit
import Foundation

@main
struct ClipboardRingTests {
    static func main() throws {
        let testPasteboard = NSPasteboard(name: NSPasteboard.Name("com.viaaaron.Slot.tests.\(UUID().uuidString)"))
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlotTests-\(UUID().uuidString)", isDirectory: true)
        let storageURL = testDirectory.appendingPathComponent("slots.plist")
        let ring = ClipboardRing(pasteboard: testPasteboard, storageURLOverride: storageURL)

        func copy(_ value: String) {
            testPasteboard.clearContents()
            let item = NSPasteboardItem()
            precondition(item.setString(value, forType: .string))
            precondition(testPasteboard.writeObjects([item]))
            precondition(ring.captureCurrentIfChanged())
        }

        func currentString() -> String? {
            testPasteboard.string(forType: .string)
        }

        copy("A")
        copy("B")
        copy("C")
        copy("D")

        precondition(ring.entries.count == 3)
        precondition(ring.entries.map(\.preview) == ["D", "C", "B"])
        precondition(ring.writeEntry(at: 2))
        precondition(currentString() == "B")

        copy("C")
        precondition(ring.entries.map(\.preview) == ["C", "D", "B"])

        testPasteboard.clearContents()
        let concealed = NSPasteboardItem()
        concealed.setString("secret", forType: .string)
        concealed.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        testPasteboard.writeObjects([concealed])
        precondition(!ring.captureCurrentIfChanged())
        precondition(ring.entries.map(\.preview) == ["C", "D", "B"])

        try? FileManager.default.removeItem(at: testDirectory)
        testPasteboard.releaseGlobally()
        print("ClipboardRingTests passed")
    }
}
