//
//  AdvancedClipboardManagerApp.swift
//  AdvancedClipboardManager
//
//  Created by Emmanuel  Asaber on 8/20/24.
//

import SwiftUI

@main
struct AdvancedClipboardManagerApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(ClipboardMonitor(viewContext: persistenceController.container.viewContext))
        }
    }
}
