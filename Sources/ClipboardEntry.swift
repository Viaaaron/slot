import AppKit
import Foundation

struct ClipboardRepresentation: Codable, Equatable {
    let type: String
    let data: Data
}

struct ClipboardItemSnapshot: Codable, Equatable {
    let representations: [ClipboardRepresentation]
}

struct ClipboardEntry: Codable, Equatable {
    let items: [ClipboardItemSnapshot]
    let capturedAt: Date

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.items == rhs.items
    }

    var preview: String {
        for item in items {
            if let representation = item.representations.first(where: {
                $0.type == NSPasteboard.PasteboardType.string.rawValue
            }), let string = String(data: representation.data, encoding: .utf8) {
                let compact = string
                    .replacingOccurrences(of: "\n", with: " ↵ ")
                    .replacingOccurrences(of: "\t", with: " ⇥ ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if compact.isEmpty { return "Empty text" }
                return String(compact.prefix(42)) + (compact.count > 42 ? "…" : "")
            }
        }

        let types = items.flatMap(\.representations).map(\.type)
        if types.contains(where: { $0.contains("image") || $0.contains("png") || $0.contains("tiff") }) {
            return "Image"
        }
        if types.contains(NSPasteboard.PasteboardType.fileURL.rawValue) {
            return items.count == 1 ? "File" : "\(items.count) files"
        }
        return items.count == 1 ? "Clipboard item" : "\(items.count) clipboard items"
    }
}

