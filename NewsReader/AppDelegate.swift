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
    let num : Int
    let headers : MIMEHeaders

    lazy var msgid : String? = {
        guard let hdr = self.headers["message-id"]?.first else {
            return nil
        }

        switch (hdr) {
        case .Generic(name: _, content: let val):
            return val

        default:
            return nil
        }
    }()

    lazy var from : String? = {
        guard let from = self.headers["from"]?.first else {
            return nil
        }

        switch (from) {
        case .Address(name: _, address: let a):
            return a.name == nil ? a.email : a.name

        default:
            return nil
        }
    }()

    lazy var subject : String? = {
        guard let subject = self.headers["subject"]?.first else {
            return nil
        }

        switch (subject) {
        case .Generic(name: _, content: let c):
            return c

        default:
            return nil
        }
    }()

    lazy var date : NSDate? = {
        guard let date = self.headers["date"]?.first else {
            return nil
        }

        switch date {
        case .Date(let d):
            return d

        default:
            return nil
        }
    }()

    init(num: Int, headers: MIMEHeaders) {
        self.num = num
        self.headers = headers
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
class AppDelegate: NSObject, NSApplicationDelegate, NSOutlineViewDelegate {

    @IBOutlet weak var window: NSWindow!

    /* Groups view */
    @IBOutlet weak var groupView: NSOutlineView!
    @IBOutlet weak var groupTreeController: NSTreeController!
    var groupRoots = [GroupTree(root: "Groups")]
    var groupIndexes : [NSIndexPath] = [] {
        didSet {
            self.threadsPromise?.cancel()

            if self.groupIndexes.count == 0 {
                self.threadArrayController.removeObjects(self.threads)
                return
            }

            let group = self.groupTreeController.selectedObjects[0] as! GroupTree
            self.threadsPromise = self.nntp?.sendCommand(.Group(group.name)).thenChain({
                (payload) throws in

                print("got reply")
                guard let nntp = self.nntp else {
                    throw NNTPError.ServerProtocolError
                }

                switch payload {
                case .GroupContent(_, let count, let lowestNumber, let highestNumber, _):
                    let from = count > 1000 ? max(lowestNumber, highestNumber - 1000) : lowestNumber

                    print("requesting from \(from)")
                    return nntp.sendCommand(.Over(ArticleRangeOrId.From(from)))

                default:
                    throw NNTPError.ServerProtocolError
                }
            })
            self.threadsPromise?.then({
                (payload) throws in

                switch(payload) {
                case .Overview(let messages):
                    self.threadArrayController.removeObjects(self.threads)

                    print("have articles")
                    var articles : [Article] = []
                    for msg in messages.reverse() {
                        articles.append(Article(num: msg.num, headers: msg.headers))
                    }
                    self.threadArrayController.addObjects(articles)

                default:
                    throw NNTPError.ServerProtocolError
                }
            }).otherwise({
                (var error) in

                switch (error) {
                case PromiseError.UncaughtError(let e, _):
                    error = e

                default:
                    break
                }

                switch (error) {
                case NNTPError.MalformedOverviewLine(let l):
                    print("Error: \(l)")

                default:
                    print("Other: \(error)")
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
            self.articlePormise = self.nntp?.sendCommand(.Article(ArticleId.MessageId(msgid!))).then({
                (payload) in

                switch (payload) {
                case .Article(_, _, let msg):
                    self.articleView.string = msg.body

                default:
                    throw NNTPError.ServerProtocolError
                }
            }, otherwise: {
                (error) in

                switch (error) {
                case let a where a is News.Error:
                    print("NewsError \((error as! News.Error).detail)")

                default:
                    print("error \(error)")
                }
            })
        }
    }

    /* Article view */
    @IBOutlet var articleView: NSTextView!
    weak var articlePormise : Promise<Void>?

    /* Model handling */
    var nntp : NNTP?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.threadView.minItemSize = NSMakeSize(200, 37)
        self.threadView.maxItemSize = NSMakeSize(600, 37)
    }

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