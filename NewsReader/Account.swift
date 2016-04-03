//
//  Account.swift
//  NewsReader
//
//  Created by Florent Bruneau on 16/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Lib
import News

private enum Error : ErrorType {
    case NotConnected
}

class Account : NSObject {
    var id : Int
    let name : String

    var host : String
    var port : Int
    var useSSL : Bool
    var login : String?
    var password : String?

    var client : NNTPClient?
    var connectionError : ErrorType?
    var isDisconnected = false {
        didSet {
            if !self.isDisconnected {
                self.connectionError = nil
                self.refreshSubscriptions()
            }
        }
    }

    var shortDesc : String {
        return "\(host):\(port)"
    }

    let children : [AnyObject] = []
    let isLeaf : Bool = true

    var groups : [String: Group] = [:]
    var subscriptions : [Group] = []

    var userName : String
    var userEmail : String

    var articleByMsgid : [String: Article] = [:]
    var orphanArticles : [String: Set<Article>] = [:]

    let cacheRoot : NSURL?
    let cacheGroups : NSURL?
    let cacheMessages : NSURL?
    var reloadCron : NSTimer?
    var synchronizeCacheCron : NSTimer?
    let processingQueue = NSOperationQueue()

    private static func getAccountParameters(account: AnyObject)
        -> (name: String, host: String, port: Int, useSSL: Bool,
            login: String?, password: String?,
        subscriptions: Set<String>, userName: String, userEmail: String)?
    {
        guard let name = account.valueForKey("name") as? String else {
            return nil
        }
        guard let host = account.valueForKey("hostname") as? String else {
            return nil
        }
        guard let port = account.valueForKey("port") as? Int else {
            return nil
        }
        guard let useSSL = account.valueForKey("useSSL") as? Bool else {
            return nil
        }

        let login = account.valueForKey("login") as? String
        var password : String? = nil

        if let alogin = login {
            do {
                password = try Keychain.findGenericPassowrd("NewsReader", accountName: "\(alogin)@\(host):\(port)").0
            } catch {
                return nil
            }
        }

        var subscriptions : Set<String>
        if let asubscriptions = account.valueForKey("subscriptions") as? NSArray {
            subscriptions = Set<String>(asubscriptions.map { $0 as! String })
        } else {
            subscriptions = Set<String>()
        }

        var userName : String
        if let storedUserName = account.valueForKey("userName") as? String {
            userName = storedUserName
        } else {
            userName = "Anonymous Coward"
        }

        var userEmail : String
        if let storedUserEmail = account.valueForKey("userEmail") as? String {
            userEmail = storedUserEmail
        } else {
            userEmail = "anonymous@example.com"
        }

        return (name: name, host: host, port: port, useSSL: useSSL,
            login: login, password: password,
            subscriptions: subscriptions, userName: userName, userEmail: userEmail)
    }

    private var groupUnreadCountContext = 0

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.groupUnreadCountContext:
            self.willChangeValueForKey("unreadCount")
            self.didChangeValueForKey("unreadCount")

        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    private func reloadSubscriptions(subscriptions: Set<String>) {
        self.subscriptions.forEach {
            $0.subscribed = false
            $0.removeObserver(self, forKeyPath: "unreadCount")
        }
        self.subscriptions = subscriptions.map {
            let group = self.group($0)

            group.subscribed = true
            group.addObserver(self, forKeyPath: "unreadCount", options: .New, context: &self.groupUnreadCountContext)
            group.load()
            return group
        }

        self.subscriptions.sortInPlace { $0.fullName < $1.fullName }
    }

    private func connect() {
        self.client = NNTPClient(host: host, port: port, ssl: useSSL)
        self.client?.delegate = self
        self.client?.setCredentials(login, password: password)
        self.client?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.client?.connect()
    }

    @objc func refreshSubscriptions() {
        for group in self.subscriptions {
            group.refresh()
        }
    }

    @objc func synchronizeCache() {
        for group in self.subscriptions {
            group.synchronizeCache()
        }
    }

    init(accountId: Int, account: AnyObject, cacheRoot: NSURL?) {
        let params = Account.getAccountParameters(account)!
        
        self.cacheRoot = cacheRoot
        self.cacheGroups = cacheRoot?.URLByAppendingPathComponent("Groups", isDirectory: true)
        self.cacheMessages = cacheRoot?.URLByAppendingPathComponent("Messages", isDirectory: true)
        self.id = accountId
        self.name = params.name
        self.host = params.host
        self.port = params.port
        self.useSSL = params.useSSL
        self.login = params.login
        self.password = params.password
        self.userName = params.userName
        self.userEmail = params.userEmail
        super.init()

        if cacheRoot != nil {
            let fileManager = NSFileManager.defaultManager()
            try! fileManager.createDirectoryAtURL(self.cacheRoot!, withIntermediateDirectories: true, attributes: nil)
            try! fileManager.createDirectoryAtURL(self.cacheGroups!, withIntermediateDirectories: true, attributes: nil)
            try! fileManager.createDirectoryAtURL(self.cacheMessages!, withIntermediateDirectories: true, attributes: nil)
        }

        self.connect()
        self.reloadSubscriptions(params.subscriptions)

        self.reloadCron = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: #selector(Account.refreshSubscriptions), userInfo: nil, repeats: true)
        self.synchronizeCacheCron = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: #selector(Group.synchronizeCache), userInfo: nil, repeats: true)
    }

    deinit {
        self.subscriptions.forEach {
            $0.removeObserver(self, forKeyPath: "unreadCount")
        }

        self.client?.disconnect()
        self.client = nil
    }

    func update(accountId: Int, account: AnyObject) -> Bool {
        self.id = accountId

        guard let params = Account.getAccountParameters(account) else {
            return false
        }

        if params.userName != self.userName || params.userEmail != self.userEmail {
            self.userName = params.userName
            self.userEmail = params.userEmail
        }

        if params.host != self.host || params.port != self.port || params.useSSL != self.useSSL
            || params.login != self.login || params.password != self.password
        {
            self.client?.disconnect()
            self.host = params.host
            self.port = params.port
            self.useSSL = params.useSSL
            self.login = params.login
            self.password = params.password
            self.connect()
        }

        let oldSubs = Set<String>(self.subscriptions.map { $0.fullName })
        if oldSubs != params.subscriptions {
            self.reloadSubscriptions(params.subscriptions)
            return true
        }
        return false
    }

    func group(name: String) -> Group {
        if let group = self.groups[name] {
            return group
        } else {
            let group = Group(account: self, fullName: name, shortDesc: nil)

            self.groups[name] = group
            return group
        }
    }

    private func findArticleParent(article: Article) -> Article? {
        assert (article.inReplyTo == nil)

        guard let parentIds = article.parentsIds else {
            return nil
        }

        for parentId in parentIds.reverse() {
            guard let parent = self.articleByMsgid[parentId] else {
                var orphans = self.orphanArticles[parentId]

                if orphans == nil {
                    orphans = []
                }
                orphans?.insert(article)
                self.orphanArticles[parentId] = orphans!
                continue
            }

            if parent === article {
                continue
            }

            return parent
        }
        return nil
    }

    private func relocateArticle(child: Article, asReplyTo article: Article) {
        child.inReplyTo = article

        guard let parentIds = article.parentsIds else {
            return
        }

        var foundArticleId = false
        for parentId in parentIds.reverse() {
            if foundArticleId {
                self.orphanArticles[parentId]?.remove(child)
            } else if parentId == article.msgid {
                foundArticleId = true
            }
        }
    }

    func article(ref: (group: String, num: Int), headers: MIMEHeaders) -> Article {
        guard case .MessageId(name: _, msgid: let msgid)? = headers["message-id"]?.first else {
            return Article(account: self, ref: ref, headers: headers)
        }

        if let article = self.articleByMsgid[msgid] {
            return article
        }

        let article = Article(account: self, ref: ref, headers: headers)

        self.articleByMsgid[msgid] = article
        if let articles = self.orphanArticles.removeValueForKey(msgid) {
            for child in articles {
                self.relocateArticle(child, asReplyTo: article)
            }
        }

        article.inReplyTo = self.findArticleParent(article)
        return article
    }

    dynamic var unreadCount : Int {
        var unreadCount = 0

        for group in self.subscriptions {
            unreadCount += group.unreadCount
        }
        return unreadCount
    }
}

extension Account : NNTPClientDelegate {
    func nntpClient(client: NNTPClient, onEvent event: NNTPClientEvent) {
        switch event {
        case .Connected:
            self.isDisconnected = false
            self.refreshSubscriptions()

        case .Disconnected:
            self.isDisconnected = true
            self.connectionError = Error.NotConnected

        case .Error(let error):
            self.isDisconnected = true
            self.connectionError = error
        }
    }
}