//
//  File.swift
//  NewsReader
//
//  Created by Florent Bruneau on 26/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

extension String {
    public func startsWith(_ other: String) -> Bool {
        return self.characters.starts(with: other.characters)
    }

    public func endsWith(_ other: String) -> Bool {
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
            myPos = myChars.index(before: myPos)
            otherPos = myChars.index(before: otherPos)

            if self[myPos] != other[otherPos] {
                return false
            }
        } while otherStart < otherPos
        return true
    }

    public static func fromBytes(_ bytes: UnsafeRawPointer, length: Int, encoding: UInt) -> String? {
        if let encString = NSString(bytes: bytes, length: length, encoding: encoding) {
            return encString as String
        }

        if encoding != String.Encoding.utf8.rawValue {
            if let utf8String = NSString(bytes: bytes, length: length, encoding: String.Encoding.utf8.rawValue) {
                return utf8String as String
            }
        }

        let charset = CFStringConvertEncodingToNSStringEncoding(CFStringBuiltInEncodings.isoLatin1.rawValue)
        if let latin1String = NSString(bytes: bytes, length: length, encoding: charset) {
            return latin1String as String
        }
        return nil
    }

    public static func fromBytes(_ bytes: UnsafeRawPointer, length: Int) -> String? {
        return String.fromBytes(bytes, length: length, encoding: String.Encoding.utf8.rawValue)
    }

    public static func fromData(_ data: Data, encoding: UInt) -> String? {
        return String.fromBytes((data as NSData).bytes, length: data.count, encoding: encoding)
    }

    public static func fromData(_ data: Data) -> String? {
        return String.fromBytes((data as NSData).bytes, length: data.count)
    }
}
