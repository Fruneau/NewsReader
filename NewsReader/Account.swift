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

class Account : NSObject {
    var id : Int
    let name : String
    var host : String
    var port : Int
    var useSSL : Bool
    var login : String?
    var password : String?

    var client : NNTPClient?

    var shortDesc : String {
        return "\(host):\(port)"
    }

    let children : [AnyObject] = []
    let isLeaf : Bool = true

    var groups : [String: Group] = [:]
    var subscriptions : [Group] = []

    var articleByMsgid : [String: Article] = [:]

    private static func getAccountParameters(account: AnyObject)
        -> (name: String, host: String, port: Int, useSSL: Bool,
            login: String?, password: String?,
            subscriptions: Set<String>)?
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

        return (name: name, host: host, port: port, useSSL: useSSL,
            login: login, password: password,
            subscriptions: subscriptions)
    }

    private func refreshSubscriptions(subscriptions: Set<String>) {
        self.subscriptions.forEach {
            $0.subscribed = false
        }
        self.subscriptions = subscriptions.map {
            let group = self.group($0)

            group.subscribed = true
            group.load()
            return group
        }
    }

    private func connect() {
        self.client = NNTPClient(host: host, port: port, ssl: useSSL)
        self.client?.setCredentials(login, password: password)
        self.client?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.client?.connect()
    }

    init(accountId: Int, account: AnyObject) {
        guard let params = Account.getAccountParameters(account) else {
            assert (false)
        }

        self.id = accountId
        self.name = params.name
        self.host = params.host
        self.port = params.port
        self.useSSL = params.useSSL
        self.login = params.login
        self.password = params.password
        super.init()

        self.connect()
        self.refreshSubscriptions(params.subscriptions)
    }

    deinit {
        self.client?.disconnect()
        self.client = nil
    }

    func update(accountId: Int, account: AnyObject) -> Bool {
        self.id = accountId

        guard let params = Account.getAccountParameters(account) else {
            return false
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
            self.refreshSubscriptions(params.subscriptions)
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

    func article(ref: (group: String, num: Int), headers: MIMEHeaders) -> Article {
        guard case .MessageId(name: _, msgid: let msgid)? = headers["message-id"]?.first else {
            return Article(account: self, ref: ref, headers: headers)
        }

        if let article = self.articleByMsgid[msgid] {
            return article
        }

        let article = Article(account: self, ref: ref, headers: headers)

        self.articleByMsgid[msgid] = article
        return article
    }
}