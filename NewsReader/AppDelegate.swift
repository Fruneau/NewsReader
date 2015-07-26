//
//  AppDelegate.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//


import Cocoa

enum Error : ErrorType {
    case NoMessage
}

class GroupTree : NSObject {
    let name : String
    var fullName : String?
    var shortDesc : String?
    let isRoot : Bool
    var children : [String: GroupTree] = [:]

    var childrenCount : Int {
        return self.children.count
    }

    var isLeaf : Bool {
        return self.fullName != nil || self.isRoot
    }

    init(root: String) {
        self.name = root
        self.isRoot = true
        super.init()
    }

    init(node: String) {
        self.name = node
        self.isRoot = false
        super.init()
    }

    func addGroup(fullName: String, shortDesc: String?) {
        var node = self

        for tok in split(fullName.characters, isSeparator: { $0 == "." }) {
            let str = String(tok)

            if let child = node.children[str] {
                node = child
            } else {
                let child = GroupTree(node: str)

                node.children[str] = child
                node = child
            }
        }

        node.fullName = fullName
        node.shortDesc = shortDesc
    }
}

class Article : NSObject {
    let msgid : String
    let num : Int

    init(msgid: String, num: Int) {
        self.msgid = msgid
        self.num = num
        super.init()
    }
}

class SelectableView : NSView {
    var selected = false {
        didSet {
            self.needsDisplay = true
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        if selected {
            NSColor.alternateSelectedControlColor().set()
            NSRectFill(self.bounds)
        }
    }
}

class SelectableCollectionViewItem : NSCollectionViewItem {
    override var selected : Bool {
        didSet {
            (self.view as? SelectableView)?.selected = selected
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSOutlineViewDelegate {

    @IBOutlet weak var window: NSWindow!

    /* Groups view */
    @IBOutlet weak var groupView: NSOutlineView!
    @IBOutlet weak var groupTreeController: NSTreeController!
    var groupRoots = [GroupTree(root: "Groups")]
    var groupIndexes : [NSIndexPath] = [] {
        didSet {
            let date = NSDate(timeIntervalSinceNow: -365 * 86400)

            self.threadsPromise?.cancel()

            if self.groupIndexes.count == 0 {
                self.threadArrayController.removeObjects(self.threads)
                return
            }

            let group = self.groupTreeController.selectedObjects[0] as! GroupTree
            self.threadsPromise = self.nntp?.listArticles(group.name, since: date)
            self.threadsPromise?.then({
                (payload) throws in

                switch (payload) {
                case .MessageIds(let msgids):
                    self.threadArrayController.removeObjects(self.threads)

                    var articles : [Article] = []
                    for msg in msgids.reverse() {
                        articles.append(Article(msgid: msg, num: 0))

                        if articles.count == 1000 {
                            break
                        }
                    }
                    self.threadArrayController.addObjects(articles)

                default:
                    throw NNTPError.ServerProtocolError
                }
            })
        }
    }

    /* Thread view */
    @IBOutlet weak var threadView: NSCollectionView!
    @IBOutlet weak var threadArrayController: NSArrayController!
    var threads : [Article] = []
    weak var threadsPromise : Promise<NNTPPayload>?
    var threadIndexes = NSIndexSet() {
        didSet {
            self.articlePormise?.cancel()

            if self.threadIndexes.count == 0 {
                self.articleView.string = ""
                return
            }

            let msgid = self.threads[self.threadIndexes.firstIndex].msgid
            self.articlePormise = self.nntp?.sendCommand(.Article(ArticleId.MessageId(msgid)))
            self.articlePormise?.then({
                (payload) in

                switch (payload) {
                case .Article(_, _, let raw):
                    self.articleView.string = raw

                default:
                    throw NNTPError.ServerProtocolError
                }
            })
        }
    }

    /* Article view */
    @IBOutlet var articleView: NSTextView!
    weak var articlePormise : Promise<NNTPPayload>?

    /* Model handling */
    var nntp : NNTP?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        self.groupView.setDelegate(self)
        self.nntp = nil
        guard var rcContent = NSData(contentsOfFile: "~/.newsreaderrc".stringByStandardizingPath)?.utf8String else {
            return
        }

        if let idx = rcContent.characters.indexOf("\n") {
            rcContent = rcContent.substringToIndex(idx)
        }

        guard let url = NSURL(string: rcContent) else {
            return
        }
        self.nntp = NNTP(url: url)

        self.nntp?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.nntp?.open()

        self.nntp?.sendCommand(.ListNewsgroups(nil)).then({
            (payload) in

            switch (payload) {
            case .GroupList(let list):
                for (groupName, shortDesc) in list {
                    let group = GroupTree(node: groupName)

                    group.fullName = groupName
                    group.shortDesc = shortDesc
                    self.groupTreeController.addObject(group)
                }
                self.groupView.reloadItem(nil, reloadChildren: true)

            default:
                throw NNTPError.ServerProtocolError
            }
        })
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        let node = item.representedObject as! GroupTree

        return outlineView.makeViewWithIdentifier(node.isRoot ? "HeaderCell" : "DataCell", owner: self)
    }
}