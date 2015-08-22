//
//  BrowserWindows.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class BrowserWindowController : NSWindowController {
    weak var appDelegate: AppDelegate?

    @IBOutlet weak var threadViewController: ThreadViewController!

    /* Groups view */
    @IBOutlet weak var groupTreeController: NSTreeController!
    dynamic var groupRoots : [AnyObject] = []
    var groupIndexes : [NSIndexPath] = [] {
        didSet {
            if self.groupIndexes.count == 0 {
                self.threadViewController.currentGroup = nil
            } else {
                self.threadViewController.currentGroup = self.groupTreeController.selectedObjects[0] as? Group
            }
        }
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