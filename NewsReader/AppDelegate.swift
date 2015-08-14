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

protocol ArticleDelegate : class {
    func articleUpdated(article: Article)
}

class Article : NSObject {
    private weak var nntp : NNTPClient?
    private weak var promise : Promise<NNTPPayload>?
    weak var delegate : ArticleDelegate?

    var headers : MIMEHeaders
    dynamic var body : String?
    var replies : [Article] = []
    weak var inReplyTo : Article?

    lazy var msgid : String? = {
        if case .MessageId(name: _, msgid: let val)? = self.headers["message-id"]?.first {
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

    var threadCount : Int {
        var count = 1;

        for article in self.replies {
            count += article.threadCount
        }
        return count
    }

    var threadDepth : Int {
        var depth = 0;

        for article in self.replies {
            depth = max(depth, article.threadDepth)
        }
        return depth + 1
    }

    var thread : [Article] {
        var thread : [Article] = [self]

        for article in self.replies {
            thread.extend(article.thread)
        }
        return thread
    }

    var lines : Int {
        guard let body = self.body else {
            return 0
        }

        return body.utf8.reduce(0, combine: { $1 == 0x0a ? $0 + 1 : $0 })
    }

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

    private var parentsIds : [String]? {
        if let references = self.headers["references"] {
            var parents : [String] = []

            for case .MessageId(name: _, msgid: let ref) in references {
                parents.append(ref)
            }
            return parents
        } else if case .MessageId(name: _, msgid: let inReplyTo)? = self.headers["in-reply-to"]?.first {
            return [ inReplyTo ]
        }
        return nil
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

    init(nntp : NNTPClient?, ref: (String, Int), headers: MIMEHeaders) {
        self.nntp = nntp
        self.refs = [ref]
        self.headers = headers
        super.init()
        self.loadRefs()
    }

    func load() {
        if self.promise != nil || self.body != nil {
            return
        }

        if let msgid = self.msgid  {
            self.promise = self.nntp?.sendCommand(.ArticleByMsgid(msgid: msgid))
        } else {
            self.promise = self.nntp?.sendCommand(.Article(group: self.refs[0].0, article: self.refs[0].1))
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
            self.delegate?.articleUpdated(self)
        })
    }

    func cancelLoad() {
        self.promise?.cancel()
    }
}

protocol GroupTreeDelegate : class {
    func groupTree(groupTree: GroupTree, hasNewThreads: [Article])
}

class GroupTree : NSObject {
    private weak var nntp : NNTPClient?
    private weak var promise : Promise<NNTPPayload>?
    weak var delegate : GroupTreeDelegate?

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

    init(nntp : NNTPClient?, node: String) {
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

    var articleByMsgid : [String: Article] = [:]
    dynamic var articles : [Article]?
    dynamic var roots : [Article]?

    func load() {
        if self.articles != nil || self.fullName == nil {
            return
        }

        self.promise = self.nntp?.sendCommand(.Group(group: self.fullName!)).thenChain({
            (payload) throws in

            guard let nntp = self.nntp else {
                throw NNTPError.ServerProtocolError
            }

            guard case .GroupContent(_, let count, let lowestNumber, let highestNumber, _) = payload else {
                throw NNTPError.ServerProtocolError
            }

            let from = count > 1000 ? max(lowestNumber, highestNumber - 1000) : lowestNumber

            self.unreadCount = count
            return nntp.sendCommand(.Over(group: self.fullName!, range: NNTPCommand.ArticleRange.From(from)))
        })
        self.promise?.then({
            (payload) throws in

            guard case .Overview(let messages) = payload else {
                throw NNTPError.ServerProtocolError
            }

            var articles : [Article] = []
            var roots : [Article] = []
            for msg in messages.reverse() {
                let article = Article(nntp: self.nntp, ref: (self.fullName!, msg.num),
                    headers: msg.headers)

                articles.append(article)

                if let msgid = article.msgid {
                    self.articleByMsgid[msgid] = article
                }
            }

            threads: for article in articles {
                if let parentIds = article.parentsIds {
                    for parentId in parentIds {
                        guard let parent = self.articleByMsgid[parentId] else {
                            continue
                        }

                        if parent === article {
                            continue
                        }

                        article.inReplyTo = parent
                        parent.replies.append(article)
                        continue threads
                    }
                }
                roots.append(article)
            }

            self.articles = articles
            self.roots = roots
            self.delegate?.groupTree(self, hasNewThreads: roots)
            print("added \(roots.count) roots")
        }).otherwise({
            (error) in

            print("\(error)")
        })
    }

    func refreshCount() {
        self.nntp?.sendCommand(.Group(group: self.fullName!)).then({
            (payload) throws in

            guard case .GroupContent(_, let count, _, _, _) = payload else {
                return
            }

            self.unreadCount = count
        })
    }
}

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

    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var threadViewController: ThreadViewController!

    /* Groups view */
    @IBOutlet weak var groupTreeController: NSTreeController!
    dynamic var groupRoots = [GroupTree(root: "Groups")]
    var groupIndexes : [NSIndexPath] = [] {
        didSet {
            if self.groupIndexes.count == 0 {
                self.threadViewController.currentGroup = nil
            } else {
                self.threadViewController.currentGroup = self.groupTreeController.selectedObjects[0] as? GroupTree
            }
        }
    }

    /* Model handling */
    var nntp : NNTPClient?

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
        self.nntp = NNTPClient(url: url)

        self.nntp?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.nntp?.connect()

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
}

extension AppDelegate : NSOutlineViewDelegate {
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        let node = item.representedObject as! GroupTree

        return outlineView.makeViewWithIdentifier(node.isRoot ? "HeaderCell" : "DataCell", owner: self)
    }
}