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

class Article {
    let msgid : String
    let num : Int

    init(msgid: String, num: Int) {
        self.msgid = msgid
        self.num = num
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    /* Groups view */
    @IBOutlet weak var groupView: NSCollectionView!
    @IBOutlet weak var groupArrayControler: NSArrayController!
    var groups : [Group] = []
    /* Thread view */
    @IBOutlet weak var threadView: NSCollectionView!

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

        let date = NSDate(timeIntervalSinceNow: -18 * 86400)

        self.nntp?.sendCommand(.ListNewsgroups(nil)).then({
            (payload) in

            switch (payload) {
            case .GroupList(let list):
                for (group, shortDesc) in list {
                    print("got \(group)")
                    self.groupArrayControler.addObject(Group(name: group, shortDesc: shortDesc))
                }

            default:
                throw NNTPError.ServerProtocolError
            }
        })

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


        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}