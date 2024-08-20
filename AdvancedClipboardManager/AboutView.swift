//
//  AboutView.swift
//  AdvancedClipboardManager
//
//  Created by Emmanuel  Asaber on 8/20/24.
//

import SwiftUI

struct AboutView: View {
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ClipBuddy"
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 128, height: 128)
            
            Text(appName)
                .font(.title)
            
            Text("Version \(version) (\(build))")
                .font(.subheadline)
            
            Text("© 2024 Lashpixel")
                .font(.caption)
            
            Text("ClipBuddy is a powerful tool for managing your clipboard history with ease.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Visit Website") {
                if let url = URL(string: "https://lashpixel.com") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .frame(width: 300, height: 400)
        .padding()
    }
}
