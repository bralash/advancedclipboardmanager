//
//  ContentView.swift
//  AdvancedClipboardManager
//
//  Created by Emmanuel  Asaber on 8/20/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @State private var searchText = ""
    @State private var selectedItem: ClipboardItem?
    @State private var showSettings = false
    @State private var showClearAlert = false
    @State private var selectedTags: Set<String> = []
    @State private var previewURL: URL?
    @State private var showAbout = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                tagFilterView
                clipboardList
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            
            DetailView(item: selectedItem)
                .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("ClipBuddy")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showClearAlert = true
                }) {
                    Label("Clear Clipboard", systemImage: "trash")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showAbout = true
                }) {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .alert(isPresented: $showClearAlert) {
            Alert(
                title: Text("Clear Clipboard"),
                message: Text("Are you sure you want to clear the clipboard? This action cannot be undone."),
                primaryButton: .destructive(Text("Clear")) {
                    clipboardMonitor.clearClipboard()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(item: Binding(
            get: { previewURL.map { PreviewWrapper(url: $0)}},
            set: { newValue in previewURL = newValue?.url }
        )) { wrapper in QuickLookPreview(url: wrapper.url)}
    }
    
    private var tagFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(clipboardMonitor.availableTags).sorted(), id: \.self) { tag in
                    TagButton(tag: tag, isSelected: selectedTags.contains(tag)) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 50)
        .background(Color.gray.opacity(0.1))
    }

    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.textBackgroundColor))
    }
    
    private var clipboardList: some View {
        List(selection: $selectedItem) {
            ForEach(filteredItems) { item in
                ClipboardItemRow(item: item)
                    .tag(item)
                    .contextMenu {
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            clipboardMonitor.togglePinStatus(for: item)
                        }
                        Button("Copy") {
                            clipboardMonitor.copyItemToClipboard(item)
                        }
                        Button("Quick Preview") {
                            if case .file(let path) = item.content {
                                previewURL = URL(fileURLWithPath: path)
                            }
                        }
                    }
            }
        }
        .listStyle(SidebarListStyle())
    }
    
    private var filteredItems: [ClipboardItem] {
        clipboardMonitor.clipboardItems.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.content.searchableText.lowercased().contains(searchText.lowercased())
            let matchesTags = selectedTags.isEmpty || !selectedTags.isDisjoint(with: item.tags)
            return matchesSearch && matchesTags
        }
    }
}

struct PreviewWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

struct QuickPreviewSheet: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack {
            switch item.content {
            case .text(let string):
                ScrollView {
                    Text(string)
                        .padding()
                }
            case .image(let data):
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    Text("Unable to load image")
                }
            case .file(let path):
                QuickLookPreview(url: URL(fileURLWithPath: path))
            }
        }
        .frame(minWidth: 300, minHeight: 300)
    }
}


struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Text(tag)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1)
            )
            .onTapGesture(perform: action)
    }
}


struct ClipboardItemRow: View {
    @ObservedObject var item: ClipboardItem
    
    var body: some View {
        HStack(spacing: 12) {
            previewContent
            itemContent
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var previewContent: some View {
        switch item.content {
        case .text(let string):
            Text(string)
                .lineLimit(2)
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                Image(systemName: "photo")
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        case .file(let path):
            QuickLookPreview(url: URL(fileURLWithPath: path))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.content.previewText)
                .lineLimit(1)
                .font(.body)
            Text(item.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}


struct DetailView: View {
    let item: ClipboardItem?
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @State private var newTag = ""
    
    var body: some View {
        Group {
            if let item = item, clipboardMonitor.clipboardItems.contains(where: { $0.id == item.id }) {
                VStack {
                    DetailContent(item: item)
                    tagManagementView(for: item)
                    Spacer()
                    Button("Copy to Clipboard") {
                        clipboardMonitor.copyItemToClipboard(item)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                Text("Select an item to view details")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
    
    private func tagManagementView(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading) {
            Text("Tags:")
                .font(.headline)
            
            FlowLayout(spacing: 5) {
                ForEach(Array(item.tags), id: \.self) { tag in
                    TagView(tag: tag) {
                        clipboardMonitor.removeTag(tag, from: item)
                    }
                }
            }
            
            HStack {
                TextField("New tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    if !newTag.isEmpty {
                        clipboardMonitor.addTag(newTag, to: item)
                        newTag = ""
                    }
                }
            }
        }
        .padding()
    }
}

struct DetailContent: View {
    let item: ClipboardItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    itemIcon
                    Text(itemTypeString)
                        .font(.headline)
                }
                Text(item.timestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                itemDetailContent
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var itemIcon: some View {
        switch item.content {
        case .text:
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
        case .image:
            Image(systemName: "photo")
                .foregroundColor(.green)
        case .file:
            Image(systemName: "doc")
                .foregroundColor(.orange)
        }
    }
    
    private var itemTypeString: String {
        switch item.content {
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .file:
            return "File"
        }
    }
    
    @ViewBuilder
    private var itemDetailContent: some View {
        switch item.content {
        case .text(let string):
            Text(string)
        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
            } else {
                Text("Unable to load image")
            }
        case .file(let path):
            VStack(alignment: .leading) {
                Text("File Path:")
                Text(path)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}


struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(tag)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}


struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var point = bounds.origin
        var lineHeight: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            if point.x + sizes[index].width > bounds.maxX {
                point.x = bounds.origin.x
                point.y += lineHeight + spacing
                lineHeight = 0
            }
            
            subview.place(at: point, proposal: .unspecified)
            
            lineHeight = max(lineHeight, sizes[index].height)
            point.x += sizes[index].width + spacing
        }
    }
    
    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> CGSize {
        var mainPosition: CGFloat = 0
        var crossPosition: CGFloat = 0
        var maxCrossPosition: CGFloat = 0
        var finalSize = CGSize.zero
        
        for size in sizes {
            if mainPosition + size.width > (proposal.width ?? .infinity) {
                mainPosition = 0
                crossPosition = maxCrossPosition + spacing
            }
            
            mainPosition += size.width + spacing
            maxCrossPosition = max(maxCrossPosition, crossPosition + size.height)
            finalSize.width = max(finalSize.width, mainPosition)
            finalSize.height = maxCrossPosition
        }
        
        return finalSize
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .frame(width: 300, height: 200)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ClipboardMonitor(viewContext: PersistenceController.preview.container.viewContext))
    }
}


extension ClipboardContent {
    var previewText: String {
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

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
