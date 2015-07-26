//
//  StringTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 26/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import Lib

class StringTests : XCTestCase {
    func testStartsWith() {
        XCTAssert("abcd".startsWith(""))
        XCTAssert("abcd".startsWith("a"))
        XCTAssert("abcd".startsWith("ab"))
        XCTAssert("abcd".startsWith("abc"))
        XCTAssert("abcd".startsWith("abcd"))

        XCTAssertFalse("abcd".startsWith("b"))
        XCTAssertFalse("abcd".startsWith("ac"))
        XCTAssertFalse("abcd".startsWith("abcde"))
    }

    func testEndsWith() {
        XCTAssert("abcd".endsWith(""))
        XCTAssert("abcd".endsWith("d"))
        XCTAssert("abcd".endsWith("cd"))
        XCTAssert("abcd".endsWith("bcd"))
        XCTAssert("abcd".endsWith("abcd"))

        XCTAssertFalse("abcd".endsWith("c"))
        XCTAssertFalse("abcd".endsWith("cc"))
        XCTAssertFalse("abcd".endsWith("abcde"))
    }
}
