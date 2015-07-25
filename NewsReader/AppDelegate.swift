//
//  AppDelegate.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//


import Cocoa

enum Error : ErrorType {
    case NoMessage
}

class Group : NSObject {
    let name : String
    let shortDesc : String?

    init(name : String, shortDesc: String?) {
        self.name = name
        self.shortDesc = shortDesc
        super.init()
    }
}

class Article : NSObject {
    let msgid : String
    let num : Int

    init(msgid: String, num: Int) {
        self.msgid = msgid
        self.num = num
        super.init()
    }
}

class SelectableView : NSView {
    var selected = false {
        didSet {
            self.needsDisplay = true
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        if selected {
            NSColor.alternateSelectedControlColor().set()
            NSRectFill(self.bounds)
        }
    }
}

class SelectableCollectionViewItem : NSCollectionViewItem {
    override var selected : Bool {
        didSet {
            (self.view as? SelectableView)?.selected = selected
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    /* Groups view */
    @IBOutlet weak var groupView: NSCollectionView!
    @IBOutlet weak var groupArrayController: NSArrayController!
    var groups : [Group] = []
    var groupIndexes = NSIndexSet() {
        didSet {
            let date = NSDate(timeIntervalSinceNow: -365 * 86400)

            if self.groupIndexes.count == 0 {
                self.threadArrayController.removeObjects(self.threads)
                return
            }

            let group = self.groups[self.groupIndexes.firstIndex].name
            print("listing \(group)")
            self.nntp?.listArticles(group, since: date).then({
                (payload) throws in

                switch (payload) {
                case .MessageIds(let msgids):
                    self.threadArrayController.removeObjects(self.threads)

                    var articles : [Article] = []
                    for msg in msgids.reverse() {
                        articles.append(Article(msgid: msg, num: 0))

                        if articles.count == 1000 {
                            break
                        }
                    }
                    self.threadArrayController.addObjects(articles)

                default:
                    throw NNTPError.ServerProtocolError
                }
            })
        }
    }

    /* Thread view */
    @IBOutlet weak var threadView: NSCollectionView!
    @IBOutlet weak var threadArrayController: NSArrayController!
    var threads : [Article] = []
    var threadIndexes = NSIndexSet() {
        didSet {
            if self.threadIndexes.count == 0 {
                self.articleView.string = ""
                return
            }

            let msgid = self.threads[self.threadIndexes.firstIndex].msgid
            print("displaying \(msgid)")
            self.nntp?.sendCommand(.Article(ArticleId.MessageId(msgid))).then({
                (payload) in

                switch (payload) {
                case .Article(_, _, let raw):
                    self.articleView.string = raw

                default:
                    throw NNTPError.ServerProtocolError
                }
            })
        }
    }

    /* Article view */
    @IBOutlet var articleView: NSTextView!

    /* Model handling */
    var nntp : NNTP?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        self.nntp = nil
        guard var rcContent = NSData(contentsOfFile: "~/.newsreaderrc".stringByStandardizingPath)?.utf8String else {
            return
        }

        if let idx = rcContent.characters.indexOf("\n") {
            rcContent = rcContent.substringToIndex(idx)
        }

        guard let url = NSURL(string: rcContent) else {
            return
        }
        self.nntp = NNTP(url: url)

        self.nntp?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.nntp?.open()

        self.nntp?.sendCommand(.ListNewsgroups(nil)).then({
            (payload) in

            switch (payload) {
            case .GroupList(let list):
                for (group, shortDesc) in list {
                    self.groupArrayController.addObject(Group(name: group, shortDesc: shortDesc))
                }

            default:
                throw NNTPError.ServerProtocolError
            }
        })

        /*
        self.nntp?.listArticles("corp.software.general", since: date).thenChain({
            (payload) throws -> Promise<NNTPPayload> in

            switch (payload) {
            case .MessageIds(let msgids):
                for msg in msgids {
                    print("got msgid \(msg)")
                    return self.nntp!.sendCommand(.Body(.MessageId(msg)))
                }
                throw Error.NoMessage

            default:
                throw NNTPError.ServerProtocolError
            }
        }).then({
            (payload) in

            switch (payload) {
            case .Article(_, _, let raw):
                self.articleView.string = raw

            default:
                throw NNTPError.ServerProtocolError
            }
        }).otherwise({
            (error) in
            
            print("got error \(error)")
        })
        */

        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}