//
//  Model.swift
//  NewsReader
//
//  Created by Florent Bruneau on 16/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import AddressBook
import Lib
import News

private struct ArticleRef {
    weak var group : Group!
    let num : Int
}

class Article : NSObject {
    weak var account : Account!
    fileprivate weak var promise : Promise<NNTPPayload>?
    fileprivate weak var notification : NSUserNotification?

    var headers : MIMEHeaders
    dynamic var body : String? {
        willSet {
            let root = self.threadRoot
            if self === root || self === root.threadFirstUnread {
                self.threadRoot.willChangeValue(forKey: "threadPreviewBody")
            }
        }

        didSet {
            let root = self.threadRoot
            if self === root || self === root.threadFirstUnread {
                self.threadRoot.didChangeValue(forKey: "threadPreviewBody")
            }
        }
    }

    var replies : [Article] = [] {
        willSet {
            threadCountWillChange()
        }

        didSet {
            threadCountDidChange()
        }
    }

    weak var inReplyTo : Article? {
        willSet {
            if let previousParent = self.inReplyTo {
                if let pos = previousParent.replies.index(of: self) {
                    previousParent.replies.remove(at: pos)
                }
            } else {
                for ref in self.refs {
                    ref.group.removeThreads([self])
                }
            }
        }

        didSet {
            if let newParent = self.inReplyTo {
                newParent.replies.append(self)
            }
        }
    }
    var threadRoot : Article {
        var article = self

        while let parent = article.inReplyTo {
            article = parent
        }
        return article
    }

    lazy var msgid : String? = {
        if case .messageId(name: _, msgid: let val)? = self.headers["message-id"]?.first {
            return val
        }
        return nil
    }()

    lazy var from : String? = {
        if let contact = self.contact {
            var res = ""

            if let firstName = contact.value(forProperty: kABFirstNameProperty) as? String {
                res.append(firstName)
            }

            if let lastName = contact.value(forProperty: kABLastNameProperty) as? String {
                if !res.isEmpty {
                    res.append(Character(" "))
                }
                res.append(lastName)
            }

            if !res.isEmpty {
                return res
            }
        }

        if case .address(name: _, address: let a)? = self.headers["from"]?.first {
            return a.name == nil ? a.email : a.name
        }

        return nil
    }()

    lazy var email : String? = {
        if case .address(name: _, address: let a)? = self.headers["from"]?.first {
            return a.email
        }
        return nil
    }()

    lazy var subject : String? = {
        if case .generic(name: _, content: let c)? = self.headers["subject"]?.first  {
            return c
        }
        return nil
    }()

    lazy var date : Date? = {
        if case .date(let d)? = self.headers["date"]?.first {
            return d
        }
        return nil
    }()

    lazy var contact : ABPerson? = {
        guard let email = self.email else {
            return nil
        }

        guard let ab = ABAddressBook.shared() else {
            return nil
        }

        let pattern = ABPerson.searchElement(forProperty: kABEmailProperty, label: nil, key: nil, value: email as NSString, comparison: CFIndex(kABPrefixMatchCaseInsensitive.rawValue))

        return ab.records(matching: pattern).first as? ABPerson
    }()

    var lines : Int {
        guard let body = self.body else {
            return 0
        }

        return body.utf8.reduce(0, { $1 == 0x0a ? $0 + 1 : $0 })
    }

    var previewBody : String? {
        return self.body?.replacingOccurrences(of: "\r\n", with: " ")
                         .trimmingCharacters(in: CharacterSet.whitespaces)
    }

    fileprivate var threadCountChanging = 0
    fileprivate func threadCountWillChange() {
        let root = self.threadRoot

        root.threadCountChanging += 1
        if root.threadCountChanging != 1 {
            return
        }

        root.willChangeValue(forKey: "threadIsRead")
        root.willChangeValue(forKey: "threadUnreadCount")
        root.willChangeValue(forKey: "threadPreviewBody")
    }

    fileprivate func threadCountDidChange() {
        let root = self.threadRoot

        root.threadCountChanging -= 1
        if root.threadCountChanging != 0 {
            return
        }

        root.didChangeValue(forKey: "threadIsRead")
        root.didChangeValue(forKey: "threadUnreadCount")
        root.didChangeValue(forKey: "threadPreviewBody")
    }

    dynamic var isRead : Bool = false {
        willSet {
            if newValue == self.isRead {
                return
            }

            self.threadCountWillChange()
        }

        didSet {
            if oldValue == self.isRead {
                return
            }

            self.threadCountDidChange()

            if self.isRead {
                if let notification = self.notification {
                    let center = NSUserNotificationCenter.default

                    center.removeDeliveredNotification(notification)
                    center.removeScheduledNotification(notification)
                }
            }

            for ref in self.refs {
                if self.isRead {
                    ref.group.markAsRead(ref.num)
                } else {
                    ref.group.unmarkAsRead(ref.num)
                }
            }
        }
    }

    fileprivate func loadNewsgroups() -> String? {
        guard let dest = self.headers["newsgroups"] else {
            return nil
        }

        var out : [String] = []
        for case .newsgroup(name: _, group: let v) in dest {
            out.append(v)
        }
        return out.joined(separator: ", ")
    }

    fileprivate func loadRefs() {
        guard let dest = self.headers["xref"] else {
            return
        }

        var refs : [ArticleRef] = []
        for case .newsgroupRef(group: let name, number: let num) in dest {
            let group = self.account.group(name)

            if group.readState.isMarkedAsRead(num) {
                self.isRead = true
            }

            refs.append(ArticleRef(group: group, num: num))
        }

        if self.isRead {
            for ref in self.refs {
                ref.group.markAsRead(ref.num)
            }
        } else {
            for ref in self.refs {
                ref.group.unmarkAsRead(ref.num)
            }
        }

        self.refs = refs
    }

    var parentsIds : [String]? {
        if let references = self.headers["references"] {
            var parents : [String] = []

            // print("references \(references)")
            for case .messageId(name: _, msgid: let ref) in references {
                parents.append(ref)
            }
            return parents
        } else if case .messageId(name: _, msgid: let inReplyTo)? = self.headers["in-reply-to"]?.first {
            return [ inReplyTo ]
        }
        return nil
    }

    fileprivate var refs : [ArticleRef]
    dynamic lazy var to : String? = self.loadNewsgroups()

    lazy var contactPicture : NSImage? = {
        if let data = self.contact?.imageData() {
            return NSImage(data: data)
        } else {
            return nil
        }
    }()

    init(account : Account, ref: (group: String, num: Int), headers: MIMEHeaders) {
        self.account = account
        self.refs = [ArticleRef(group: self.account.group(ref.group), num: ref.num)]
        self.headers = headers
        super.init()
        self.loadRefs()

        if let msgid = self.msgid {
            self.account?.articleByMsgid[msgid] = self
            self.readFromFile()
        }
    }

    func writeToFile() {
    }

    func readFromFile() -> MIMEPart? {
        return nil
    }

    @discardableResult func load() -> Promise<NNTPPayload>? {
        if self.promise != nil || self.body != nil {
            return self.promise
        }

        if let msg = self.readFromFile() {
            self.promise = Promise<NNTPPayload>(success: .article(0, "", msg))
        } else if let msgid = self.msgid  {
            self.promise = self.account?.client?.sendCommand(.articleByMsgid(msgid: msgid))
        } else {
            self.promise = self.account?.client?.sendCommand(.article(group: self.refs[0].group.fullName, article: self.refs[0].num))
        }

        self.promise?.then({
            (payload) in

            guard case .article(_, _, let msg) = payload else {
                return
            }

            self.headers = msg.headers
            self.body = msg.getBodyAsPlainText()
            self.to = self.loadNewsgroups()
            self.loadRefs()
        })
        self.promise?.otherwise({
            print($0)
            self.promise = nil
        })
        return self.promise
    }
}

extension Article {
    fileprivate func doSendUserNotification() {
        if self.notification != nil {
            return
        }

        if self.isRead {
            return
        }

        let notification = NSUserNotification()

        notification.title = self.from
        notification.subtitle = self.subject
        notification.informativeText = self.previewBody
        //notification.contentImage = self.contactPicture
        notification.identifier = self.msgid

        notification.userInfo = [ "type": "article", "account": self.account.name ]
        self.notification = notification

        NSUserNotificationCenter.default
                                .scheduleNotification(notification)
    }

    func sendUserNotification() {
        if self.body != nil {
            self.doSendUserNotification()
        } else {
            self.load()?.then({
                (_) in

                self.doSendUserNotification()
            })
        }
    }
}

extension Article {
    var threadCount : Int {
        var count = 1;

        for article in self.replies {
            count += article.threadCount
        }
        return count
    }

    dynamic var threadUnreadCount : Int {
        var count = 0

        for article in self.replies {
            count += article.threadUnreadCount
        }

        if !self.isRead {
            count += 1
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
            thread.append(contentsOf: article.thread)
        }
        return thread
    }

    dynamic var threadIsRead : Bool {
        if !self.isRead {
            return false
        }

        for article in self.replies {
            if !article.threadIsRead {
                return false
            }
        }
        return true
    }

    var threadFirstUnread : Article? {
        if !self.isRead {
            return self
        }

        for article in self.replies {
            if let unread = article.threadFirstUnread {
                return unread
            }
        }

        return nil
    }

    dynamic var threadPreviewBody : String? {
        var article : Article

        if let unread = self.threadFirstUnread {
            article = unread
        } else {
            article = self
        }

        guard let body = article.previewBody else {
            article.load()
            return nil
        }

        return body
    }

    @objc func toggleThreadAsReadState() {
        self.threadCountWillChange()
        if self.threadIsRead {
            for article in self.thread {
                article.isRead = false
            }
        } else {
            for article in self.thread {
                article.isRead = true
            }
        }
        self.threadCountDidChange()
    }

    @objc func markThreadAsRead() {
        self.threadCountWillChange()
        for article in self.thread {
            article.isRead = true
        }
        self.threadCountDidChange()
    }
}
