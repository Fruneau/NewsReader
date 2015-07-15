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
    func testConnect() {
        let nntp = NNTP(host: "news.intersec.com", port: 563, ssl: true)
        let runLoop = NSRunLoop.currentRunLoop()

        nntp!.scheduleInRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
        nntp!.open()

        runLoop.runUntilTimeout(10, orCondition: { false })
    }
}
