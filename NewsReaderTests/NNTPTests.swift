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

        nntp.listArticles("corp.software.general", since: date).then({
            (reply) in

            print("Got reply")
            for line in reply.payload! {
                print(line)
            }
        })

        self.runLoop.runUntilTimeout(10, orCondition: { !nntp.hasPendingCommands })
    }
}
