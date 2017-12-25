//
//  AppDelegate.swift
//  MacPaw Test
//
//  Created by Anton Barkov on 21.12.2017.
//  Copyright © 2017 Anton Barkov. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        print(urls)
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        print(filenames)
    }

    @IBAction func fileOpenAction(_ sender: Any) {
        print("'called'")
    }
}

