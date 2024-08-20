//
//  QuickLookPreview.swift
//  AdvancedClipboardManager
//
//  Created by Emmanuel  Asaber on 8/20/24.
//

import SwiftUI
import Quartz

struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> QLPreviewView {
        let preview = QLPreviewView(frame: .zero, style: .normal)
        preview?.autostarts = true
        return preview ?? QLPreviewView()
    }
    
    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}
