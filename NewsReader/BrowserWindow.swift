//
//  BrowserWindows.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class GroupOutlineView : NSOutlineView {
    private weak var refreshItem : NSMenuItem?
    private weak var markAsReadItem : NSMenuItem?
    private weak var silentItem : NSMenuItem?

    override func menuForEvent(event: NSEvent) -> NSMenu? {
        let point = self.convertPoint(event.locationInWindow, fromView: nil)
        let row = self.rowAtPoint(point)

        guard let view = self.viewAtColumn(0, row: row, makeIfNecessary: false) as? NSTableCellView else {
            return nil
        }

        if view.identifier != "DataCell" {
            return nil
        }

        guard let group = view.objectValue as? Group else {
            return nil
        }

        self.refreshItem?.target = group
        self.refreshItem?.enabled = true

        self.markAsReadItem?.target = group
        self.markAsReadItem?.enabled = !group.isRead

        self.silentItem?.target = group
        self.silentItem?.enabled = true
        self.silentItem?.state = group.isSilent ? NSOffState : NSOnState

        return self.menu
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.refreshItem = self.menu?.itemWithTitle("Refresh")
        self.refreshItem?.action = "refresh"

        self.markAsReadItem = self.menu?.itemWithTitle("Mark group as read")
        self.markAsReadItem?.action = "markGroupAsRead"

        self.silentItem = self.menu?.itemWithTitle("Notify on new messages")
        self.silentItem?.action = "toggleNotificationState"
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
        self.threadViewController.bind("representedObject", toObject: self.groupTreeController, withKeyPath: "selection.self", options: nil)
        self.articleViewController.bind("representedObject", toObject: self.threadViewController, withKeyPath: "selection", options: nil)
    }
}

extension BrowserWindowController : NSOutlineViewDelegate {
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        if item.representedObject is Group {
            return outlineView.makeViewWithIdentifier("DataCell", owner: self)
        } else if item.representedObject is Account {
            return outlineView.makeViewWithIdentifier("HeaderCell", owner: self)
        } else {
            return nil
        }
    }
}

extension BrowserWindowController {
    @IBAction func refreshGroups(sender: AnyObject?) {
        self.appDelegate?.refreshGroups(sender)
    }

    @IBAction func newMessage(sender: AnyObject?) {
        self.appDelegate?.newMessage(self.threadViewController.currentGroup)
    }
}