//
//  PromiseTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import XCTest
import NewsReader

private enum Error : ErrorType {
    case Fail
}

private func preparePromise(action: (String) -> Void) -> ((Void) -> Void, (ErrorType) -> Void) {
    var onSuccess : ((Void) -> Void)?
    var onError : ((ErrorType) -> Void)?
    let promise = Promise<Void>() {
        (s, e) in

        onSuccess = s
        onError = e
    }

    promise.then({
        action("1")
    }).then({
        action("1.1")
    }).otherwise({
        (_) in

        action("1.1.2")
    }).then({
        action("1.1.2.1")
    })

    promise.otherwise({
        (_) in

        action("2")
    }).then({
        action("2.1")

        throw Error.Fail
    }).otherwise({
        (_) in

        action("2.1.2")
    })

    return (onSuccess!, onError!)
}

class PromiseTests : XCTestCase {
    func testBase() {
        var out : [String] = []

        out.removeAll()
        preparePromise({ (s) in out.append(s) }).0()
        XCTAssertEqual(out, [ "1", "1.1", "1.1.2.1", "2.1", "2.1.2" ])

        out.removeAll()
        preparePromise({ (s) in out.append(s) }).1(Error.Fail)
        XCTAssertEqual(out, [ "1.1.2", "1.1.2.1", "2", "2.1", "2.1.2" ])
    }
}