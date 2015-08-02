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
public struct GroupSubscription : CustomStringConvertible {
    /// Full name of the group.
    public let name : String

    /// Subscription state for the group.
    public var subscribed : Bool

    /// Sorted list of range of read articles.
    ///
    /// This member stores the list of article numbers that are marked as
    /// read for this group. That list is a succession of ranges of numbers
    /// that is guaranteed to be optmized.
    ///
    /// We do guarantee that `NSMaxRange(read[i]) < read[i + 1].location`
    /// which means that entries are sorted and that two successive entries
    /// are merged if they immediately follow each other.
    private var read : [NSRange]

    /// Build a group for testing purpose.
    ///
    /// The created group has no read articles and is not subscribed.
    ///
    /// - parameter name: the name of the group
    internal init(name: String) {
        self.name = name
        self.subscribed = false
        self.read = []
    }

    /// Check that the read list is properly optimized.
    internal func checkOptimized() -> Bool {
        if self.read.count == 0 {
            return true
        }
        for i in 1..<self.read.count {
            if NSMaxRange(self.read[i - 1]) >= self.read[i].location {
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
    private mutating func optimizeAt(pos: Int) {
        if pos < 0 || pos >= self.read.count - 1 {
            return
        }

        let first = self.read[pos]
        let second = self.read[pos + 1]
        if NSMaxRange(first) == second.location {
            self.read[pos] = NSUnionRange(first, second)
            self.read.removeAtIndex(pos + 1)
        }
    }

    /// Mark an article as read
    ///
    /// This function adds an article in the list of read articles for the
    /// group.
    ///
    /// - parameter num: The article number to mark
    /// - returns: The previous state for the article
    public mutating func markAsRead(num: Int) -> Bool {
        for var i = 0; i < self.read.count; i++ {
            let range = self.read[i]

            switch num {
            case _ where NSMaxRange(range) < num:
                continue

            case NSMaxRange(range):
                self.read[i] = NSMakeRange(range.location, range.length + 1)
                self.optimizeAt(i)
                return false

            case _ where NSLocationInRange(num, range):
                return true

            case range.location - 1:
                self.read[i] = NSMakeRange(range.location - 1, range.length + 1)
                self.optimizeAt(i - 1)
                return false

            default:
                self.read.insert(NSMakeRange(num, 1), atIndex: i)
                self.optimizeAt(i)
                return false
            }
        }

        self.read.append(NSMakeRange(num, 1))
        return false
    }

    /// Mark a range of articles as read
    ///
    /// Mark all the elements of the provided range as read. This helper is not
    /// currently implemented efficiently.
    ///
    /// - parameter range: The range of article number to mark as read
    public mutating func markRangeAsRead(range: NSRange) {
        for i in range.location..<NSMaxRange(range) {
            self.markAsRead(i)
        }
    }

    /// Mark an article as unread.
    ///
    /// This function removes an article from the list of read articles in
    /// group.
    ///
    /// - parameter num: The article number to unmark
    /// - returns: The previous state of the article
    public mutating func unmarkAsRead(num: Int) -> Bool {
        for var i = 0; i < self.read.count; i++ {
            let range = self.read[i]

            switch (num) {
            case _ where NSMaxRange(range) <= num:
                continue

            case NSMaxRange(range) - 1:
                if range.length == 1 {
                    self.read.removeAtIndex(i)
                    return true
                }
                self.read[i] = NSMakeRange(range.location, range.length - 1)
                return true

            case range.location:
                self.read[i] = NSMakeRange(range.location + 1, range.length - 1)
                return true

            case _ where NSLocationInRange(num, range):
                self.read[i] = NSMakeRange(range.location, num - range.location)
                self.read.insert(NSMakeRange(num + 1, NSMaxRange(range) - (num + 1)), atIndex: i + 1)
                return true

            default:
                return false
            }
        }
        return false
    }

    /// Mark a range of articles as read
    ///
    /// Mark all the elements of the provided range as unread. This helper is
    /// not currently implemented efficiently.
    ///
    /// - parameter range: The range of article number to mark as unread
    public mutating func unmarkRangeAsRead(range: NSRange) {
        for i in range.location..<NSMaxRange(range) {
            self.unmarkAsRead(i)
        }
    }

    /// Check if an article is marked as read.
    ///
    /// - parameter num: The article number to check
    /// - returns: A flag indicating if the article is marked as read.
    public func isMarkedAsRead(num: Int) -> Bool {
        for range in self.read {
            if NSLocationInRange(num, range) {
                return true
            }
        }
        return false
    }

    /// Representation of the subscription in .newsrc format
    public var description : String {
        var buffer = self.name

        buffer += self.subscribed ? ": " : "! "

        for i in 0..<self.read.count {
            let range = self.read[i]

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