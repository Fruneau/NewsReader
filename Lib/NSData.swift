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

public func memfind(ptr: UnsafePointer<Void>, length: Int, str: String.UTF8View) -> UnsafePointer<Void> {
    let first = Int32(str.first!)
    var pos = ptr
    let end = ptr + length - (str.count - 1)

    func matchAt(sub : UnsafePointer<Void>) -> Bool {
        var bytes = UnsafePointer<UInt8>(sub)

        for byte in str {
            if byte != bytes[0] {
                return false
            }
            bytes = bytes + 1
        }
        return true
    }

    while pos < end {
        let match = memchr(pos, first, end - pos)

        if match == nil || matchAt(match) {
            return UnsafePointer<Void>(match)
        }

        pos = UnsafePointer<Void>(match) + 1
    }
    return nil
}

public extension NSData {
    public var utf8String : String? {
        return NSString(bytes: self.bytes, length: self.length, encoding: NSUTF8StringEncoding) as String?
    }

    public convenience init?(quotedPrintableString content: String) {
        let utf8Data = content.utf8
        guard let data = NSMutableData(capacity: utf8Data.count) else {
            return nil
        }

        var pos = utf8Data.startIndex
        let end = utf8Data.endIndex

        while pos != end {
            var code = utf8Data[pos]

            if code == 0x3d {
                pos = pos.successor()
                if pos == end {
                    return nil
                }
                guard let first = charToHex(utf8Data[pos]) else {
                    return nil
                }

                pos = pos.successor()
                if pos == end {
                    return nil
                }
                guard let second = charToHex(utf8Data[pos]) else {
                    return nil
                }

                code = (first << 4 + second)
            }
            data.appendBytes(&code, length: 1)
            pos = pos.successor()
        }
        self.init(data: data)
    }

    public func split(separator: String) -> [NSData] {
        var chunks : [NSData] = []
        let separatorChars = separator.utf8
        let bytes = self.bytes
        let length = self.length
        var pos = 0

        while pos < length {
            let begin = bytes + pos
            let end = memfind(begin, length: length - pos, str: separatorChars)

            if end == nil {
                chunks.append(NSData(bytesNoCopy: UnsafeMutablePointer<Void>(begin), length: length - pos, freeWhenDone: false))
                break
            } else {
                chunks.append(NSData(bytesNoCopy: UnsafeMutablePointer<Void>(begin), length: end - begin, freeWhenDone: false))
            }
            pos += (end - begin) + separatorChars.count
        }
        return chunks
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