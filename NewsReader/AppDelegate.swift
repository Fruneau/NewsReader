//
//  AppDelegate.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//


import Cocoa
import AddressBook
import Lib
import News

enum Error : ErrorType {
    case NoMessage
}

class Article : NSObject {
    private weak var nntp : NNTP?
    private weak var promise : Promise<NNTPPayload>?

    var headers : MIMEHeaders
    dynamic var body : String?

    lazy var msgid : String? = {
        if case .Generic(name: _, content: let val)? = self.headers["message-id"]?.first {
            return val
        }
        return nil
    }()

    lazy var from : String? = {
        if let contact = self.contact {
            var res = ""

            if let firstName = contact.valueForProperty(kABFirstNameProperty) as? String {
                res.extend(firstName)
            }

            if let lastName = contact.valueForProperty(kABLastNameProperty) as? String {
                if !res.isEmpty {
                    res.append(Character(" "))
                }
                res.extend(lastName)
            }

            if !res.isEmpty {
                return res
            }
        }

        if case .Address(name: _, address: let a)? = self.headers["from"]?.first {
            return a.name == nil ? a.email : a.name
        }

        return nil
    }()

    lazy var email : String? = {
        if case .Address(name: _, address: let a)? = self.headers["from"]?.first {
            return a.email
        }
        return nil
    }()

    lazy var subject : String? = {
        if case .Generic(name: _, content: let c)? = self.headers["subject"]?.first  {
            return c
        }
        return nil
    }()

    lazy var date : NSDate? = {
        if case .Date(let d)? = self.headers["date"]?.first {
            return d
        }
        return nil
    }()

    lazy var contact : ABPerson? = {
        guard let email = self.email else {
            return nil
        }

        guard let ab = ABAddressBook.sharedAddressBook() else {
            return nil
        }

        let pattern = ABPerson.searchElementForProperty(kABEmailProperty, label: nil, key: nil, value: email as NSString, comparison: CFIndex(kABPrefixMatchCaseInsensitive.rawValue))

        return ab.recordsMatchingSearchElement(pattern).first as? ABPerson
    }()

    private func loadNewsgroups() -> String? {
        guard let dest = self.headers["newsgroups"] else {
            return nil
        }

        var out : [String] = []
        for case .Newsgroup(name: _, group: let v) in dest {
            out.append(v)
        }
        return ", ".join(out)
    }

    private func loadRefs() {
        guard let dest = self.headers["xref"] else {
            return
        }

        var refs : [(String, Int)] = []
        for case .NewsgroupRef(group: let group, number: let num) in dest {
            refs.append((group, num))
        }
        self.refs = refs
    }

    var refs : [(String, Int)]
    dynamic lazy var to : String? = self.loadNewsgroups()

    lazy var contactPicture : NSImage? = {
        if let data = self.contact?.imageData() {
            return NSImage(data: data)
        } else {
            return nil
        }
    }()

    init(nntp : NNTP?, ref: (String, Int), headers: MIMEHeaders) {
        self.nntp = nntp
        self.refs = [ref]
        self.headers = headers
        super.init()
        self.loadRefs()
    }

    func load() {
        if self.promise != nil {
            return
        }

        if let msgid = self.msgid  {
            self.promise = self.nntp?.sendCommand(.Article(ArticleId.MessageId(msgid)))
        } else {
            self.promise = self.nntp?.sendCommand(.Article(ArticleId.Number(self.refs[0].1)),
                inGroup: self.refs[0].0)
        }

        self.promise?.then({
            (payload) in

            guard case .Article(_, _, let msg) = payload else {
                return
            }

            self.headers = msg.headers
            self.body = msg.body
            self.to = self.loadNewsgroups()
            self.loadRefs()
        })
    }

    func cancelLoad() {
        self.promise?.cancel()
    }
}

class GroupTree : NSObject {
    let name : String
    var fullName : String?
    var shortDesc : String?

    var unreadCount : Int? {
        didSet {
            if let count = self.unreadCount {
                self.unreadCountText = "\(count)"
            } else {
                self.unreadCountText = nil
            }
        }
    }
    dynamic var unreadCountText : String?

    let isRoot : Bool
    var children : [String: GroupTree] = [:]

    var isLeaf : Bool {
        return self.fullName != nil || self.isRoot
    }

    init(root: String) {
        self.name = root
        self.isRoot = true
        super.init()
    }

    init(nntp : NNTP?, node: String) {
        self.name = node
        self.isRoot = false
        self.nntp = nntp
        super.init()
    }

    func addGroup(fullName: String, shortDesc: String?) {
        var node = self

        for tok in split(fullName.characters, isSeparator: { $0 == "." }) {
            let str = String(tok)

            if let child = node.children[str] {
                node = child
            } else {
                let child = GroupTree(nntp: self.nntp, node: str)

                node.children[str] = child
                node = child
            }
        }

        node.fullName = fullName
        node.shortDesc = shortDesc
    }

    dynamic var threads : [Article]?
    private weak var nntp : NNTP?
    private weak var promise : Promise<NNTPPayload>?
    var selection = NSIndexSet() {
        didSet {
            if self.selection.count == 0 {
                return
            }

            self.threads?[self.selection.firstIndex].load()
        }
    }

    func load() {
        if self.threads != nil || self.fullName == nil {
            return
        }

        self.promise = self.nntp?.sendCommand(.Group(self.fullName!)).thenChain({
            (payload) throws in

            guard let nntp = self.nntp else {
                throw NNTPError.ServerProtocolError
            }

            guard case .GroupContent(_, let count, let lowestNumber, let highestNumber, _) = payload else {
                throw NNTPError.ServerProtocolError
            }

            let from = count > 1000 ? max(lowestNumber, highestNumber - 1000) : lowestNumber

            self.unreadCount = count
            return nntp.sendCommand(.Over(ArticleRangeOrId.From(from)), inGroup: self.fullName!)
        })
        self.promise?.then({
            (payload) throws in

            guard case .Overview(let messages) = payload else {
                throw NNTPError.ServerProtocolError
            }

            var articles : [Article] = []
            for msg in messages.reverse() {
                articles.append(Article(nntp: self.nntp, ref: (self.fullName!, msg.num),
                    headers: msg.headers))
            }
            self.threads = articles
        }).otherwise({
            (var error) in

            if case PromiseError.UncaughtError(let e, _) = error {
                error = e
            }

            switch (error) {
            case NNTPError.MalformedOverviewLine(let l):
                print("Error: \(l)")

            default:
                print("Other: \(error)")
            }
        })
    }

    func refreshCount() {
        self.nntp?.sendCommand(.Group(self.fullName!)).then({
            (payload) throws in

            guard case .GroupContent(_, let count, _, _, _) = payload else {
                return
            }

            self.unreadCount = count
        })
    }
}

class BackgroundView : NSView {
    override func drawRect(dirtyRect: NSRect) {
        NSColor.whiteColor().set()
        NSRectFill(dirtyRect)
    }
}

class UserBadgeView : NSImageView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true

        self.layer!.borderWidth = 0
        self.layer!.cornerRadius = self.bounds.size.width / 2
        self.layer!.masksToBounds = true
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
    @IBOutlet weak var groupTreeController: NSTreeController!
    dynamic var groupRoots = [GroupTree(root: "Groups")]
    var groupIndexes : [NSIndexPath] = [] {
        didSet {
            if self.groupIndexes.count == 0 {
                return
            }

            let group = self.groupTreeController.selectedObjects[0] as! GroupTree
            group.load()
        }
    }

    /* Thread view */
    @IBOutlet weak var threadView: NSCollectionView!

    /* Model handling */
    var nntp : NNTP?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.threadView.minItemSize = NSMakeSize(0, 37)
        self.threadView.maxItemSize = NSMakeSize(0, 37)
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
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

            guard case .GroupList(let list) = payload else {
                throw NNTPError.ServerProtocolError
            }

            for (groupName, shortDesc) in list {
                let group = GroupTree(nntp: self.nntp, node: groupName)

                group.fullName = groupName
                group.shortDesc = shortDesc
                self.groupRoots.append(group)
                group.refreshCount()
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