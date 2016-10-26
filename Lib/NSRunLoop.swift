//
//  NSRunLoop.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

public extension RunLoop {
    public func runUntilDate(_ date: Date, orCondition condition: () -> Bool) -> Bool {
        var cond = condition()

        while !cond && date.compare(Date()) == .orderedDescending {
            self.run(mode: RunLoopMode.defaultRunLoopMode, before: date)

            cond = condition()
        }

        return cond
    }

    public func runUntilTimeout(_ to: TimeInterval, orCondition condition: () -> Bool) -> Bool {
        return self.runUntilDate(Date(timeIntervalSinceNow: to), orCondition: condition)
    }
}
