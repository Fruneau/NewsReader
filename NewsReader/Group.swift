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
    @objc optional func group(_ group: Group, willHaveNewThreads: [Article])
    @objc optional func group(_ group: Group, hasNewThreads: [Article], atBottom: Bool)

    @objc optional func group(_ group: Group, willLoseThreads: [Article])
    @objc optional func group(_ group: Group, hasLostThreads: [Article])
}

class Group : NSObject {
    weak var account : Account!
    fileprivate weak var promise : Promise<NNTPPayload>?
    fileprivate weak var loadHistoryPromise : Promise<NNTPPayload>?
    weak var delegate : GroupDelegate?

    let children : [Any] = []
    let isLeaf : Bool = true

    let fullName : String
    let keyConfName : String
    var shortDesc : String?
    var subscribed : Bool = false
    var readState = GroupReadState()

    fileprivate var initDone = false
    fileprivate let rootDataCacheURL : URL?
    fileprivate var rootDataCache : NSMutableDictionary?
    fileprivate var rootDataCacheDirty = false

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

    fileprivate func readConfigurationForKey(_ key: String) -> Any? {
        let defaults = UserDefaults.standard
        return defaults.objectAtPath("\(self.keyConfName).\(key)")
    }

    fileprivate func setConfiguration(_ object: Any, forKey key: String) {
        let defaults = UserDefaults.standard
        defaults.set(object, forKey: "\(self.keyConfName).\(key)")
    }

    fileprivate func loadConfigurationParameters() {
        if let line = self.readConfigurationForKey("readState") as? String,
               let readState = GroupReadState(line: line) {
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

    fileprivate func loadCachedParameters() {
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

        let normalizedGroup = fullName.replacingOccurrences(of: ".", with: "@")
        self.keyConfName = "accounts[\(self.account.id)].groups.\(normalizedGroup)"
        self.shortDesc = shortDesc

        self.rootDataCacheURL = account.cacheGroups?.appendingPathComponent("\(self.fullName).plist", isDirectory: false)
        if let url = self.rootDataCacheURL {
            self.rootDataCache = NSMutableDictionary(contentsOf: url)

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

    fileprivate var inBatchMarking = false
    fileprivate func notifyUnreadCountChange(_ action: (() -> ())?) {
        if self.inBatchMarking {
            action?()
            return
        }

        self.willChangeValue(forKey: "unreadCount")
        self.willChangeValue(forKey: "unreadCountText")
        self.willChangeValue(forKey: "isRead")

        self.inBatchMarking = true
        action?()
        self.inBatchMarking = false
        self.setConfiguration(self.readState.description, forKey: "readState")

        self.didChangeValue(forKey: "unreadCount")
        self.didChangeValue(forKey: "unreadCountText")
        self.didChangeValue(forKey: "isRead")
    }

    func markAsRead(_ num: Int) {
        if !self.readState.markAsRead(num) {
            self.notifyUnreadCountChange(nil)
        }
    }

    func unmarkAsRead(_ num: Int) {
        if self.readState.unmarkAsRead(num) {
            self.notifyUnreadCountChange(nil)
        }
    }

    dynamic var roots : [Article] = []

    fileprivate var fetchedCount = 0
    fileprivate var groupRange : NSRange? {
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
    fileprivate var fetchedRange : NSRange? {
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
    fileprivate var notifiedRange : NSRange? {
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

    func getIndexOfThread(_ thread: Article) -> Int? {
        return self.roots.index(of: thread)
    }

    func addThreads(_ threads: [Article], atBottom: Bool) {
        self.delegate?.group?(self, willHaveNewThreads: threads)

        self.notifyUnreadCountChange {
            if !atBottom {
                self.roots.insert(contentsOf: threads, at: 0)
            } else {
                self.roots.append(contentsOf: threads)
            }
        }

        self.delegate?.group?(self, hasNewThreads: roots, atBottom: atBottom)
    }

    func removeThreads(_ threads: [Article]) {
        self.delegate?.group?(self, willLoseThreads: threads)

        self.notifyUnreadCountChange {
            for thread in threads {
                if let pos = self.roots.index(of: thread) {
                    self.roots.remove(at: pos)
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
        self.rootDataCache?.write(to: self.rootDataCacheURL!, atomically: true)
    }

    fileprivate enum Error : Swift.Error {
        case invalidCache
    }

    fileprivate func loadOverview(_ payload: NNTPPayload, atBottom: Bool) throws {
        guard case .overview(let messages) = payload else {
            throw NNTPError.serverProtocolError
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
                    if let range = self.notifiedRange {
                        if !NSLocationInRange(msg.num, range) {
                            notNotified.append(article)
                        }
                    }
                }

                overviews?[String(msg.num)] = msg.headers.dictionary
            }
            self.rootDataCacheDirty = true

            self.fetchedCount += messages.count

            self.addThreads(roots.reversed(), atBottom: atBottom)
        }
        if notNotified.count > 0 {
            for article in notNotified {
                article.sendUserNotification()
            }
        }
    }

    fileprivate func loadFromCache() -> Promise<NNTPPayload>? {
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
                    throw Error.invalidCache;
                }

                guard NSLocationInRange(num, self.groupRange!) else {
                    continue
                }

                guard let dict = val as? NSDictionary,
                    let headers = MIMEHeaders(fromDictionary: dict) else
                {
                    throw Error.invalidCache
                }

                res.append(NNTPOverview(num: num, headers: headers, bytes: nil, lines: nil))
            }

            res.sort { $0.num < $1.num }
            return .overview(res)
        }
    }

    @discardableResult fileprivate func loadHistory() throws -> Promise<NNTPPayload> {
        if NSEqualRanges(self.groupRange!, self.fetchedRange!) {
            self.synchronizeCache()
            return Promise<NNTPPayload>(success: .overview([]))
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
            return Promise<NNTPPayload>(success: .overview([]))
        } else {
            let highest = self.fetchedRange!.location
            let lowest = self.groupRange!.location

            toFetch = NSMakeRange(max(highest - 100, lowest), min(100, highest - lowest))
        }

        guard let client = self.account?.client else {
            throw NNTPError.serverProtocolError
        }

        let promise = client.sendCommand(.over(group: self.fullName, range: NNTPCommand.ArticleRange.inRange(toFetch)))
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
            case NNTPError.noArticleWithThatNumber:
                self.fetchedRange = NSUnionRange(self.fetchedRange!, toFetch)
                try self.loadHistory()

            default:
                break
            }
        })
        self.loadHistoryPromise = promise
        return promise
    }

    fileprivate var loaded = false
    func load() {
        if self.loaded || self.promise != nil {
            return
        }

        if let promise = self.loadFromCache() {
            self.promise = promise
            _ = self.promise?.otherwise({
                (_) in

                self.rootDataCache = NSMutableDictionary()
                self.rootDataCache?["overviews"] = NSMutableDictionary()
                self.rootDataCacheDirty = true

                self.fetchedRange = nil
                self.groupRange = nil
                self.loaded = true
                self.refresh()
            })
            _ = self.promise?.then({
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

        self.promise = self.account.client?.sendCommand(.group(group: self.fullName)).thenChain({
            (payload) throws in

            switch payload {
            case .groupContent(_, _, let lowest, let highest, _):
                self.groupRange = NSMakeRange(lowest, highest - lowest + 1)
                if self.fetchedRange == nil {
                    self.fetchedRange = NSMakeRange(highest + 1, 0)
                } else if self.fetchedRange!.location < lowest {
                    let overviews = self.rootDataCache?["overviews"] as? NSMutableDictionary

                    for num in self.fetchedRange!.location..<lowest {
                        print("forgetting article \(num)")
                        overviews?.removeObject(forKey: String(num))
                    }

                    self.fetchedRange = NSIntersectionRange(self.fetchedRange!, self.groupRange!)
                }
                if self.notifiedRange == nil {
                    self.notifiedRange = self.groupRange
                }

            default:
                throw NNTPError.serverProtocolError
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
