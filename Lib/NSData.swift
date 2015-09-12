//
//  NSData.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

private func charToHex(char: UInt8) -> UInt8? {
    switch (char) {
    case 0x30...0x39:
        return char - 0x30

    case 0x41, 0x61:
        return 10

    case 0x42, 0x62:
        return 11

    case 0x43, 0x63:
        return 12

    case 0x44, 0x64:
        return 13

    case 0x45, 0x65:
        return 14

    case 0x46, 0x66:
        return 15

    default:
        return nil
    }
}

public extension NSData {
    public var utf8String : String? {
        return NSString(bytes: self.bytes, length: self.length, encoding: NSUTF8StringEncoding) as String?
    }

    public var intValue : Int? {
        guard let str = self.utf8String else {
            return nil
        }

        return Int(str)
    }

    public convenience init?(quotedPrintableData content: NSData) {
        let bytes = UnsafePointer<UInt8>(content.bytes)
        var pos = 0
        let end = content.length

        guard let data = NSMutableData(capacity: content.length) else {
            return nil
        }

        while pos != end {
            var code = bytes[pos]

            if code == 0x3d {
                pos++
                if pos == end {
                    return nil
                }

                if bytes[pos] == 0x0d {
                    pos++
                    if pos == end {
                        break
                    }

                    if bytes[pos] == 0x0a {
                        pos++
                        continue
                    }
                } else if bytes[pos] == 0x0a {
                    pos++
                    continue
                }

                guard let first = charToHex(bytes[pos]) else {
                    return nil
                }

                pos++
                if pos == end {
                    return nil
                }
                guard let second = charToHex(bytes[pos]) else {
                    return nil
                }

                code = (first << 4 + second)
            }
            data.appendBytes(&code, length: 1)
            pos++
        }
        self.init(data: data)
    }

    public convenience init?(quotedPrintableString content: String) {
        guard let utf8Data = (content as NSString).dataUsingEncoding(NSUTF8StringEncoding) else {
            return nil
        }

        self.init(quotedPrintableData: utf8Data)
    }

    public func forEachChunk(separator: String, action: (NSData, Int) throws -> ()) rethrows {
        try separator.withCString {
            let separatorLen = Int(strlen($0))
            let bytes = self.bytes
            let length = self.length
            var pos = 0

            while pos < length {
                let begin = bytes + pos
                let end = UnsafePointer<Void>(memmem(begin, length - pos, $0, separatorLen))

                if end == nil {
                    try action(NSData(bytesNoCopy: UnsafeMutablePointer<Void>(begin), length: length - pos, freeWhenDone: false), pos)
                    break
                } else {
                    try action(NSData(bytesNoCopy: UnsafeMutablePointer<Void>(begin), length: end - begin, freeWhenDone: false), pos)
                }
                pos += (end - begin) + separatorLen
            }
        }
    }
}

extension NSMutableData {
    public func appendString(string: String) {
        string.withCString {
            self.appendBytes($0, length: Int(strlen($0)))
        }
    }
}

public func ~=(pattern: String, value: NSData) -> Bool {
    let chars = pattern.utf8
    let bytes = value.bytes

    if chars.count != value.length {
        return false
    }

    var res = false
    pattern.withCString {
        res = memcmp(bytes, $0, value.length) == 0
    }
    return res
}