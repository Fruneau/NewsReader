//
//  NNTPTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import NewsReader

class NNTPTests : XCTestCase {
    let runLoop = NSRunLoop.currentRunLoop()
    var nntp : NNTP?

    override func setUp() {
        super.setUp()

        self.nntp = nil
        if var rcContent = NSData(contentsOfFile: "~/.newsreaderrc".stringByStandardizingPath)?.utf8String {
            if let idx = rcContent.characters.indexOf("\n") {
                rcContent = rcContent.substringToIndex(idx)
            }

            if let url = NSURL(string: rcContent) {
                self.nntp = NNTP(url: url)

                XCTAssertNotNil(self.nntp, "unsupported news server url")
                self.nntp?.scheduleInRunLoop(self.runLoop, forMode: NSDefaultRunLoopMode)
                self.nntp?.open()
            } else {
                XCTAssert(false, "invalid URL provided in ~/.newsreaderrc file")
            }
        } else {
            XCTAssert(false, "cannot read ~/.newsreaderrc file")
        }
    }

    override func tearDown() {
        self.nntp?.close()
        self.nntp?.removeFromRunLoop(self.runLoop, forMode: NSDefaultRunLoopMode)
        self.nntp = nil

        super.tearDown()
    }

    func testConnect() {
        let nntp = self.nntp!
        let date = NSDate(timeIntervalSinceNow: -18 * 86400)

        nntp.sendCommand(.Group("corp.software.general")).then({
            (payload) in

            switch (payload) {
            case .GroupContent(_, let count, let low, let high, _):
                print("group has \(count), numbers between \(low) and \(high)")

            default:
                throw NNTPError.ServerProtocolError
            }
        })
        nntp.listArticles("corp.software.general", since: date).then({
            (payload) in

            switch (payload) {
            case .MessageIds(let msgids):
                for msg in msgids {
                    print("got msgid \(msg)")
                }

            default:
                throw NNTPError.ServerProtocolError
            }
        }).otherwise({
            (error) in

            print("got error \(error)")
        })

        self.runLoop.runUntilTimeout(10, orCondition: { !nntp.hasPendingCommands })
    }
}
