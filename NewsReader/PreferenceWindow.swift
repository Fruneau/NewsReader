//
//  PreferenceWindow.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Cocoa

class PreferenceWindowController : NSWindowController, NSWindowDelegate {
    func windowShouldClose(sender: AnyObject) -> Bool {
        let defaults = NSUserDefaultsController.sharedUserDefaultsController()

        if defaults.hasUnappliedChanges {
            let alert = NSAlert()

            alert.addButtonWithTitle("Save")
            alert.addButtonWithTitle("Discard")
            alert.messageText = "Save preferences?"
            alert.informativeText = "Do you want to save the changes made in the preferences?"
            alert.alertStyle = NSAlertStyle.InformationalAlertStyle

            alert.beginSheetModalForWindow(self.window!) {
                if $0 == NSAlertFirstButtonReturn {
                    defaults.save(self)
                } else {
                    defaults.discardEditing()
                }
                self.window?.close()
            }
            return false
        }
        return true
    }

}