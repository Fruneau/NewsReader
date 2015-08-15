//
//  PreferenceWindow.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Cocoa

class AccountItem : NSCollectionViewItem {
    override var selected : Bool {
        didSet {
            guard let accountView = self.view as? BackgroundView else {
                return
            }

            if self.selected {
                accountView.backgroundColor = NSColor.alternateSelectedControlColor()
                (self.textField?.cell as? NSTextFieldCell)?.textColor = NSColor.alternateSelectedControlTextColor()
            } else {
                accountView.backgroundColor = NSColor.whiteColor()
                (self.textField?.cell as? NSTextFieldCell)?.textColor = NSColor.labelColor()
            }
        }
    }
}

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

    @IBOutlet var accountListController: NSArrayController!
    @IBOutlet weak var newAccountSheet: NSPanel!
    @IBOutlet weak var newAccountNameCell: NSTextFieldCell!

    @IBAction func addAccount(sender: AnyObject) {
        self.newAccountNameCell.objectValue = nil

        self.window?.beginSheet(self.newAccountSheet, completionHandler: nil)
    }

    @IBAction func createAccount(sender: AnyObject) {
        let name = self.newAccountNameCell.stringValue
        self.accountListController.addObject(NSMutableDictionary(dictionary: [
            "name": name,
            "enabled": true,
            "port": 465,
            "useSSL": false
        ]))

        self.window?.endSheet(self.newAccountSheet)
    }

    @IBAction func cancelAccountCreation(sender: AnyObject) {
        self.window?.endSheet(self.newAccountSheet)
    }
}