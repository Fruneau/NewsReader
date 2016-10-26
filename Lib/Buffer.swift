//
//  File.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

open class Buffer {
    fileprivate let buffer : NSMutableData
    fileprivate var skipped = 0
    fileprivate var stored = 0

    public init(capacity: Int) {
        self.buffer = NSMutableData(capacity: capacity)!
    }

    open func append(maxLength: Int, writer: (UnsafeMutableRawPointer, Int) throws -> Int) rethrows {
        assert (self.buffer.length == self.skipped + self.stored)
        if self.skipped > maxLength {
            let begin = self.buffer.mutableBytes
            memmove(begin, begin + self.skipped, self.stored)
            self.skipped = 0
        }

        self.buffer.length = self.skipped + self.stored + maxLength

        let written = try writer(self.buffer.mutableBytes + self.skipped + self.stored,
                                 maxLength)

        assert (written <= maxLength)
        self.stored += written
        self.buffer.length = self.skipped + self.stored
    }

    open func appendBytes(_ bytes: UnsafeRawPointer, length: Int) {
        self.buffer.append(bytes, length: length)
        self.stored += length
    }

    open func appendData(_ data: Data) {
        self.buffer.append(data)
        self.stored += data.count
    }

    open func appendString(_ string: String) {
        if let data = (string as NSString).data(using: String.Encoding.utf8.rawValue) {
            self.appendData(data)
        }
    }

    open func read(reader: (UnsafeRawPointer, Int) throws -> Int) rethrows {
        let read = try reader(self.buffer.bytes + self.skipped, self.stored)

        assert (self.stored >= read)
        self.skipped += read
        self.stored -= read
    }

    open var length : Int {
        return self.stored
    }
}
