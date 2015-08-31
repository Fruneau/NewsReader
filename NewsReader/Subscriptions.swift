//
//  Subscriptions.swift
//  NewsReader
//
//  Created by Florent Bruneau on 16/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Cocoa
import Lib
import News

class SubscriptionController : NSObject {
    var account : Account?
    var data = NSMutableDictionary(dictionary: [ "children": NSMutableDictionary() ])
    weak var promise : Promise<NNTPPayload>?

    @IBOutlet weak var accountListController: NSArrayController!
    @IBOutlet weak var subscriptionView: NSOutlineView!
    @IBOutlet weak var groupColumn: NSTableColumn!
    @IBOutlet weak var accountTabs: NSTabView!
    @IBOutlet weak var subscriptionsTab: NSTabViewItem!

    private func reloadAccount() {
        if self.account != nil {
            if self.account?.id == self.accountListController.selectionIndexes.firstIndex {
                return
            }
        }

        self.promise?.cancel()
        self.account = nil
        (self.data["children"] as! NSMutableDictionary).removeAllObjects()
        self.subscriptionView.reloadData()

        if self.accountTabs.selectedTabViewItem !== self.subscriptionsTab {
            return
        }

        if self.accountListController.selectionIndexes.count == 0 {
            return
        }

        self.account = Account(accountId: self.accountListController.selectionIndexes.firstIndex,
                               account: self.accountListController.selection,
                               cacheRoot: nil)
        self.promise = self.account?.client?.sendCommand(.ListNewsgroups(nil))
        self.promise?.then({
            (payload) in

            guard case .GroupList(let list) = payload else {
                throw NNTPError.ServerProtocolError
            }

            self.data["children"] = NSMutableDictionary()
            for (groupName, shortDesc) in list {
                let leaf = groupName.characters.split(".").reduce(self.data) {
                    (table, token) in

                    let str = String(token)
                    let children = table["children"] as! NSMutableDictionary

                    if let node = children[str] {
                        return node as! NSMutableDictionary
                    }

                    let res = NSMutableDictionary(dictionary: [
                        "children": NSMutableDictionary(),
                        "name": str
                    ])
                    children[str] = res
                    return res
                }

                leaf["fullname"] = groupName
                leaf["description"] = shortDesc
                leaf["subscribed"] = self.account!.groups[groupName]?.subscribed
            }
            self.subscriptionView.reloadData()
        }).otherwise({ (e) in debugPrint(e) })

    }

    private var accountListContext = 0
    override func awakeFromNib() {
        super.awakeFromNib()

        self.accountListController.addObserver(self, forKeyPath: "selectionIndexes", options: [], context: &self.accountListContext)
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.accountListContext:
            self.reloadAccount()

        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}

extension SubscriptionController : NSTabViewDelegate {
    func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem?) {
        print("reload because tab changed")
        self.reloadAccount()
    }
}

extension SubscriptionController : NSOutlineViewDataSource {
    private func getDict(item: AnyObject?) -> NSDictionary {
        if item == nil {
            return self.data
        } else {
            return item! as! NSDictionary
        }
    }

    private func getChildren(item: AnyObject?) -> NSDictionary {
        return self.getDict(item)["children"] as! NSDictionary
    }

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        return self.getChildren(item).allValues.sort({ ($0["name"] as! String) < ($1["name"] as! String) })[index]
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return self.getChildren(item).count != 0
    }

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        return self.getChildren(item).count
    }

    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        let dict = self.getDict(item)

        if dict["fullname"] != nil || tableColumn === self.groupColumn {
            return item
        } else {
            return nil
        }
    }
}

extension SubscriptionController : NSOutlineViewDelegate {
    @IBAction func changeSubscription(sender: NSButton) {
        guard let cell = sender.superview as? NSTableCellView else {
            return
        }

        guard let dict = cell.objectValue as? NSDictionary else {
            assert (false)
            return
        }

        guard let fullname = dict["fullname"] as? String else {
            assert (false)
            return
        }

        guard let subscriptions = self.accountListController.selection.valueForKey("subscriptions") as? NSMutableArray else {
            assert (false)
            return
        }

        let pos = subscriptions.indexOfObject(fullname)

        switch sender.state {
        case NSOnState:
            if pos == NSNotFound {
                subscriptions.addObject(fullname)
            }

        case NSOffState:
            if pos != NSNotFound {
                subscriptions.removeObjectAtIndex(pos)
            }

        default:
            assert (false)
        }
    }
}