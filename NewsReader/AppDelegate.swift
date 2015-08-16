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

    func loadAccount(account: AnyObject) -> Account? {
        guard let enabled = account.valueForKey("enabled") as? Bool else {
            return nil
        }
        if !enabled {
            return nil
        }

        guard let a = Account(account: account) else {
            return nil
        }

        a.client?.sendCommand(.ListNewsgroups(nil)).then({
            (payload) in

            guard case .GroupList(let list) = payload else {
                throw NNTPError.ServerProtocolError
            }

            for (groupName, shortDesc) in list {
                let group = GroupTree(nntp: a.client, node: groupName)

                group.fullName = groupName
                group.shortDesc = shortDesc
                self.browserWindowController?.groupRoots.append(group)
                group.refreshCount()
            }
        }).otherwise({ (e) in debugPrint(e) })

        return a
    }

    func reloadAccounts() {
        guard let accounts = NSUserDefaults.standardUserDefaults().arrayForKey("accounts") as? [[String: AnyObject]] else {
            return
        }

        var oldAccounts = self.accounts
        var newAccounts : [String: Account] = [:]

        for account in accounts {
            guard let name = account["name"] as? String else {
                continue
            }

            if let old = oldAccounts.removeValueForKey(name) {
                old.update(account)
                newAccounts[name] = old
            } else {
                guard let client = self.loadAccount(account) else {
                    continue
                }
                newAccounts[name] = client
            }
        }

        for account in oldAccounts {
            account.1.client?.disconnect()
        }

        self.accounts = newAccounts
    }

    private var accountUpdateContext = 0
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.accountUpdateContext:
            self.reloadAccounts()

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