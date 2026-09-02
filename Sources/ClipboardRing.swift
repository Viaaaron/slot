import AppKit
import Foundation

final class ClipboardRing {
    private(set) var entries: [ClipboardEntry] = []
    private let pasteboard: NSPasteboard
    private let maximumEntries = 3
    private let maximumEntryBytes = 128 * 1024 * 1024
    private var lastObservedChangeCount: Int
    private let storageURL: URL

    var onChange: (() -> Void)?

    init(pasteboard: NSPasteboard = .general, storageURLOverride: URL? = nil) {
        self.pasteboard = pasteboard
        lastObservedChangeCount = pasteboard.changeCount
        if let storageURLOverride {
            storageURL = storageURLOverride
            try? FileManager.default.createDirectory(
                at: storageURLOverride.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let directory = support.appendingPathComponent("Slot", isDirectory: true)
            storageURL = directory.appendingPathComponent("slots.plist")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        load()
        captureCurrentIfChanged(force: true)
    }

    @discardableResult
    func captureCurrentIfChanged(force: Bool = false) -> Bool {
        let changeCount = pasteboard.changeCount
        guard force || changeCount != lastObservedChangeCount else { return false }
        lastObservedChangeCount = changeCount

        guard let entry = snapshotCurrentPasteboard() else { return false }
        entries.removeAll(where: { $0 == entry })
        entries.insert(entry, at: 0)
        if entries.count > maximumEntries {
            entries.removeLast(entries.count - maximumEntries)
        }
        persist()
        onChange?()
        return true
    }

    func writeEntry(at index: Int) -> Bool {
        guard entries.indices.contains(index) else { return false }
        let entry = entries[index]
        pasteboard.clearContents()

        let pasteboardItems: [NSPasteboardItem] = entry.items.compactMap { snapshot in
            let item = NSPasteboardItem()
            var wroteRepresentation = false
            for representation in snapshot.representations {
                let type = NSPasteboard.PasteboardType(representation.type)
                if item.setData(representation.data, forType: type) {
                    wroteRepresentation = true
                }
            }
            return wroteRepresentation ? item : nil
        }

        guard !pasteboardItems.isEmpty else { return false }
        pasteboard.writeObjects(pasteboardItems)
        lastObservedChangeCount = pasteboard.changeCount
        return true
    }

    func clear() {
        entries.removeAll()
        persist()
        onChange?()
    }

    private func snapshotCurrentPasteboard() -> ClipboardEntry? {
        guard let pasteboardItems = pasteboard.pasteboardItems, !pasteboardItems.isEmpty else {
            return nil
        }

        let allTypes = Set(pasteboardItems.flatMap { $0.types.map(\.rawValue) })
        let privateMarkers = [
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.TransientType",
            "com.agilebits.onepassword",
            "com.1password"
        ]
        if allTypes.contains(where: { type in
            privateMarkers.contains(where: { marker in type.localizedCaseInsensitiveContains(marker) })
        }) {
            return nil
        }

        var totalBytes = 0
        var snapshots: [ClipboardItemSnapshot] = []

        for pasteboardItem in pasteboardItems {
            var representations: [ClipboardRepresentation] = []
            for type in pasteboardItem.types {
                guard let data = pasteboardItem.data(forType: type), !data.isEmpty else { continue }
                totalBytes += data.count
                guard totalBytes <= maximumEntryBytes else { return nil }
                representations.append(ClipboardRepresentation(type: type.rawValue, data: data))
            }
            if !representations.isEmpty {
                snapshots.append(ClipboardItemSnapshot(representations: representations))
            }
        }

        guard !snapshots.isEmpty else { return nil }
        return ClipboardEntry(items: snapshots, capturedAt: Date())
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? PropertyListDecoder().decode([ClipboardEntry].self, from: data) else {
            return
        }
        entries = Array(saved.prefix(maximumEntries))
    }

    private func persist() {
        guard let data = try? PropertyListEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
