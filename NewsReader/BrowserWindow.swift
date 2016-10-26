//
//  BrowserWindows.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class GroupOutlineView : NSOutlineView {
    fileprivate weak var refreshItem : NSMenuItem?
    fileprivate weak var markAsReadItem : NSMenuItem?
    fileprivate weak var silentItem : NSMenuItem?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = self.convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)

        guard let view = self.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView else {
            return nil
        }

        if view.identifier != "DataCell" {
            return nil
        }

        guard let group = view.objectValue as? Group else {
            return nil
        }

        self.refreshItem?.target = group
        self.refreshItem?.isEnabled = true

        self.markAsReadItem?.target = group
        self.markAsReadItem?.isEnabled = !group.isRead

        self.silentItem?.target = group
        self.silentItem?.isEnabled = true
        self.silentItem?.state = group.isSilent ? NSOffState : NSOnState

        return self.menu
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.refreshItem = self.menu?.item(withTitle: "Refresh")
        self.refreshItem?.action = #selector(Group.refresh)

        self.markAsReadItem = self.menu?.item(withTitle: "Mark group as read")
        self.markAsReadItem?.action = #selector(Group.markGroupAsRead)

        self.silentItem = self.menu?.item(withTitle: "Notify on new messages")
        self.silentItem?.action = #selector(Group.toggleNotificationState)
    }
}

class BrowserWindowController : NSWindowController {
    weak var appDelegate: AppDelegate?

    @IBOutlet weak var groupTreeController: NSTreeController!
    @IBOutlet weak var threadViewController: ThreadViewController!
    @IBOutlet var articleViewController: NSViewController!

    /* Groups view */
    dynamic var groupRoots : [AnyObject] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        self.threadViewController.bind("representedObject", to: self.groupTreeController, withKeyPath: "selection.self", options: nil)
        self.articleViewController.bind("representedObject", to: self.threadViewController, withKeyPath: "selection", options: nil)
    }
}

extension BrowserWindowController : NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if (item as AnyObject).representedObject is Group {
            return outlineView.make(withIdentifier: "DataCell", owner: self)
        } else if (item as AnyObject).representedObject is Account {
            return outlineView.make(withIdentifier: "HeaderCell", owner: self)
        } else {
            return nil
        }
    }
}

extension BrowserWindowController {
    @IBAction func refreshGroups(_ sender: AnyObject?) {
        self.appDelegate?.refreshGroups(sender)
    }

    @IBAction func newMessage(_ sender: AnyObject?) {
        self.appDelegate?.newMessage(self.threadViewController.currentGroup)
    }
}
