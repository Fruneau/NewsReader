//
//  PreferenceWindow.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Cocoa
import Lib

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

class PreferenceWindowController : NSWindowController {
    @IBOutlet var accountListController: NSArrayController!
    @IBOutlet weak var newAccountSheet: NSPanel!
    @IBOutlet weak var newAccountNameCell: NSTextFieldCell!

    private func loadStoredPassword(account: AnyObject) -> String? {
        guard let login = account.valueForKey("login") as? String else {
            return nil
        }
        guard let hostname = account.valueForKey("hostname") as? String else {
            return nil
        }
        guard let port = account.valueForKey("port") as? Int else {
            return nil
        }

        do {
            return try Keychain.findGenericPassowrd("NewsReader", accountName: "\(login)@\(hostname):\(port)").0
        } catch {
            return nil
        }
    }

    private func storePassword(account: AnyObject) {
        guard let login = account.valueForKey("login") as? String else {
            return
        }
        guard let hostname = account.valueForKey("hostname") as? String else {
            return
        }
        guard let port = account.valueForKey("port") as? Int else {
            return
        }

        let password = account.valueForKey("password") as? String
        if password == self.loadStoredPassword(account) {
            return
        }

        do {
            try Keychain.addGenericPassword("NewsReader", accountName: "\(login)@\(hostname):\(port)", password: password == nil ? "" : password!)
        } catch {
            return
        }
    }

    private func getCurrentPassword() -> String? {
        let selection = self.accountListController.selection

        if let password = selection.valueForKey("password") as? String {
            if password != "" {
                return password
            }
        }

        return self.loadStoredPassword(selection)
    }

    private func reloadPasswordCell() {
        if self.accountListController.selectionIndexes.count == 0 {
            self.passwordCell.enabled = false
        } else {
            self.passwordCell.enabled = true
            self.passwordCell.objectValue = self.getCurrentPassword()
        }
    }

    private var arraySelectionContext = 0
    @IBOutlet weak var passwordCell: NSSecureTextFieldCell!
    override func windowDidLoad() {
        self.accountListController.addObserver(self, forKeyPath: "selection", options: .New, context: &self.arraySelectionContext)
        super.windowDidLoad()
        self.reloadPasswordCell()
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.arraySelectionContext:
            self.reloadPasswordCell()

        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    @IBAction func passwordChanged(sender: AnyObject?) {
        let value = self.passwordCell.stringValue
        let selection = self.accountListController.selection

        if value == self.loadStoredPassword(selection) {
            return
        }

        if value.isEmpty {
            selection.setNilValueForKey("password")
        } else {
            selection.setValue(value, forKey: "password")
        }
    }
}

extension PreferenceWindowController : NSWindowDelegate {
    func savePreferences() {
        let defaults = NSUserDefaultsController.sharedUserDefaultsController()

        if let accounts = defaults.values.valueForKey("accounts") as? [AnyObject] {
            for i in 0..<accounts.count {
                self.storePassword(accounts[i])
                accounts[i].setValue("", forKey: "password")
            }
        }

        defaults.save(self)
    }

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
                    self.savePreferences()
                } else {
                    defaults.discardEditing()
                }
                self.close()
            }
            return false
        }
        return true
    }
    
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
            "useSSL": false,
            "subscriptions": NSMutableArray(),
            "groups": NSMutableDictionary()
        ]))

        self.window?.endSheet(self.newAccountSheet)
    }

    @IBAction func cancelAccountCreation(sender: AnyObject) {
        self.window?.endSheet(self.newAccountSheet)
    }
}
