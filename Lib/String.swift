//
//  File.swift
//  NewsReader
//
//  Created by Florent Bruneau on 26/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

extension String {
    public func startsWith(other: String) -> Bool {
        return self.characters.startsWith(other.characters)
    }

    public func endsWith(other: String) -> Bool {
        let myChars = self.characters
        let otherChars = other.characters

        if otherChars.count > myChars.count {
            return false
        }
        if otherChars.isEmpty {
            return true
        }

        var myPos = myChars.endIndex
        var otherPos = otherChars.endIndex
        let otherStart = otherChars.startIndex

        repeat {
            myPos = myPos.predecessor()
            otherPos = otherPos.predecessor()

            if self[myPos] != other[otherPos] {
                return false
            }
        } while otherStart < otherPos
        return true
    }
}