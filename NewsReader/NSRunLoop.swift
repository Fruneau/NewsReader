//
//  NSRunLoop.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

public extension NSRunLoop {
    public func runUntilDate(date: NSDate, orCondition condition: () -> Bool) -> Bool {
        var cond = condition()

        while !cond && date.compare(NSDate()) == .OrderedDescending {
            self.runMode(NSDefaultRunLoopMode, beforeDate: date)

            cond = condition()
        }

        return cond
    }

    public func runUntilTimeout(to: NSTimeInterval, orCondition condition: () -> Bool) -> Bool {
        return self.runUntilDate(NSDate(timeIntervalSinceNow: to), orCondition: condition)
    }
}