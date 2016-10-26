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
    override var isSelected : Bool {
        didSet {
            guard let accountView = self.view as? BackgroundView else {
                return
            }

            if self.isSelected {
                accountView.backgroundColor = NSColor.alternateSelectedControlColor
                (self.textField?.cell as? NSTextFieldCell)?.textColor = NSColor.alternateSelectedControlTextColor
            } else {
                accountView.backgroundColor = NSColor.white
                (self.textField?.cell as? NSTextFieldCell)?.textColor = NSColor.labelColor
            }
        }
    }
}

class PreferenceWindowController : NSWindowController {
    @IBOutlet var accountListController: NSArrayController!
    @IBOutlet weak var newAccountSheet: NSPanel!
    @IBOutlet weak var newAccountNameCell: NSTextFieldCell!

    fileprivate func loadStoredPassword(_ account: AnyObject) -> String? {
        guard let login = account.value(forKey: "login") as? String else {
            return nil
        }
        guard let hostname = account.value(forKey: "hostname") as? String else {
            return nil
        }
        guard let port = account.value(forKey: "port") as? Int else {
            return nil
        }

        do {
            return try Keychain.findGenericPassowrd("NewsReader", accountName: "\(login)@\(hostname):\(port)").0
        } catch {
            return nil
        }
    }

    fileprivate func storePassword(_ account: AnyObject) {
        guard let login = account.value(forKey: "login") as? String else {
            return
        }
        guard let hostname = account.value(forKey: "hostname") as? String else {
            return
        }
        guard let port = account.value(forKey: "port") as? Int else {
            return
        }

        let password = account.value(forKey: "password") as? String
        if password == self.loadStoredPassword(account) {
            return
        }

        do {
            _ = try Keychain.addGenericPassword("NewsReader", accountName: "\(login)@\(hostname):\(port)", password: password == nil ? "" : password!)
        } catch {
            return
        }
    }

    fileprivate func getCurrentPassword() -> String? {
        let selection = self.accountListController.selection as AnyObject

        if let password = selection.value(forKey: "password") as? String {
            if password != "" {
                return password
            }
        }

        return self.loadStoredPassword(selection)
    }

    fileprivate func reloadPasswordCell() {
        if self.accountListController.selectionIndexes.count == 0 {
            self.passwordCell.isEnabled = false
        } else {
            self.passwordCell.isEnabled = true
            self.passwordCell.objectValue = self.getCurrentPassword()
        }
    }

    fileprivate var arraySelectionContext = 0
    @IBOutlet weak var passwordCell: NSSecureTextFieldCell!
    override func windowDidLoad() {
        self.accountListController.addObserver(self, forKeyPath: "selection", options: .new, context: &self.arraySelectionContext)
        super.windowDidLoad()
        self.reloadPasswordCell()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch context {
        case (&self.arraySelectionContext)?:
            self.reloadPasswordCell()

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    @IBAction func passwordChanged(_ sender: AnyObject?) {
        let value = self.passwordCell.stringValue
        let selection = self.accountListController.selection as AnyObject

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
        let defaults = NSUserDefaultsController.shared()

        if let accounts = (defaults.values as AnyObject).value(forKey: "accounts") as? [AnyObject] {
            for i in 0..<accounts.count {
                self.storePassword(accounts[i])
                accounts[i].setValue("", forKey: "password")
            }
        }

        defaults.save(self)
    }

    func windowShouldClose(_ sender: Any) -> Bool {
        let defaults = NSUserDefaultsController.shared()

        if defaults.hasUnappliedChanges {
            let alert = NSAlert()

            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Discard")
            alert.messageText = "Save preferences?"
            alert.informativeText = "Do you want to save the changes made in the preferences?"
            alert.alertStyle = NSAlertStyle.informational

            alert.beginSheetModal(for: self.window!, completionHandler: {
                if $0 == NSAlertFirstButtonReturn {
                    self.savePreferences()
                } else {
                    defaults.discardEditing()
                }
                self.close()
            }) 
            return false
        }
        return true
    }
    
    @IBAction func addAccount(_ sender: AnyObject) {
        self.newAccountNameCell.objectValue = nil

        self.window?.beginSheet(self.newAccountSheet, completionHandler: nil)
    }

    @IBAction func createAccount(_ sender: AnyObject) {
        let name = self.newAccountNameCell.stringValue
        self.accountListController.addObject(NSMutableDictionary(dictionary: [
            "name": name,
            "enabled": true,
            "port": 119,
            "useSSL": false,
            "subscriptions": NSMutableArray(),
            "groups": NSMutableDictionary()
        ]))

        self.window?.endSheet(self.newAccountSheet)
    }

    @IBAction func cancelAccountCreation(_ sender: AnyObject) {
        self.window?.endSheet(self.newAccountSheet)
    }
}
