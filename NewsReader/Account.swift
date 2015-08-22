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

    private func refreshSubscriptions(subscriptions: Set<String>) {
        self.subscriptions.forEach {
            $0.subscribed = false
        }
        self.subscriptions = subscriptions.map {
            let group = self.group($0)

            group.subscribed = true
            return group
        }
    }

    private func connect() {
        self.client = NNTPClient(host: host, port: port, ssl: useSSL)
        self.client?.setCredentials(login, password: password)
        self.client?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.client?.connect()
    }

    init(name: String, host: String, port: Int, useSSL : Bool, login: String?, password: String?, subscriptions: Set<String>) {
        self.name = name
        self.host = host
        self.port = port
        self.useSSL = useSSL
        self.login = login
        self.password = password

        super.init()
        self.refreshSubscriptions(subscriptions)
        self.connect()
    }

    convenience init?(name: String, host: String, port: Int, useSSL : Bool, login: String?, subscriptions: Set<String>) {
        var password : String?

        if let alogin = login {
            do {
                password = try Keychain.findGenericPassowrd("NewsReader", accountName: "\(alogin)@\(host):\(port)").0
            } catch {
                return nil
            }
        }
        self.init(name: name, host: host, port: port, useSSL: useSSL, login: login, password: password, subscriptions: subscriptions)
    }

    convenience init?(account: AnyObject) {
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

        var subscriptions : Set<String>
        if let asubscriptions = account.valueForKey("subscriptions") as? NSArray {
            subscriptions = Set<String>(asubscriptions.map { $0 as! String })
        } else {
            subscriptions = Set<String>()
        }

        self.init(name: name, host: host, port: port, useSSL: useSSL, login: login, subscriptions: subscriptions)
    }

    deinit {
        self.client?.disconnect()
        self.client = nil
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

    func update(host: String, port: Int, useSSL : Bool, login: String?, password: String?, subscriptions: Set<String>) {
        if host == self.host && port == self.port && useSSL == self.useSSL && login == self.login && password == self.password {
            return
        }

        self.client?.disconnect()
        self.host = host
        self.port = port
        self.useSSL = useSSL
        self.login = login
        self.password = password

        self.refreshSubscriptions(subscriptions)
        self.connect()
    }

    func update(host: String, port: Int, useSSL : Bool, login: String?, subscriptions: Set<String>) {
        var password : String?

        if let alogin = login {
            do {
                password = try Keychain.findGenericPassowrd("NewsReader", accountName: "\(alogin)@\(host):\(port)").0
            } catch {
                return
            }
        }

        self.update(host, port: port, useSSL: useSSL, login: login, password: password, subscriptions: subscriptions)
    }

    func update(account: AnyObject) {
        guard let host = account.valueForKey("hostname") as? String else {
            return
        }
        guard let port = account.valueForKey("port") as? Int else {
            return
        }
        guard let useSSL = account.valueForKey("useSSL") as? Bool else {
            return
        }

        let login = account["login"] as? String

        var subscriptions : Set<String>
        if let asubscriptions = account.valueForKey("subscriptions") as? NSArray {
            subscriptions = Set<String>(asubscriptions.map { $0 as! String })
        } else {
            subscriptions = Set<String>()
        }

        self.update(host, port: port, useSSL: useSSL, login: login, subscriptions: subscriptions)
    }
}