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
}