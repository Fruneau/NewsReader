//
//  NNTPTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import NewsReader

class Delegate : NNTP.Delegate {
    override init() {
        super.init()
    }

    override func nntp(nntp: NNTP, handleEvent event: NNTPEvent) {
        switch (event) {
        case .Ready:
            let date = NSDate(timeIntervalSinceNow: -18 * 86400)

            nntp.listArticles("corp.software.general", since: date)

        default:
            break
        }
        print(event)
    }
}

class NNTPTests : XCTestCase {
    func testConnect() {
        if var rcContent = NSData(contentsOfFile: "~/.newsreaderrc".stringByStandardizingPath)?.utf8String {
            if let idx = rcContent.characters.indexOf("\n") {
                rcContent = rcContent.substringToIndex(idx)
            }

            if let url = NSURL(string: rcContent) {
                let nntp = NNTP(url: url)
                let runLoop = NSRunLoop.currentRunLoop()
                let delegate = Delegate()

                XCTAssertNotNil(nntp)
                nntp!.delegate = delegate

                nntp!.scheduleInRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
                nntp!.open()

                runLoop.runUntilTimeout(10, orCondition: { false })

                nntp!.close()
                nntp!.removeFromRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
            } else {
                XCTAssert(false, "invalid URL provided in ~/.newsreaderrc file")
            }

        } else {
            XCTAssert(false, "cannot read ~/.newsreaderrc file")
        }
    }
}
