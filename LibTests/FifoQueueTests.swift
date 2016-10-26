//
//  FifoQueueTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import Lib

class FifoQueueTests: XCTestCase {
    fileprivate func checkPop(_ queue: FifoQueue<Int>, exp: Int?) {
        if let i = exp {
            XCTAssertFalse(queue.isEmpty)

            let val = queue.pop()
            XCTAssertNotNil(val)
            XCTAssertEqual(val!, i)
        } else {
            XCTAssertTrue(queue.isEmpty)
            XCTAssertNil(queue.pop())
        }
    }

    func testQueue() {
        let queue = FifoQueue<Int>()

        self.checkPop(queue, exp: nil)

        queue.push(1)
        self.checkPop(queue, exp: 1)
        self.checkPop(queue, exp: nil)

        queue.push(2)
        queue.push(3)
        queue.push(4)
        self.checkPop(queue, exp: 2)
        self.checkPop(queue, exp: 3)
        self.checkPop(queue, exp: 4)
        self.checkPop(queue, exp: nil)
    }
}
