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
    func groupTree(groupTree: Group, hasNewThreads: [Article])
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

    dynamic var articles : [Article]?
    dynamic var roots : [Article]?

    func load() {
        if self.articles != nil {
            return
        }

        self.promise = self.account.client?.sendCommand(.Group(group: self.fullName)).thenChain({
            (payload) throws in

            guard let client = self.account?.client else {
                throw NNTPError.ServerProtocolError
            }

            guard case .GroupContent(_, let count, let lowestNumber, let highestNumber, _) = payload else {
                throw NNTPError.ServerProtocolError
            }

            let from = count > 1000 ? max(lowestNumber, highestNumber - 1000) : lowestNumber

            return client.sendCommand(.Over(group: self.fullName, range: NNTPCommand.ArticleRange.From(from)))
        })
        self.promise?.then({
            (payload) throws in

            guard case .Overview(let messages) = payload else {
                throw NNTPError.ServerProtocolError
            }

            var roots : [Article] = []
            let articles = messages.reverse().map {
                (msg) -> Article in

                return self.account.article((group: self.fullName, msg.num), headers: msg.headers)
            }

            threads: for article in articles {
                if article.inReplyTo != nil {
                    continue
                }

                if let parentIds = article.parentsIds {
                    for parentId in parentIds {
                        guard let parent = self.account?.articleByMsgid[parentId] else {
                            continue
                        }

                        if parent === article {
                            continue
                        }

                        article.inReplyTo = parent
                        parent.replies.append(article)
                        continue threads
                    }
                }
                roots.append(article)
            }

            self.notifyUnreadCountChange {
                self.articles = articles
                self.roots = roots
            }
            self.delegate?.groupTree(self, hasNewThreads: roots)
        }).otherwise({
            (error) in
            
            debugPrint("loading of group \(self.fullName) failed: \(error)")
        })
    }
}

