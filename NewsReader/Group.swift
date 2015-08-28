//
//  Group.swift
//  NewsReader
//
//  Created by Florent Bruneau on 22/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Lib
import News

protocol GroupDelegate : class {
    func group(group: Group, hasNewThreads: [Article])
}

class Group : NSObject {
    private weak var account : Account!
    private weak var promise : Promise<NNTPPayload>?
    weak var delegate : GroupDelegate?

    let children : [AnyObject] = []
    let isLeaf : Bool = true

    let fullName : String
    let keyConfName : String
    var shortDesc : String?
    var subscribed : Bool = false
    var readState : GroupReadState

    var name : String {
        return fullName
    }

    dynamic var unreadCount : Int {
        var count = 0

        if let roots = self.roots {
            for thread in roots {
                count += thread.threadUnreadCount
            }
        }
        return count
    }

    dynamic var unreadCountText : String {
        return "\(self.unreadCount)"
    }

    dynamic var isRead : Bool {
        return self.unreadCount == 0
    }

    init(account: Account?, fullName: String, shortDesc: String?) {
        self.account = account
        self.fullName = fullName

        let normalizedGroup = fullName.stringByReplacingOccurrencesOfString(".", withString: "@")
        self.keyConfName = "accounts[\(self.account.id)].groups.\(normalizedGroup)"
        self.shortDesc = shortDesc

        let defaults = NSUserDefaults.standardUserDefaults()

        if let line = defaults.objectAtPath("\(self.keyConfName).readState") as? String,
               readState = GroupReadState(line: line) {
            self.readState = readState
        } else {
            self.readState = GroupReadState()
        }

        if let group = defaults.objectAtPath("\(self.keyConfName).notifiedRange") as? String {
            self.notifiedRange = NSRangeFromString(group)
        }
        super.init()
    }

    private func notifyUnreadCountChange(action: (() -> ())?) {
        self.willChangeValueForKey("unreadCount")
        self.willChangeValueForKey("unreadCountText")
        self.willChangeValueForKey("isRead")

        action?()

        self.didChangeValueForKey("unreadCount")
        self.didChangeValueForKey("unreadCountText")
        self.didChangeValueForKey("isRead")
    }

    func markAsRead(num: Int) {
        if self.readState.markAsRead(num) {
            NSUserDefaults.standardUserDefaults().setObject(self.readState.description,
                atPath: "\(self.keyConfName).readState")

            self.notifyUnreadCountChange(nil)
        }
    }

    func unmarkAsRead(num: Int) {
        if self.readState.unmarkAsRead(num) {
            NSUserDefaults.standardUserDefaults().setObject(self.readState.description,
                atPath: "\(self.keyConfName).readState")
            self.notifyUnreadCountChange(nil)
        }
    }

    dynamic var roots : [Article]?

    private var fetchedCount = 0
    private var groupRange : NSRange?
    private var fetchedRange : NSRange?
    private var notifiedRange : NSRange?

    private func loadHistory() throws -> Promise<NNTPPayload> {
        if self.groupRange?.location == self.fetchedRange?.location
        && self.groupRange?.length == self.fetchedRange?.length
        {
            return Promise<NNTPPayload>(success: .Overview([]))
        }

        if self.fetchedCount > 10000 {
            return Promise<NNTPPayload>(success: .Overview([]))
        }

        var toFetch : NSRange

        if NSMaxRange(self.groupRange!) > NSMaxRange(self.fetchedRange!) {
            let highest = NSMaxRange(self.groupRange!)
            let lowest = NSMaxRange(self.fetchedRange!)

            toFetch = NSMakeRange(lowest, min(100, highest - lowest))
        } else {
            let highest = self.fetchedRange!.location
            let lowest = self.groupRange!.location

            toFetch = NSMakeRange(max(highest - 100, lowest), min(100, highest - lowest))
        }

        guard let client = self.account?.client else {
            throw NNTPError.ServerProtocolError
        }

        let promise = client.sendCommand(.Over(group: self.fullName, range: NNTPCommand.ArticleRange.Between(toFetch.location, NSMaxRange(toFetch) - 1)))
        promise.then({
            (payload) throws in

            guard case .Overview(let messages) = payload else {
                throw NNTPError.ServerProtocolError
            }

            var roots : [Article] = []
            var notNotified : [Article] = []

            for msg in messages {
                let article = self.account.article((group: self.fullName, msg.num), headers: msg.headers)
                if article.inReplyTo == nil {
                    roots.append(article)
                }

                if !article.isRead {
                    if !NSLocationInRange(msg.num, self.notifiedRange!) {
                        notNotified.append(article)
                    }
                }
            }
            self.fetchedCount += messages.count

            let growUp = self.fetchedRange!.location < toFetch.location
            self.fetchedRange = NSUnionRange(self.fetchedRange!, toFetch)
            self.notifiedRange = NSUnionRange(toFetch, self.notifiedRange!)

            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(NSStringFromRange(self.notifiedRange!), atPath: "\(self.keyConfName).notifiedRange")

            self.notifyUnreadCountChange {
                if growUp {
                    self.roots?.insertContentsOf(roots.reverse(), at: 0)
                } else {
                    self.roots?.appendContentsOf(roots.reverse())
                }
            }

            self.delegate?.group(self, hasNewThreads: roots)
            if notNotified.count > 0 {
                for article in notNotified {
                    article.sendUserNotification()
                }
            }

            try self.loadHistory()
        })
        return promise
    }

    func load() {
        if self.groupRange != nil {
            return
        }

        self.promise = self.account.client?.sendCommand(.Group(group: self.fullName)).thenChain({
            (payload) throws -> Promise<NNTPPayload> in

            switch payload {
            case .GroupContent(_, _, let lowest, let highest, _):
                self.groupRange = NSMakeRange(lowest, highest - lowest + 1)
                self.fetchedRange = NSMakeRange(highest + 1, 0)
                if self.notifiedRange == nil {
                    self.notifiedRange = self.fetchedRange
                }

            default:
                throw NNTPError.ServerProtocolError
            }

            self.roots = []
            return try self.loadHistory()
        })
        self.promise?.otherwise({
            (error) in
            
            debugPrint("loading of group \(self.fullName) failed: \(error)")
        })
    }
}