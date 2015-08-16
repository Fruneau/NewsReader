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

class Account {
    var host : String
    var port : Int
    var useSSL : Bool
    var login : String?
    var password : String?

    var client : NNTPClient?

    init(host: String, port: Int, useSSL : Bool, login: String?, password: String?) {
        self.host = host
        self.port = port
        self.useSSL = useSSL
        self.login = login
        self.password = password

        self.client = NNTPClient(host: host, port: port, ssl: useSSL)
        self.client?.setCredentials(login, password: password)
        self.client?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.client?.connect()
    }

    convenience init?(host: String, port: Int, useSSL : Bool, login: String?) {
        var password : String?

        if let alogin = login {
            do {
                password = try Keychain.findGenericPassowrd("NewsReader", accountName: "\(alogin)@\(host):\(port)").0
            } catch {
                return nil
            }
        }
        self.init(host: host, port: port, useSSL: useSSL, login: login, password: password)
    }

    convenience init?(account: AnyObject) {
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

        self.init(host: host, port: port, useSSL: useSSL, login: login)
    }

    deinit {
        self.client?.disconnect()
        self.client = nil
    }

    func update(host: String, port: Int, useSSL : Bool, login: String?, password: String?) {
        if host == self.host && port == self.port && useSSL == self.useSSL && login == self.login && password == self.password {
            return
        }

        self.client?.disconnect()
        self.host = host
        self.port = port
        self.useSSL = useSSL
        self.login = login
        self.password = password

        self.client = NNTPClient(host: host, port: port, ssl: useSSL)
        self.client?.setCredentials(login, password: password)
        self.client?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.client?.connect()
    }

    func update(host: String, port: Int, useSSL : Bool, login: String?) {
        var password : String?

        if let alogin = login {
            do {
                password = try Keychain.findGenericPassowrd("NewsReader", accountName: "\(alogin)@\(host):\(port)").0
            } catch {
                return
            }
        }

        self.update(host, port: port, useSSL: useSSL, login: login, password: password)
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

        self.update(host, port: port, useSSL: useSSL, login: login)
    }
}