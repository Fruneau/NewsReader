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

class Article : NSObject {
    private weak var account : Account?
    private weak var promise : Promise<NNTPPayload>?

    var headers : MIMEHeaders
    dynamic var body : String?

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
        }

        didSet {
            self.threadRoot.didChangeValueForKey("threadIsRead")

            for ref in self.refs {
                if self.isRead {
                    self.account?.group(ref.0).markAsRead(ref.1)
                } else {
                    self.account?.group(ref.0).unmarkAsRead(ref.1)
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

        var refs : [(String, Int)] = []
        for case .NewsgroupRef(group: let group, number: let num) in dest {
            refs.append((group, num))
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

    var refs : [(String, Int)]
    dynamic lazy var to : String? = self.loadNewsgroups()

    lazy var contactPicture : NSImage? = {
        if let data = self.contact?.imageData() {
            return NSImage(data: data)
        } else {
            return nil
        }
    }()

    init(account : Account?, ref: (String, Int), headers: MIMEHeaders) {
        self.account = account
        self.refs = [ref]
        self.headers = headers
        super.init()
        self.loadRefs()
    }

    func load() -> Promise<NNTPPayload>? {
        if self.promise != nil || self.body != nil {
            return self.promise
        }

        if let msgid = self.msgid  {
            self.promise = self.account?.client?.sendCommand(.ArticleByMsgid(msgid: msgid))
        } else {
            self.promise = self.account?.client?.sendCommand(.Article(group: self.refs[0].0, article: self.refs[0].1))
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

    var threadUnreadCount : Int {
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

    var threadIsRead : Bool {
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
}