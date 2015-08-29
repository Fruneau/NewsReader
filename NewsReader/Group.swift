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
    private weak var loadHistoryPromise : Promise<NNTPPayload>?
    weak var delegate : GroupDelegate?

    let children : [AnyObject] = []
    let isLeaf : Bool = true

    let fullName : String
    let keyConfName : String
    var shortDesc : String?
    var subscribed : Bool = false
    var readState = GroupReadState()

    var isSilent : Bool = false {
        didSet {
            self.setConfiguration(self.isSilent, forKey: "isSilent")
        }
    }

    var name : String {
        return fullName
    }

    dynamic var unreadCount : Int {
        var count = 0

        for thread in roots {
            count += thread.threadUnreadCount
        }
        return count
    }

    dynamic var unreadCountText : String {
        return "\(self.unreadCount)"
    }

    dynamic var isRead : Bool {
        return self.unreadCount == 0
    }

    private func readConfigurationForKey(key: String) -> AnyObject? {
        let defaults = NSUserDefaults.standardUserDefaults()
        return defaults.objectAtPath("\(self.keyConfName).\(key)")
    }

    private func setConfiguration(object: AnyObject, forKey key: String) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(object, atPath: "\(self.keyConfName).\(key)")
    }

    init(account: Account?, fullName: String, shortDesc: String?) {
        self.account = account
        self.fullName = fullName

        let normalizedGroup = fullName.stringByReplacingOccurrencesOfString(".", withString: "@")
        self.keyConfName = "accounts[\(self.account.id)].groups.\(normalizedGroup)"
        self.shortDesc = shortDesc

        super.init()

        if let line = self.readConfigurationForKey("readState") as? String,
               readState = GroupReadState(line: line) {
            self.readState = readState
        } else {
            self.readState = GroupReadState()
        }

        if let group = self.readConfigurationForKey("notifiedRange") as? String {
            self.notifiedRange = NSRangeFromString(group)
        }

        if let isSilent = self.readConfigurationForKey("isSilent") as? Bool {
            self.isSilent = isSilent
        }
    }

    private var inBatchMarking = false
    private func notifyUnreadCountChange(action: (() -> ())?) {
        if self.inBatchMarking {
            action?()
            return
        }

        self.willChangeValueForKey("unreadCount")
        self.willChangeValueForKey("unreadCountText")
        self.willChangeValueForKey("isRead")

        self.inBatchMarking = true
        action?()
        self.inBatchMarking = false
        self.setConfiguration(self.readState.description, forKey: "readState")

        self.didChangeValueForKey("unreadCount")
        self.didChangeValueForKey("unreadCountText")
        self.didChangeValueForKey("isRead")
    }

    func markAsRead(num: Int) {
        if !self.readState.markAsRead(num) {
            self.notifyUnreadCountChange(nil)
        }
    }

    func unmarkAsRead(num: Int) {
        if self.readState.unmarkAsRead(num) {
            self.notifyUnreadCountChange(nil)
        }
    }

    dynamic var roots : [Article] = []

    private var fetchedCount = 0
    private var groupRange : NSRange?
    private var fetchedRange : NSRange?
    private var notifiedRange : NSRange? {
        didSet {
            self.setConfiguration(NSStringFromRange(self.notifiedRange!), forKey: "notifiedRange")
        }
    }

    private func loadHistory() throws -> Promise<NNTPPayload> {
        if self.groupRange?.location == self.fetchedRange?.location
        && self.groupRange?.length == self.fetchedRange?.length
        {
            return Promise<NNTPPayload>(success: .Overview([]))
        }

        if let promise = self.loadHistoryPromise {
            return promise
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

        print("\(self.fullName): requesting overviews \(NSStringFromRange(toFetch))")
        let promise = client.sendCommand(.Over(group: self.fullName, range: NNTPCommand.ArticleRange.InRange(toFetch)))
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

            self.notifyUnreadCountChange {
                if growUp {
                    self.roots.insertContentsOf(roots.reverse(), at: 0)
                } else {
                    self.roots.appendContentsOf(roots.reverse())
                }
            }

            self.delegate?.group(self, hasNewThreads: roots)
            if notNotified.count > 0 {
                for article in notNotified {
                    article.sendUserNotification()
                }
            }

            self.loadHistoryPromise = nil
            try self.loadHistory()
        }, otherwise: {
            (_) in

            self.loadHistoryPromise = nil
            try self.loadHistory()
        })
        self.loadHistoryPromise = promise
        return promise
    }

    func load() {
        if self.groupRange != nil {
            return
        }

        self.refresh()
    }
}

extension Group {
    @objc func refresh() {
        if self.account.client == nil {
            return
        }

        self.promise = self.account.client?.sendCommand(.Group(group: self.fullName)).thenChain({
            (payload) throws in

            switch payload {
            case .GroupContent(_, _, let lowest, let highest, _):
                self.groupRange = NSMakeRange(lowest, highest - lowest + 1)
                print("\(self.fullName): group range refreshed \(NSStringFromRange(self.groupRange!))")
                if self.fetchedRange == nil {
                    self.fetchedRange = NSMakeRange(highest + 1, 0)
                }
                if self.notifiedRange == nil {
                    self.notifiedRange = self.fetchedRange
                }

            default:
                throw NNTPError.ServerProtocolError
            }

            return try self.loadHistory()
        })
        self.promise?.otherwise({
            (error) in
            
            debugPrint("loading of group \(self.fullName) failed: \(error)")
        })
    }

    @objc func toggleNotificationState() {
        self.isSilent = !self.isSilent
    }

    @objc func markGroupAsRead() {
        if let readState = GroupReadState(line: "\(self.groupRange!.location)-\(NSMaxRange(self.fetchedRange!) - 1)") {
            self.readState = readState
        }
        self.notifyUnreadCountChange {
            for thread in self.roots {
                thread.markThreadAsRead()
            }
        }
    }
}