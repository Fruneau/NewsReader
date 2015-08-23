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
    private weak var account : Account!
    private weak var promise : Promise<NNTPPayload>?

    var headers : MIMEHeaders
    dynamic var body : String? {
        willSet {
            if self === self.threadRoot.threadFirstUnread {
                self.threadRoot.willChangeValueForKey("threadPreviewBody")
            }
        }

        didSet {
            if self === self.threadRoot.threadFirstUnread {
                self.threadRoot.didChangeValueForKey("threadPreviewBody")
            }
        }
    }

    var replies : [Article] = []
    weak var inReplyTo : Article?
    var threadRoot : Article {
        var article = self

        while let parent = article.inReplyTo {
            article = parent
        }
        return article
    }

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

    var lines : Int {
        guard let body = self.body else {
            return 0
        }

        return body.utf8.reduce(0, combine: { $1 == 0x0a ? $0 + 1 : $0 })
    }

    dynamic var isRead : Bool = false {
        willSet {
            self.threadRoot.willChangeValueForKey("threadIsRead")
            self.threadRoot.willChangeValueForKey("threadUnreadCount")
            self.threadRoot.willChangeValueForKey("threadPreviewBody")
        }

        didSet {
            self.threadRoot.didChangeValueForKey("threadIsRead")
            self.threadRoot.didChangeValueForKey("threadUnreadCount")
            self.threadRoot.didChangeValueForKey("threadPreviewBody")

            for ref in self.refs {
                if self.isRead {
                    ref.group.markAsRead(ref.num)
                } else {
                    ref.group.unmarkAsRead(ref.num)
                }
            }
        }
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

        var refs : [ArticleRef] = []
        for case .NewsgroupRef(group: let name, number: let num) in dest {
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

            for case .MessageId(name: _, msgid: let ref) in references {
                parents.append(ref)
            }
            return parents
        } else if case .MessageId(name: _, msgid: let inReplyTo)? = self.headers["in-reply-to"]?.first {
            return [ inReplyTo ]
        }
        return nil
    }

    private var refs : [ArticleRef]
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

    func load() -> Promise<NNTPPayload>? {
        if self.promise != nil || self.body != nil {
            return self.promise
        }

        if let msg = self.readFromFile() {
            self.promise = Promise<NNTPPayload>(success: .Article(0, "", msg))
        } else if let msgid = self.msgid  {
            self.promise = self.account?.client?.sendCommand(.ArticleByMsgid(msgid: msgid))
        } else {
            self.promise = self.account?.client?.sendCommand(.Article(group: self.refs[0].group.fullName, article: self.refs[0].num))
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
        return self.promise
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
            count++
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

        guard let body = article.body else {
            article.load()
            return nil
        }

        return body.stringByReplacingOccurrencesOfString("\r\n", withString: " ")
                   .stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    }
}