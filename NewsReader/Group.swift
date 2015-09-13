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

@objc protocol GroupDelegate : class {
    optional func group(group: Group, willHaveNewThreads: [Article])
    optional func group(group: Group, hasNewThreads: [Article], atBottom: Bool)

    optional func group(group: Group, willLoseThreads: [Article])
    optional func group(group: Group, hasLostThreads: [Article])
}

class Group : NSObject {
    weak var account : Account!
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

    private var initDone = false
    private let rootDataCacheURL : NSURL?
    private var rootDataCache : NSMutableDictionary?
    private var rootDataCacheDirty = false

    var isSilent : Bool = false {
        didSet {
            if !self.initDone {
                return
            }

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

    private func loadConfigurationParameters() {
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

    private func loadCachedParameters() {
        if let groupRange = self.rootDataCache?["groupRange"] as? String {
            self.groupRange = NSRangeFromString(groupRange)
        }

        if let fetchedRange = self.rootDataCache?["fetchedRange"] as? String {
            self.fetchedRange = NSRangeFromString(fetchedRange)
        }

        if self.shortDesc == nil {
            if let shortDesc = self.rootDataCache?["shortDesc"] as? String {
                self.shortDesc = shortDesc
            }
        }
    }

    init(account: Account!, fullName: String, shortDesc: String?) {
        self.account = account
        self.fullName = fullName

        let normalizedGroup = fullName.stringByReplacingOccurrencesOfString(".", withString: "@")
        self.keyConfName = "accounts[\(self.account.id)].groups.\(normalizedGroup)"
        self.shortDesc = shortDesc

        self.rootDataCacheURL = account.cacheGroups?.URLByAppendingPathComponent("\(self.fullName).plist", isDirectory: false)
        if let url = self.rootDataCacheURL {
            self.rootDataCache = NSMutableDictionary(contentsOfURL: url)

            if self.rootDataCache == nil {
                self.rootDataCache = NSMutableDictionary()

                self.rootDataCache?["overviews"] = NSMutableDictionary()
                if shortDesc != nil {
                    self.rootDataCache?["shortDesc"] = shortDesc!
                }
                self.rootDataCacheDirty = true
            }
        }

        super.init()
        self.loadConfigurationParameters()
        self.loadCachedParameters()
        self.initDone = true
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
    private var groupRange : NSRange? {
        didSet {
            if !self.initDone {
                return
            }
            if let previous = oldValue {
                if NSEqualRanges(previous, self.groupRange!) {
                    return
                }
            }

            self.rootDataCacheDirty = true
            self.rootDataCache?["groupRange"] = NSStringFromRange(self.groupRange!)
        }
    }
    private var fetchedRange : NSRange? {
        didSet {
            if !self.initDone {
                return
            }
            if let previous = oldValue {
                if NSEqualRanges(previous, self.fetchedRange!) {
                    return
                }
            }

            self.rootDataCacheDirty = true
            self.rootDataCache?["fetchedRange"] = NSStringFromRange(self.fetchedRange!)
        }
    }
    private var notifiedRange : NSRange? {
        didSet {
            if !self.initDone {
                return
            }
            if let previous = oldValue {
                if NSEqualRanges(previous, self.notifiedRange!) {
                    return
                }
            }

            self.setConfiguration(NSStringFromRange(self.notifiedRange!), forKey: "notifiedRange")
        }
    }

    func getIndexOfThread(thread: Article) -> Int? {
        return self.roots.indexOf(thread)
    }

    func addThreads(threads: [Article], atBottom: Bool) {
        self.delegate?.group?(self, willHaveNewThreads: threads)

        self.notifyUnreadCountChange {
            if !atBottom {
                self.roots.insertContentsOf(threads, at: 0)
            } else {
                self.roots.appendContentsOf(threads)
            }
        }

        self.delegate?.group?(self, hasNewThreads: roots, atBottom: atBottom)
    }

    func removeThreads(threads: [Article]) {
        self.delegate?.group?(self, willLoseThreads: threads)

        self.notifyUnreadCountChange {
            for thread in threads {
                if let pos = self.roots.indexOf(thread) {
                    self.roots.removeAtIndex(pos)
                }
            }
        }

        self.delegate?.group?(self, hasLostThreads: threads)
    }

    func synchronizeCache() {
        if !self.rootDataCacheDirty {
            return
        }
        self.rootDataCacheDirty = false
        self.rootDataCache?.writeToURL(self.rootDataCacheURL!, atomically: true)
    }

    private enum Error : ErrorType {
        case InvalidCache
    }

    private func loadOverview(payload: NNTPPayload, atBottom: Bool) throws {
        guard case .Overview(let messages) = payload else {
            throw NNTPError.ServerProtocolError
        }

        var notNotified : [Article] = []
        self.notifyUnreadCountChange {
            var roots : [Article] = []
            let overviews = self.rootDataCache?["overviews"] as? NSMutableDictionary

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

                overviews?[String(msg.num)] = msg.headers.dictionary
            }
            self.rootDataCacheDirty = true

            self.fetchedCount += messages.count

            self.addThreads(roots.reverse(), atBottom: atBottom)
        }
        if notNotified.count > 0 {
            for article in notNotified {
                article.sendUserNotification()
            }
        }
    }

    private func loadFromCache() -> Promise<NNTPPayload>? {
        guard let overviews = self.rootDataCache?["overviews"] as? NSDictionary else {
            return nil
        }

        return Promise<NNTPPayload>(queue: self.account.processingQueue) {
            () throws -> NNTPPayload in

            var res : [NNTPOverview] = []

            for (key, val) in overviews {
                guard let key = key as? String,
                    let num = Int(key) else
                {
                    throw Error.InvalidCache;
                }

                guard NSLocationInRange(num, self.groupRange!) else {
                    continue
                }

                guard let dict = val as? NSDictionary,
                    let headers = MIMEHeaders(fromDictionary: dict) else
                {
                    throw Error.InvalidCache
                }

                res.append(NNTPOverview(num: num, headers: headers, bytes: nil, lines: nil))
            }

            res.sortInPlace { $0.num < $1.num }
            return .Overview(res)
        }
    }

    private func loadHistory() throws -> Promise<NNTPPayload> {
        if NSEqualRanges(self.groupRange!, self.fetchedRange!) {
            self.synchronizeCache()
            return Promise<NNTPPayload>(success: .Overview([]))
        }

        if let promise = self.loadHistoryPromise {
            return promise
        }

        if let error = self.account.connectionError {
            return Promise<NNTPPayload>(failure: error)
        }

        var toFetch : NSRange

        if NSMaxRange(self.groupRange!) > NSMaxRange(self.fetchedRange!) {
            let highest = NSMaxRange(self.groupRange!)
            let lowest = NSMaxRange(self.fetchedRange!)

            toFetch = NSMakeRange(lowest, min(100, highest - lowest))
        } else if self.fetchedCount > 10000 {
            self.synchronizeCache()
            return Promise<NNTPPayload>(success: .Overview([]))
        } else {
            let highest = self.fetchedRange!.location
            let lowest = self.groupRange!.location

            toFetch = NSMakeRange(max(highest - 100, lowest), min(100, highest - lowest))
        }

        guard let client = self.account?.client else {
            throw NNTPError.ServerProtocolError
        }

        let promise = client.sendCommand(.Over(group: self.fullName, range: NNTPCommand.ArticleRange.InRange(toFetch)))
        promise.then({
            (payload) throws in

            try self.loadOverview(payload, atBottom: self.fetchedRange!.location >= toFetch.location)
            self.fetchedRange = NSUnionRange(self.fetchedRange!, toFetch)
            self.notifiedRange = NSUnionRange(toFetch, self.notifiedRange!)


            self.loadHistoryPromise = nil
            try self.loadHistory()
        }, otherwise: {
            (error) in

            self.loadHistoryPromise = nil
            print("error while fetching overviews for group \(self.fullName) for range \(NSStringFromRange(toFetch)) with group range \(NSStringFromRange(self.groupRange!)): \(error)")
            switch error {
            case NNTPError.NoArticleWithThatNumber:
                self.fetchedRange = NSUnionRange(self.fetchedRange!, toFetch)
                try self.loadHistory()

            default:
                break
            }
        })
        self.loadHistoryPromise = promise
        return promise
    }

    private var loaded = false
    func load() {
        if self.loaded || self.promise != nil {
            return
        }

        if let promise = self.loadFromCache() {
            self.promise = promise
            self.promise?.otherwise({
                (_) in

                self.rootDataCache = NSMutableDictionary()
                self.rootDataCache?["overviews"] = NSMutableDictionary()
                self.rootDataCacheDirty = true

                self.fetchedRange = nil
                self.groupRange = nil
                self.loaded = true
                self.refresh()
            })
            self.promise?.then({
                (payload) throws in

                try self.loadOverview(payload, atBottom: true)
                print("loaded from cache")
                self.loaded = true
                self.refresh()
            })
        } else {
            self.loaded = true
            self.refresh()
        }
    }
}

extension Group {
    @objc func refresh() {
        if self.account.client == nil || !self.loaded {
            return
        }

        self.promise = self.account.client?.sendCommand(.Group(group: self.fullName)).thenChain({
            (payload) throws in

            switch payload {
            case .GroupContent(_, _, let lowest, let highest, _):
                self.groupRange = NSMakeRange(lowest, highest - lowest + 1)
                if self.fetchedRange == nil {
                    self.fetchedRange = NSMakeRange(highest + 1, 0)
                } else if self.fetchedRange!.location < lowest {
                    let overviews = self.rootDataCache?["overviews"] as? NSMutableDictionary

                    for num in self.fetchedRange!.location..<lowest {
                        print("forgetting article \(num)")
                        overviews?.removeObjectForKey(String(num))
                    }

                    self.fetchedRange = NSIntersectionRange(self.fetchedRange!, self.groupRange!)
                }
                if self.notifiedRange == nil {
                    self.notifiedRange = self.groupRange
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