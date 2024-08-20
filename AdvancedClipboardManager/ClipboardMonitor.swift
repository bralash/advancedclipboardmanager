//
//  ClipboardMonitor.swift
//  AdvancedClipboardManager
//
//  Created by Emmanuel  Asaber on 8/20/24.
//

import Cocoa
import SwiftUI
import CoreData

class ClipboardMonitor: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var availableTags: Set<String> = []
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        lastChangeCount = pasteboard.changeCount
        loadSavedItems()
        updateAvailableTags()
        startMonitoring()
    }
    
    private func loadSavedItems() {
        let fetchRequest: NSFetchRequest<ClipboardItemMO> = ClipboardItemMO.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemMO.timestamp, ascending: false)]
        
        do {
            let savedItems = try viewContext.fetch(fetchRequest)
            clipboardItems = savedItems.compactMap { ClipboardItem(managedObject: $0) }
        } catch {
            print("Error loading saved items: \(error)")
        }
    }
    
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    func addTag(_ tag: String, to item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].tags.insert(tag)
            updateAvailableTags()
            saveItemTags(item: clipboardItems[index])
        }
    }
    
    func removeTag(_ tag: String, from item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].tags.remove(tag)
            updateAvailableTags()
            saveItemTags(item: clipboardItems[index])
        }
    }
    
    private func updateAvailableTags() {
        availableTags = Set(clipboardItems.flatMap { $0.tags })
    }
    
    private func saveItemTags(item: ClipboardItem) {
        let fetchRequest: NSFetchRequest<ClipboardItemMO> = ClipboardItemMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let managedObject = results.first {
                managedObject.tagsString = item.tags.joined(separator: ",")
                saveContext()
            }
        } catch {
            print("Error saving item tags: \(error)")
        }
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkForChanges()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func clearClipboard() {
        pasteboard.clearContents()
        clipboardItems.removeAll()
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipboardItemMO.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try viewContext.execute(batchDeleteRequest)
            try viewContext.save()
        } catch {
            print ("Error clearing clipboard items: \(error)")
        }
        
        objectWillChange.send()
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        if let string = pasteboard.string(forType: .string) {
            let newItem = ClipboardItem(content: .text(string))
            addItem(newItem)
            print("Added text item: \(string.prefix(20))...")
        } else if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                let newItem = ClipboardItem(content: .image(pngData))
                addItem(newItem)
                print("Added image item: \(pngData.count) bytes")
            }
        } else if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            let newItem = ClipboardItem(content: .file(firstURL.path))
            addItem(newItem)
            print("Added file item: \(firstURL.path)")
        }
    }
    
    
    private func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.clipboardItems.insert(item, at: 0)
            if self.clipboardItems.count > 50 {
                self.clipboardItems.removeLast()
            }
            
            let newManagedObject = ClipboardItemMO(context: self.viewContext)
            newManagedObject.id = item.id
            newManagedObject.timestamp = item.timestamp
            newManagedObject.type = item.content.typeString
            newManagedObject.content = item.content.data
            newManagedObject.isPinned = item.isPinned
            newManagedObject.tagsString = item.tags.joined(separator: ",")
            
            self.saveContext()
            self.updateAvailableTags()
        }
    }
    
    func togglePinStatus(for item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].isPinned.toggle()
            
            // Update Core Data
            let fetchRequest: NSFetchRequest<ClipboardItemMO> = ClipboardItemMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                if let managedObject = results.first {
                    managedObject.isPinned = clipboardItems[index].isPinned
                    saveContext()
                }
            } catch {
                print("Error updating pin status: \(error)")
            }
            
            // Re-sort items to move pinned items to the top
            sortClipboardItems()
        }
    }
    
    private func sortClipboardItems() {
        clipboardItems.sort { (item1, item2) -> Bool in
            if item1.isPinned != item2.isPinned {
                return item1.isPinned
            }
            return item1.timestamp > item2.timestamp
        }
        objectWillChange.send()
    }
    
    func copyItemToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .tiff)
        case .file(let path):
            pasteboard.writeObjects([NSURL(fileURLWithPath: path)])
        }
    }
}

class ClipboardItem: Identifiable, ObservableObject, Hashable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    @Published var isPinned: Bool
    @Published var tags: Set<String>
    
    init(id: UUID = UUID(), content: ClipboardContent, timestamp: Date = Date(), isPinned: Bool = false, tags: Set<String> = []) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.tags = tags
    }
    
    init?(managedObject: ClipboardItemMO) {
        guard let id = managedObject.id,
              let timestamp = managedObject.timestamp,
              let type = managedObject.type,
              let data = managedObject.content else {
            return nil
        }
        
        self.id = id
        self.timestamp = timestamp
        self.isPinned = managedObject.isPinned
        self.tags = Set(managedObject.tagsString?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [])
        
        switch type {
        case "text":
            guard let string = String(data: data, encoding: .utf8) else { return nil }
            self.content = .text(string)
        case "image":
            self.content = .image(data)
        case "file":
            guard let path = String(data: data, encoding: .utf8) else { return nil }
            self.content = .file(path)
        default:
            return nil
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance (required for Hashable)
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}


enum ClipboardContent: Hashable {
    case text(String)
    case image(Data)
    case file(String)
    
    var typeString: String {
        switch self {
        case .text: return "text"
        case .image: return "image"
        case .file: return "file"
        }
    }
    
    var data: Data {
        switch self {
        case .text(let string):
            return string.data(using: .utf8) ?? Data()
        case .image(let imageData):
            return imageData
        case .file(let path):
            return path.data(using: .utf8) ?? Data()
        }
    }
    
    var searchableText: String {
        switch self {
        case .text(let string):
            return string
        case .image:
            return "Image"
        case .file(let path):
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }
}

