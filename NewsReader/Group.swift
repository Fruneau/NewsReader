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
    var shortDesc : String?
    var subscribed : Bool = false

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
        self.shortDesc = shortDesc
        super.init()
    }

    func markAsRead(num: Int) {
        self.willChangeValueForKey("unreadCount")
        self.willChangeValueForKey("unreadCountText")
        self.willChangeValueForKey("isRead")


        self.didChangeValueForKey("unreadCount")
        self.didChangeValueForKey("unreadCountText")
        self.didChangeValueForKey("isRead")
    }

    func unmarkAsRead(num: Int) {
        self.willChangeValueForKey("unreadCount")
        self.willChangeValueForKey("unreadCountText")
        self.willChangeValueForKey("isRead")

        self.didChangeValueForKey("unreadCount")
        self.didChangeValueForKey("unreadCountText")
        self.didChangeValueForKey("isRead")
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

            self.willChangeValueForKey("unreadCount")
            self.willChangeValueForKey("unreadCountText")
            self.willChangeValueForKey("isRead")

            self.articles = articles
            self.roots = roots

            self.didChangeValueForKey("unreadCount")
            self.didChangeValueForKey("unreadCountText")
            self.didChangeValueForKey("isRead")
            
            self.delegate?.groupTree(self, hasNewThreads: roots)
        }).otherwise({
            (error) in
            
            debugPrint("loading of group \(self.fullName) failed: \(error)")
        })
    }
}

