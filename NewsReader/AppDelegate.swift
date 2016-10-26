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
    override class func initialize() {
        self.exposeBinding("backgroundColor")
    }

    @IBInspectable var backgroundColor : NSColor? {
        didSet {
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if let background = self.backgroundColor {
            background.set()
            NSRectFill(dirtyRect)
        }
    }
}

@IBDesignable
class UserBadgeView : NSImageView {
    override func awakeFromNib() {
        super.awakeFromNib()

        self.wantsLayer = true

        self.layer?.frame = self.frame
        self.layer?.borderWidth = 0
        self.layer?.cornerRadius = self.frame.size.width / 2
        self.layer?.masksToBounds = true
    }
}

class ShortDateFormatter : Formatter {
    fileprivate static let todayFormatter : DateFormatter = {
        let f = DateFormatter();

        f.doesRelativeDateFormatting = true
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }();

    fileprivate static let oldFormatter : DateFormatter = {
        let f = DateFormatter()

        f.doesRelativeDateFormatting = true
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    override func string(for obj: Any?) -> String? {
        guard let date = obj as? Date else {
            return nil
        }

        if date.compare(Date(timeIntervalSinceNow: -44200)) == .orderedAscending {
            return ShortDateFormatter.oldFormatter.string(for: obj)
        } else {
            return ShortDateFormatter.todayFormatter.string(for: obj)
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var browserWindowController: BrowserWindowController?
    var preferenceWindowController : PreferenceWindowController?
    var editionWindowControllers : [EditionWindow] = []
    var applicationCache : URL!

    /* Model handling */
    var accounts : [String: Account] = [:]

    override func awakeFromNib() {
        super.awakeFromNib()
        self.browserWindowController = BrowserWindowController(windowNibName: "BrowserWindow")
        self.browserWindowController?.appDelegate = self
    }

    func loadAccount(_ accountId: Int, account: AnyObject) -> Account? {
        guard let enabled = account.value(forKey: "enabled") as? Bool else {
            return nil
        }
        if !enabled {
            return nil
        }

        let cacheRoot = self.applicationCache.appendingPathComponent("\(accountId)", isDirectory: true)


        return Account(accountId: accountId, account: account, cacheRoot: cacheRoot)
    }

    fileprivate func refreshApplicationUnreadCount() {
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
        guard let accounts = UserDefaults.standard.array(forKey: "accounts") as? [[String: Any]] else {
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

            if let old = oldAccounts.removeValue(forKey: name) {
                hasChanges = hasChanges || old.update(id, account: account as AnyObject)
                newAccounts[name] = old
            } else {
                guard let client = self.loadAccount(id, account: account as AnyObject) else {
                    continue
                }
                client.addObserver(self, forKeyPath: "unreadCount", options: .new, context: &self.accountUnreadCountChangeContext)
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

    fileprivate var accountUnreadCountChangeContext = 0
    fileprivate var accountUpdateContext = 0
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch context {
        case (&self.accountUpdateContext)?:
            self.reloadAccounts()

        case (&self.accountUnreadCountChangeContext)?:
            self.refreshApplicationUnreadCount()

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSUserDefaultsController.shared().appliesImmediately = false
        UserDefaults.standard.register(defaults: [
            "accounts": [[String: Any]]()
        ])

        let fileManager = FileManager.default
        let cacheRoot = try! fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        self.applicationCache = cacheRoot.appendingPathComponent("fr.mymind.NewsReader", isDirectory: true)

        try! fileManager.createDirectory(at: self.applicationCache, withIntermediateDirectories: true, attributes: nil)


        UserDefaults.standard.addObserver(self, forKeyPath: "accounts",
            options: NSKeyValueObservingOptions.new, context: &self.accountUpdateContext)
        self.reloadAccounts()
        self.browserWindowController?.showWindow(self)

        NSUserNotificationCenter.default.delegate = self
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            return false
        } else {
            self.browserWindowController?.window?.makeKeyAndOrderFront(self)
            return true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for account in self.accounts {
            account.1.client?.disconnect()
            account.1.synchronizeCache()
        }
    }

    @IBAction func openPreferences(_ sender: Any) {
        if self.preferenceWindowController == nil {
            self.preferenceWindowController = PreferenceWindowController(windowNibName: "PreferenceWindow")
        }

        self.preferenceWindowController?.showWindow(self)
    }
}

extension AppDelegate : NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        guard let name = notification.userInfo?["account"] as? String else {
            return false
        }
        
        guard let account = self.accounts[name] else {
            return false
        }

        guard let id = notification.identifier else {
            return false
        }

        guard let article = account.articleByMsgid[id] else {
            return false
        }

        return !article.isRead
    }
}

extension AppDelegate {
    @IBAction func refreshGroups(_ sender: Any?) {
        for account in self.accounts {
            account.1.refreshSubscriptions()
        }
    }

    fileprivate func buildEditionWindow(_ sender: Any?) -> EditionWindow {
        switch sender {
        case let a as Account:
            return EditionWindow(newMessageForAccount: a)

        case let g as Group:
            return EditionWindow(newMessageInGroup: g)

        case let a as Article:
            return EditionWindow(replyToArticle: a)

        default:
            return EditionWindow(newMessageForAccount: self.accounts.first!.1)
        }
    }

    @IBAction func newMessage(_ sender: Any?) {
        let editorWindow = self.buildEditionWindow(sender)

        editorWindow.showWindow(self)
        self.editionWindowControllers.append(editorWindow)
    }
}
