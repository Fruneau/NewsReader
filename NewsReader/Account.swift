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

private enum Error : Swift.Error {
    case notConnected
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
    var connectionError : Swift.Error?
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

    let children : [Any] = []
    let isLeaf : Bool = true

    var groups : [String: Group] = [:]
    var subscriptions : [Group] = []

    var userName : String
    var userEmail : String

    var articleByMsgid : [String: Article] = [:]
    var orphanArticles : [String: Set<Article>] = [:]

    let cacheRoot : URL?
    let cacheGroups : URL?
    let cacheMessages : URL?
    var reloadCron : Timer?
    var synchronizeCacheCron : Timer?
    let processingQueue = OperationQueue()

    fileprivate static func getAccountParameters(_ account: AnyObject)
        -> (name: String, host: String, port: Int, useSSL: Bool,
            login: String?, password: String?,
        subscriptions: Set<String>, userName: String, userEmail: String)?
    {
        guard let name = account.value(forKey: "name") as? String else {
            return nil
        }
        guard let host = account.value(forKey: "hostname") as? String else {
            return nil
        }
        guard let port = account.value(forKey: "port") as? Int else {
            return nil
        }
        guard let useSSL = account.value(forKey: "useSSL") as? Bool else {
            return nil
        }

        let login = account.value(forKey: "login") as? String
        var password : String? = nil

        if let alogin = login {
            do {
                password = try Keychain.findGenericPassowrd("NewsReader", accountName: "\(alogin)@\(host):\(port)").0
            } catch {
                return nil
            }
        }

        var subscriptions : Set<String>
        if let asubscriptions = account.value(forKey: "subscriptions") as? NSArray {
            subscriptions = Set<String>(asubscriptions.map { $0 as! String })
        } else {
            subscriptions = Set<String>()
        }

        var userName : String
        if let storedUserName = account.value(forKey: "userName") as? String {
            userName = storedUserName
        } else {
            userName = "Anonymous Coward"
        }

        var userEmail : String
        if let storedUserEmail = account.value(forKey: "userEmail") as? String {
            userEmail = storedUserEmail
        } else {
            userEmail = "anonymous@example.com"
        }

        return (name: name, host: host, port: port, useSSL: useSSL,
            login: login, password: password,
            subscriptions: subscriptions, userName: userName, userEmail: userEmail)
    }

    fileprivate var groupUnreadCountContext = 0

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch context {
        case (&self.groupUnreadCountContext)?:
            self.willChangeValue(forKey: "unreadCount")
            self.didChangeValue(forKey: "unreadCount")

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    fileprivate func reloadSubscriptions(_ subscriptions: Set<String>) {
        self.subscriptions.forEach {
            $0.subscribed = false
            $0.removeObserver(self, forKeyPath: "unreadCount")
        }
        self.subscriptions = subscriptions.map {
            let group = self.group($0)

            group.subscribed = true
            group.addObserver(self, forKeyPath: "unreadCount", options: .new, context: &self.groupUnreadCountContext)
            group.load()
            return group
        }

        self.subscriptions.sort { $0.fullName < $1.fullName }
    }

    fileprivate func connect() {
        self.client = NNTPClient(host: host, port: port, ssl: useSSL)
        self.client?.delegate = self
        self.client?.setCredentials(login, password: password)
        self.client?.scheduleInRunLoop(RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode.rawValue)
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

    init(accountId: Int, account: AnyObject, cacheRoot: URL?) {
        let params = Account.getAccountParameters(account)!
        
        self.cacheRoot = cacheRoot
        self.cacheGroups = cacheRoot?.appendingPathComponent("Groups", isDirectory: true)
        self.cacheMessages = cacheRoot?.appendingPathComponent("Messages", isDirectory: true)
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
            let fileManager = FileManager.default
            try! fileManager.createDirectory(at: self.cacheRoot!, withIntermediateDirectories: true, attributes: nil)
            try! fileManager.createDirectory(at: self.cacheGroups!, withIntermediateDirectories: true, attributes: nil)
            try! fileManager.createDirectory(at: self.cacheMessages!, withIntermediateDirectories: true, attributes: nil)
        }

        self.connect()
        self.reloadSubscriptions(params.subscriptions)

        self.reloadCron = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(Account.refreshSubscriptions), userInfo: nil, repeats: true)
        self.synchronizeCacheCron = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(Group.synchronizeCache), userInfo: nil, repeats: true)
    }

    deinit {
        self.subscriptions.forEach {
            $0.removeObserver(self, forKeyPath: "unreadCount")
        }

        self.client?.disconnect()
        self.client = nil
    }

    func update(_ accountId: Int, account: AnyObject) -> Bool {
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

    func group(_ name: String) -> Group {
        if let group = self.groups[name] {
            return group
        } else {
            let group = Group(account: self, fullName: name, shortDesc: nil)

            self.groups[name] = group
            return group
        }
    }

    fileprivate func findArticleParent(_ article: Article) -> Article? {
        assert (article.inReplyTo == nil)

        guard let parentIds = article.parentsIds else {
            return nil
        }

        for parentId in parentIds.reversed() {
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

    fileprivate func relocateArticle(_ child: Article, asReplyTo article: Article) {
        child.inReplyTo = article

        guard let parentIds = article.parentsIds else {
            return
        }

        var foundArticleId = false
        for parentId in parentIds.reversed() {
            if foundArticleId {
                _ = self.orphanArticles[parentId]?.remove(child)
            } else if parentId == article.msgid {
                foundArticleId = true
            }
        }
    }

    func article(_ ref: (group: String, num: Int), headers: MIMEHeaders) -> Article {
        guard case .messageId(name: _, msgid: let msgid)? = headers["message-id"]?.first else {
            return Article(account: self, ref: ref, headers: headers)
        }

        if let article = self.articleByMsgid[msgid] {
            return article
        }

        let article = Article(account: self, ref: ref, headers: headers)

        self.articleByMsgid[msgid] = article
        if let articles = self.orphanArticles.removeValue(forKey: msgid) {
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
    func nntpClient(_ client: NNTPClient, onEvent event: NNTPClientEvent) {
        switch event {
        case .connected:
            self.isDisconnected = false
            self.refreshSubscriptions()

        case .disconnected:
            self.isDisconnected = true
            self.connectionError = Error.notConnected

        case .error(let error):
            self.isDisconnected = true
            self.connectionError = error
        }
    }
}
