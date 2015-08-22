//
//  AppDelegate.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa
import Lib
import News

@IBDesignable
class BackgroundView : NSView {
    @IBInspectable var backgroundColor : NSColor? {
        didSet {
            self.needsDisplay = true
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        if let background = self.backgroundColor {
            background.set()
            NSRectFill(dirtyRect)
        }
    }
}

@IBDesignable
class UserBadgeView : NSImageView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.wantsLayer = true

        self.layer?.borderWidth = 0
        self.layer?.cornerRadius = self.bounds.size.width / 2
        self.layer?.masksToBounds = true
    }
}

class ShortDateFormatter : NSFormatter {
    private static let todayFormatter : NSDateFormatter = {
        let f = NSDateFormatter();

        f.doesRelativeDateFormatting = true
        f.dateStyle = .NoStyle
        f.timeStyle = .ShortStyle
        return f
    }();

    private static let oldFormatter : NSDateFormatter = {
        let f = NSDateFormatter()

        f.doesRelativeDateFormatting = true
        f.dateStyle = .ShortStyle
        f.timeStyle = .NoStyle
        return f
    }()

    override func stringForObjectValue(obj: AnyObject) -> String? {
        guard let date = obj as? NSDate else {
            return nil
        }

        if date.compare(NSDate(timeIntervalSinceNow: -44200)) == .OrderedAscending {
            return ShortDateFormatter.oldFormatter.stringForObjectValue(obj)
        } else {
            return ShortDateFormatter.todayFormatter.stringForObjectValue(obj)
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var browserWindowController: BrowserWindowController?
    var preferenceWindowController : PreferenceWindowController?

    /* Model handling */
    var accounts : [String: Account] = [:]

    override func awakeFromNib() {
        super.awakeFromNib()
        self.browserWindowController = BrowserWindowController(windowNibName: "BrowserWindow")
        self.browserWindowController?.appDelegate = self
    }

    func loadAccount(accountId: Int, account: AnyObject) -> Account? {
        guard let enabled = account.valueForKey("enabled") as? Bool else {
            return nil
        }
        if !enabled {
            return nil
        }

        return Account(accountId: accountId, account: account)
    }

    private func refreshApplicationUnreadCount() {
        var unreadCount = 0

        for account in self.accounts.values {
            unreadCount += account.unreadCount
        }

        if unreadCount == 0 {
            NSApp.dockTile.badgeLabel = nil
        } else {
            NSApp.dockTile.badgeLabel = String(unreadCount)
        }
    }

    func reloadAccounts() {
        guard let accounts = NSUserDefaults.standardUserDefaults().arrayForKey("accounts") as? [[String: AnyObject]] else {
            return
        }

        var oldAccounts = self.accounts
        var newAccounts : [String: Account] = [:]
        var hasChanges = false

        for id in 0..<accounts.count {
            let account = accounts[id]
            guard let name = account["name"] as? String else {
                continue
            }

            if let old = oldAccounts.removeValueForKey(name) {
                hasChanges = hasChanges || old.update(id, account: account)
                newAccounts[name] = old
            } else {
                guard let client = self.loadAccount(id, account: account) else {
                    continue
                }
                client.addObserver(self, forKeyPath: "unreadCount", options: .New, context: &self.accountUnreadCountChangeContext)
                newAccounts[name] = client
                hasChanges = true
            }
        }

        for account in oldAccounts {
            hasChanges = true
            account.1.client?.disconnect()
            account.1.removeObserver(self, forKeyPath: "unreadCount")
        }


        if hasChanges {
            self.accounts = newAccounts
            self.browserWindowController?.groupRoots.removeAll()

            for account in self.accounts.values {
                self.browserWindowController?.groupRoots.append(account)
                for group in account.subscriptions {
                    self.browserWindowController?.groupRoots.append(group)
                }
            }
            self.refreshApplicationUnreadCount()
        }
    }

    private var accountUnreadCountChangeContext = 0
    private var accountUpdateContext = 0
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.accountUpdateContext:
            self.reloadAccounts()

        case &self.accountUnreadCountChangeContext:
            self.refreshApplicationUnreadCount()

        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        NSUserDefaultsController.sharedUserDefaultsController().appliesImmediately = false
        NSUserDefaults.standardUserDefaults().registerDefaults([
            "accounts": [[String: AnyObject]]()
        ])

        NSUserDefaults.standardUserDefaults().addObserver(self, forKeyPath: "accounts",
            options: NSKeyValueObservingOptions.New, context: &self.accountUpdateContext)
        self.reloadAccounts()
        self.browserWindowController?.showWindow(self)
    }

    func applicationWillTerminate(notification: NSNotification) {
        for account in self.accounts {
            account.1.client?.disconnect()
        }
    }

    @IBAction func openPreferences(sender: AnyObject) {
        if self.preferenceWindowController == nil {
            self.preferenceWindowController = PreferenceWindowController(windowNibName: "PreferenceWindow")
        }

        self.preferenceWindowController?.showWindow(self)
    }
}