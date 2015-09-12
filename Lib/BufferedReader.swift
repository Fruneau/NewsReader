//
//  BufferedReader.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

public class BufferedReader {
    private let stream : NSInputStream
    private let buffer: Buffer
    private var ended = false
    private var lastReadTo = 0
    private var lastBound = ""

    public enum Error : ErrorType {
        case ReadError
    }

    public init(fromStream stream: NSInputStream) {
        self.stream = stream
        self.buffer = Buffer(capacity: 2 << 20)
    }

    public convenience init(fromData data: NSData) {
        let stream = NSInputStream(data: data)

        stream.open()
        self.init(fromStream: stream)
    }

    public convenience init?(fromString string: String) {
        if let data = (string as NSString).dataUsingEncoding(NSUTF8StringEncoding) {
            self.init(fromData: data)
        } else {
            return nil
        }
    }

    private func fillBuffer(minSize: Int) throws -> Bool {
        var filledAll = false

        try self.buffer.append(minSize) {
            (buffer, length) throws in

            switch (self.stream.read(UnsafeMutablePointer<UInt8>(buffer), maxLength: length)) {
            case 0:
                return 0

            case length:
                filledAll = true
                return length

            case let e where e > 0:
                return e

            default:
                throw Error.ReadError
            }
        }

        return filledAll
    }

    public func fillBuffer() throws {
        while try self.fillBuffer(64 << 10) {
        }
    }

    public func readDataUpTo(bound: String, keepBound: Bool, endOfStreamIsBound: Bool) throws -> NSData? {
        assert (!bound.isEmpty)
        if self.ended {
            return nil
        }

        if bound != self.lastBound {
            self.lastReadTo = 0
            self.lastBound = bound
        }

        var res : NSData?
        bound.withCString {
            (boundChars) in

            let boundLen = Int(strlen(boundChars))

            self.buffer.read() {
                (buffer, maxLength) in
                
                assert (maxLength >= self.lastReadTo)
                
                let end = UnsafePointer<Void>(memmem(buffer + self.lastReadTo, maxLength - self.lastReadTo, boundChars, boundLen))
                self.lastReadTo = max(maxLength - boundLen, 0)
                
                if end != nil {
                    let len = end - buffer
                    
                    if len + 1 < maxLength {
                        if keepBound {
                            res = NSData(bytes: buffer, length: len + boundLen)
                        } else {
                            res = NSData(bytes: buffer, length: len)
                        }
                        return len + boundLen
                    }
                } else if self.stream.streamStatus == NSStreamStatus.AtEnd {
                    assert (!self.stream.hasBytesAvailable)
                    if maxLength > 0 && endOfStreamIsBound {
                        res = NSData(bytes: buffer, length: maxLength)
                    }
                    self.ended = true
                    return maxLength
                }
                
                return 0
            }
        }

        if res != nil {
            self.lastReadTo = 0
        }
        return res
    }

    public func close() {
        self.stream.close()
    }

    public var streamError : NSError? {
        return self.stream.streamError
    }

    public var streamStatus : NSStreamStatus {
        return self.stream.streamStatus
    }

    public var hasBytesAvailable : Bool {
        return self.buffer.length > 0
    }
}