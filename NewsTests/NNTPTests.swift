//
//  NNTPTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import News

class NNTPTests : XCTestCase {
    let runLoop = RunLoop.current
    var nntp : NNTPClient?

    override func setUp() {
        super.setUp()

        self.nntp = nil
        if var rcContent = (try? Data(contentsOf: URL(fileURLWithPath: ("~/.newsreaderrc" as NSString).standardizingPath)))?.utf8String {
            if let idx = rcContent.characters.index(of: "\n") {
                rcContent = rcContent.substring(to: idx)
            }

            if let url = URL(string: rcContent) {
                self.nntp = NNTPClient(url: url)

                XCTAssertNotNil(self.nntp, "unsupported news server url")
                self.nntp?.scheduleInRunLoop(self.runLoop, forMode: RunLoopMode.defaultRunLoopMode.rawValue)
                _ = self.nntp?.connect()
            } else {
                XCTAssert(false, "invalid URL provided in ~/.newsreaderrc file")
            }
        } else {
            XCTAssert(false, "cannot read ~/.newsreaderrc file")
        }
    }

    override func tearDown() {
        self.nntp?.disconnect()
        self.nntp?.removeFromRunLoop(self.runLoop, forMode: RunLoopMode.defaultRunLoopMode.rawValue)
        self.nntp = nil

        super.tearDown()
    }

    func testConnect() {
        let nntp = self.nntp!
        let date = Date(timeIntervalSinceNow: -18 * 86400)

        nntp.sendCommand(.group(group: "corp.software.general")).then({
            (payload) throws in

            switch (payload) {
            case .groupContent(_, let count, let low, let high, _):
                print("group has \(count), numbers between \(low) and \(high)")

            default:
                throw NNTPError.serverProtocolError
            }
        })
        nntp.listArticles("corp.software.general", since: date).then({
            (payload) in

            switch (payload) {
            case .messageIds(let msgids):
                for msg in msgids {
                    print("got msgid \(msg)")
                }

            default:
                throw NNTPError.serverProtocolError
            }
        }).otherwise({
            (error) in

            print("got error \(error)")
        })

        _ = self.runLoop.runUntilTimeout(10, orCondition: { !nntp.hasPendingCommands })
    }
}
