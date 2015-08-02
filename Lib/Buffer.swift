//
//  File.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

public class Buffer {
    private let buffer : NSMutableData
    private var skipped = 0
    private var stored = 0

    public init(capacity: Int) {
        self.buffer = NSMutableData(capacity: capacity)!
    }

    public func append(maxLength: Int, writer: (UnsafeMutablePointer<Void>, Int) throws -> Int) rethrows {
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

    public func appendBytes(bytes: UnsafePointer<Void>, length: Int) {
        self.buffer.appendBytes(bytes, length: length)
        self.stored += length
    }

    public func appendData(data: NSData) {
        self.buffer.appendData(data)
        self.stored += data.length
    }

    public func appendString(string: String) {
        if let data = (string as NSString).dataUsingEncoding(NSUTF8StringEncoding) {
            self.appendData(data)
        }
    }

    public func read(reader: (UnsafePointer<Void>, Int) throws -> Int) rethrows {
        let read = try reader(self.buffer.bytes + self.skipped, self.stored)

        assert (self.stored >= read)
        self.skipped += read
        self.stored -= read
    }

    public var length : Int {
        return self.stored
    }
}