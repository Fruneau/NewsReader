//
//  NewsRCTests.swift
//  NewsReader
//
//  Created by Florent Bruneau on 01/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

import XCTest
@testable import News

class NewsRCTests : XCTestCase {
    func testMarkAsRead() {
        var group = GroupSubscription(name: "toto")

        for i in 0..<10 {
            XCTAssertFalse(group.isMarkedAsRead(i))
        }

        XCTAssertFalse(group.markAsRead(1))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            switch i {
            case 1:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertFalse(group.markAsRead(2))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            switch i {
            case 1, 2:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertFalse(group.markAsRead(4))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            switch i {
            case 1, 2, 4:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }
        
        XCTAssertFalse(group.markAsRead(5))
        for i in 0..<10 {
            switch i {
            case 1, 2, 4, 5:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(2, 3)), 1)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            switch i {
            case 1...5:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(6, 2)), 2)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            switch i {
            case 1...7:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertFalse(group.markAsRead(9))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            switch i {
            case 1...7, 9:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(0, 10)), 2)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<10 {
            XCTAssertTrue(group.isMarkedAsRead(i))
        }
    }

    func testMarkAsUnread() {
        var group = GroupSubscription(name: "toto")

        XCTAssertFalse(group.markAsRead(1))
        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(3, 3)), 3)
        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(7, 2)), 2)
        XCTAssertFalse(group.markAsRead(10))
        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(12, 2)), 2)
        XCTAssertEqual(group.markRangeAsRead(NSMakeRange(15, 3)), 3)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 1, 3...5, 7, 8, 10, 12, 13, 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertFalse(group.unmarkAsRead(0))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 1, 3...5, 7, 8, 10, 12, 13, 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }
        
        XCTAssertTrue(group.unmarkAsRead(1))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 3...5, 7, 8, 10, 12, 13, 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertEqual(group.unmarkRangeAsRead(NSMakeRange(1, 3)), 1)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 4, 5, 7, 8, 10, 12, 13, 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }
        
        XCTAssertEqual(group.unmarkRangeAsRead(NSMakeRange(0, 7)), 2)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 7, 8, 10, 12, 13, 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertEqual(group.unmarkRangeAsRead(NSMakeRange(8, 5)), 3)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 7, 13, 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertEqual(group.unmarkRangeAsRead(NSMakeRange(0, 15)), 2)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 15...17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }

        XCTAssertTrue(group.unmarkAsRead(16))
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            switch i {
            case 15, 17:
                XCTAssertTrue(group.isMarkedAsRead(i))

            default:
                XCTAssertFalse(group.isMarkedAsRead(i))
            }
        }
        
        XCTAssertEqual(group.unmarkRangeAsRead(NSMakeRange(0, 21)), 2)
        XCTAssertTrue(group.checkOptimized())
        for i in 0..<20 {
            XCTAssertFalse(group.isMarkedAsRead(i))
        }
    }
}