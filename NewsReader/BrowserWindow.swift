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
    dynamic var groupRoots : [Group] = []
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
        let node = item.representedObject as! Group

        return outlineView.makeViewWithIdentifier(node.isRoot ? "HeaderCell" : "DataCell", owner: self)
    }
}