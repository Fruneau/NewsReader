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

    fileprivate func reloadAccount() {
        if self.account != nil {
            if self.account?.id == self.accountListController.selectionIndexes.first {
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

        self.account = Account(accountId: self.accountListController.selectionIndexes.first!,
                               account: self.accountListController.selection as AnyObject,
                               cacheRoot: nil)
        self.promise = self.account?.client?.sendCommand(.listNewsgroups(nil))
        self.promise?.then({
            (payload) in

            guard case .groupList(let list) = payload else {
                throw NNTPError.serverProtocolError
            }

            self.data["children"] = NSMutableDictionary()
            for (groupName, shortDesc) in list {
                let leaf = groupName.characters.split { $0 == "."}.reduce(self.data) {
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

    fileprivate var accountListContext = 0
    override func awakeFromNib() {
        super.awakeFromNib()

        self.accountListController.addObserver(self, forKeyPath: "selectionIndexes", options: [], context: &self.accountListContext)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch context {
        case (&self.accountListContext)?:
            self.reloadAccount()

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

extension SubscriptionController : NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        print("reload because tab changed")
        self.reloadAccount()
    }
}

extension SubscriptionController : NSOutlineViewDataSource {
    fileprivate func getDict(_ item: Any?) -> NSDictionary {
        if item == nil {
            return self.data
        } else {
            return item! as! NSDictionary
        }
    }

    fileprivate func getChildren(_ item: Any?) -> NSDictionary {
        return self.getDict(item)["children"] as! NSDictionary
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return self.getChildren(item as AnyObject?).allValues.sorted(by: { (($0 as AnyObject)["name"] as! String) < (($1 as AnyObject)["name"] as! String) })[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return self.getChildren(item as AnyObject?).count != 0
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return self.getChildren(item as AnyObject?).count
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let dict = self.getDict(item as AnyObject?)

        if dict["fullname"] != nil || tableColumn === self.groupColumn {
            return item
        } else {
            return nil
        }
    }
}

extension SubscriptionController : NSOutlineViewDelegate {
    @IBAction func changeSubscription(_ sender: NSButton) {
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

        guard let subscriptions = (self.accountListController.selection as AnyObject).value(forKey: "subscriptions") as? NSMutableArray else {
            assert (false)
            return
        }

        let pos = subscriptions.index(of: fullname)

        switch sender.state {
        case NSOnState:
            if pos == NSNotFound {
                subscriptions.add(fullname)
            }

        case NSOffState:
            if pos != NSNotFound {
                subscriptions.removeObject(at: pos)
            }

        default:
            assert (false)
        }
    }
}
