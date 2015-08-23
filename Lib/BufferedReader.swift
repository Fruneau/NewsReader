//
//  BufferedReader.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

private func memfind(ptr: UnsafePointer<Void>, length: Int, str: String.UTF8View) -> UnsafePointer<Void> {
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

    private func fillBuffer(minSize: Int) throws {
        var remain = minSize

        while remain > 0 && self.stream.hasBytesAvailable {
            try self.buffer.append(remain) {
                (buffer, length) throws in

                switch (self.stream.read(UnsafeMutablePointer<UInt8>(buffer), maxLength: length)) {
                case 0:
                    return 0

                case let e where e > 0:
                    remain -= e
                    return e

                default:
                    throw Error.ReadError
                }
            }
        }
    }

    public func readDataUpTo(bound: String, keepBound: Bool, endOfStreamIsBound: Bool) throws -> NSData? {
        let boundChars = bound.utf8

        assert (boundChars.count > 0)
        if self.ended {
            return nil
        }

        if bound != self.lastBound {
            self.lastReadTo = 0
            self.lastBound = bound
        }

        repeat {
            var res : NSData?

            try self.fillBuffer(64 << 10)
            self.buffer.read() {
                (buffer, maxLength) in

                assert (maxLength >= self.lastReadTo)

                let end = memfind(buffer + self.lastReadTo, length: maxLength - self.lastReadTo, str: boundChars)
                self.lastReadTo = max(maxLength - boundChars.count, 0)

                if end != nil {
                    let len = end - buffer

                    if len + 1 < maxLength {
                        if keepBound {
                            res = NSData(bytes: buffer, length: len + boundChars.count)
                        } else {
                            res = NSData(bytes: buffer, length: len)
                        }
                        return len + boundChars.count
                    }
                } else if self.stream.streamStatus == NSStreamStatus.AtEnd {
                    assert (!self.stream.hasBytesAvailable)
                    if maxLength > 0 {
                        res = NSData(bytes: buffer, length: maxLength)
                    }
                    self.ended = true
                    return maxLength
                }

                return 0
            }

            if res != nil {
                self.lastReadTo = 0
                return res
            }
        } while self.stream.hasBytesAvailable && !self.ended

        return nil
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
}