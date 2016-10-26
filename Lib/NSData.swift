//
//  NSData.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

private func charToHex(_ char: UInt8) -> UInt8? {
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

public extension Data {
    public var utf8String : String? {
        return NSString(bytes: (self as NSData).bytes, length: self.count, encoding: String.Encoding.utf8.rawValue) as String?
    }

    public var intValue : Int? {
        guard let str = self.utf8String else {
            return nil
        }

        return Int(str)
    }

    public func forEachChunk(separator: String, action: (Data, Int) throws -> ()) rethrows {
        try separator.withCString {
            let separatorLen = Int(strlen($0))
            let bytes = (self as NSData).bytes
            let length = self.count
            var pos = 0

            while pos < length {
                let begin = bytes + pos
                let end = UnsafeRawPointer(memmem(begin, length - pos, $0, separatorLen))

                if let end = end {
                    try action(Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: begin), count: end - begin, deallocator: .none), pos)
                } else {
                    try action(Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: begin), count: length - pos, deallocator: .none), pos)
                    break
                }
                pos += (end! - begin) + separatorLen
            }
        }
    }
}

public extension NSData {
    public convenience init?(quotedPrintableData content: Data) {
        let bytes = (content as NSData).bytes.bindMemory(to: UInt8.self, capacity: content.count)
        var pos = 0
        let end = content.count

        guard let data = NSMutableData(capacity: content.count) else {
            return nil
        }

        while pos != end {
            var code = bytes[pos]

            if code == 0x3d {
                pos += 1
                if pos == end {
                    return nil
                }

                if bytes[pos] == 0x0d {
                    pos += 1
                    if pos == end {
                        break
                    }

                    if bytes[pos] == 0x0a {
                        pos += 1
                        continue
                    }
                } else if bytes[pos] == 0x0a {
                    pos += 1
                    continue
                }

                guard let first = charToHex(bytes[pos]) else {
                    return nil
                }

                pos += 1
                if pos == end {
                    return nil
                }
                guard let second = charToHex(bytes[pos]) else {
                    return nil
                }

                code = (first << 4 + second)
            }
            data.append(&code, length: 1)
            pos += 1
        }
        self.init(data: data as Data)
    }

    public convenience init?(quotedPrintableString content: String) {
        guard let utf8Data = (content as NSString).data(using: String.Encoding.utf8.rawValue) else {
            return nil
        }

        self.init(quotedPrintableData: utf8Data)
    }
}

extension NSMutableData {
    public func appendString(_ string: String) {
        string.withCString {
            self.append($0, length: Int(strlen($0)))
        }
    }
}

public func ~=(pattern: String, value: Data) -> Bool {
    let chars = pattern.utf8
    let bytes = (value as NSData).bytes

    if chars.count != value.count {
        return false
    }

    var res = false
    pattern.withCString {
        res = memcmp(bytes, $0, value.count) == 0
    }
    return res
}
