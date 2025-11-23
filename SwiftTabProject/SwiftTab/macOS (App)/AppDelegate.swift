//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Nawat Suangburanakul on 1/11/2568 BE.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force the entire app (AppKit + SwiftUI) to render in Dark Mode regardless of system setting.
        let darkAppearance = NSAppearance(named: .darkAqua)
        NSApp.appearance = darkAppearance
        NSApp.windows.forEach { $0.appearance = darkAppearance }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}
