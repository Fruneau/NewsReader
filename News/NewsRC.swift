//
//  NewsRC.swift
//  NewsReader
//
//  Created by Florent Bruneau on 01/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

/// Description of the subscription status to a group
///
/// This object contains the details of the subscription to a group, including
/// the subscription state and the list of read messages.
///
/// It maps to the content of a `.newsrc` file 
public struct GroupReadState : CustomStringConvertible {
    /// Sorted list of range of read articles.
    ///
    /// This member stores the list of article numbers that are marked as
    /// read for this group. That list is a succession of ranges of numbers
    /// that is guaranteed to be optmized.
    ///
    /// We do guarantee that `NSMaxRange(read[i]) < read[i + 1].location`
    /// which means that entries are sorted and that two successive entries
    /// are merged if they immediately follow each other.
    fileprivate var ranges : [NSRange]

    /// Build a group for testing purpose.
    ///
    /// The created group has no read articles and is not subscribed.
    public init() {
        self.ranges = []
    }

    /// Build a group status from a textual version
    ///
    /// - parameter line: the textual representation of the read state
    public init?(line: String) {
        let scanner = Scanner(string: line)
        var ranges : [NSRange] = []

        scanner.charactersToBeSkipped = nil
        while !scanner.isAtEnd {
            var start : Int = 0

            if !scanner.scanInt(&start) {
                return nil
            }

            if scanner.skipString("-") {
                var end : Int = 0

                if !scanner.scanInt(&end) {
                    return nil
                }

                if end <= start {
                    return nil
                }

                ranges.append(NSMakeRange(start, end - start + 1))
            } else {
                ranges.append(NSMakeRange(start, 1))
            }

            if !scanner.isAtEnd {
                if !scanner.skipString(",") {
                    return nil
                }
            }
        }

        self.ranges = ranges
    }

    /// Check that the read list is properly optimized.
    internal func checkOptimized() -> Bool {
        if self.ranges.count == 0 {
            return true
        }
        for i in 1..<self.ranges.count {
            if NSMaxRange(self.ranges[i - 1]) >= self.ranges[i].location {
                return false
            }
        }
        return true
    }

    /// Optimize the content of read list.
    ///
    /// This try to merge the entries at `pos` and `pos + 1` into a single
    /// range if they strictly follow each other.
    ///
    /// - parameter pos: the index to try to merge in the next one
    fileprivate mutating func optimizeAt(_ pos: Int) {
        if pos < 0 || pos >= self.ranges.count - 1 {
            return
        }

        let first = self.ranges[pos]
        let second = self.ranges[pos + 1]
        if NSMaxRange(first) == second.location {
            self.ranges[pos] = NSUnionRange(first, second)
            self.ranges.remove(at: pos + 1)
        }
    }

    /// Mark an article as read
    ///
    /// This function adds an article in the list of read articles for the
    /// group.
    ///
    /// - parameter num: The article number to mark
    /// - returns: The previous state for the article
    public mutating func markAsRead(_ num: Int) -> Bool {
        for i in 0 ..< self.ranges.count {
            let range = self.ranges[i]

            switch num {
            case _ where NSMaxRange(range) < num:
                continue

            case NSMaxRange(range):
                self.ranges[i] = NSMakeRange(range.location, range.length + 1)
                self.optimizeAt(i)
                return false

            case _ where NSLocationInRange(num, range):
                return true

            case range.location - 1:
                self.ranges[i] = NSMakeRange(range.location - 1, range.length + 1)
                self.optimizeAt(i - 1)
                return false

            default:
                self.ranges.insert(NSMakeRange(num, 1), at: i)
                self.optimizeAt(i)
                return false
            }
        }

        self.ranges.append(NSMakeRange(num, 1))
        return false
    }

    /// Mark a range of articles as read
    ///
    /// Mark all the elements of the provided range as read. This helper is not
    /// currently implemented efficiently.
    ///
    /// - parameter range: The range of article number to mark as read
    /// - returns: the number of article marked as read
    public mutating func markRangeAsRead(_ range: NSRange) -> Int {
        var count = 0

        for i in range.location..<NSMaxRange(range) {
            if !self.markAsRead(i) {
                count += 1
            }
        }
        return count
    }

    /// Mark an article as unread.
    ///
    /// This function removes an article from the list of read articles in
    /// group.
    ///
    /// - parameter num: The article number to unmark
    /// - returns: The previous state of the article
    public mutating func unmarkAsRead(_ num: Int) -> Bool {
        for i in 0 ..< self.ranges.count {
            let range = self.ranges[i]

            switch (num) {
            case _ where NSMaxRange(range) <= num:
                continue

            case NSMaxRange(range) - 1:
                if range.length == 1 {
                    self.ranges.remove(at: i)
                    return true
                }
                self.ranges[i] = NSMakeRange(range.location, range.length - 1)
                return true

            case range.location:
                self.ranges[i] = NSMakeRange(range.location + 1, range.length - 1)
                return true

            case _ where NSLocationInRange(num, range):
                self.ranges[i] = NSMakeRange(range.location, num - range.location)
                self.ranges.insert(NSMakeRange(num + 1, NSMaxRange(range) - (num + 1)), at: i + 1)
                return true

            default:
                return false
            }
        }
        return false
    }

    /// Mark a range of articles as unread
    ///
    /// Mark all the elements of the provided range as unread. This helper is
    /// not currently implemented efficiently.
    ///
    /// - parameter range: The range of article number to mark as unread
    /// - returns: the number of unmarked items
    public mutating func unmarkRangeAsRead(_ range: NSRange) -> Int {
        var count = 0

        for i in range.location..<NSMaxRange(range) {
            if self.unmarkAsRead(i) {
                count += 1
            }
        }
        return count
    }

    /// Check if an article is marked as read.
    ///
    /// - parameter num: The article number to check
    /// - returns: A flag indicating if the article is marked as read.
    public func isMarkedAsRead(_ num: Int) -> Bool {
        for range in self.ranges {
            if NSLocationInRange(num, range) {
                return true
            }
        }
        return false
    }

    /// Representation of the subscription in .newsrc format
    public var description : String {
        var buffer = ""

        for i in 0..<self.ranges.count {
            let range = self.ranges[i]

            if i != 0 {
                buffer += ","
            }

            if range.length == 1 {
                buffer += "\(range.location)"
            } else {
                buffer += "\(range.location)-\(NSMaxRange(range) - 1)"
            }
        }
        return buffer
    }
}
