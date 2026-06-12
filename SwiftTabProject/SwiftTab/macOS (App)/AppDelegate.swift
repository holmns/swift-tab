//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by Nawat Suangburanakul on 1/11/2568 BE.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}
