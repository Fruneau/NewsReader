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
    private let lineBreak : String.UTF8View

    public enum Error : ErrorType {
        case ReadError
    }

    public init(fromStream stream: NSInputStream, lineBreak: String) {
        self.stream = stream
        self.buffer = Buffer(capacity: 2 << 20)
        self.lineBreak = lineBreak.utf8
    }

    public convenience init(fromData data: NSData, lineBreak: String) {
        let stream = NSInputStream(data: data)

        stream.open()
        self.init(fromStream: stream, lineBreak: lineBreak)
    }

    public convenience init?(fromString string: String, lineBreak: String) {
        if let data = (string as NSString).dataUsingEncoding(NSUTF8StringEncoding) {
            self.init(fromData: data, lineBreak: lineBreak)
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

    public func readLine() throws -> String? {
        if self.ended || self.lineBreak.count == 0 {
            return nil
        }

        repeat {
            var res : String?
            var hasReply = false

            try self.fillBuffer(4 << 10)
            self.buffer.read() {
                (buffer, maxLength) in

                let end = memfind(buffer, length: maxLength, str: self.lineBreak)

                if end != nil {
                    let len = end - buffer

                    if len + 1 < maxLength {
                        res = String.fromBytes(buffer, length: len)
                        hasReply = true
                        return len + self.lineBreak.count
                    }
                } else if self.stream.streamStatus == NSStreamStatus.AtEnd {
                    assert (!self.stream.hasBytesAvailable)
                    if maxLength > 0 {
                        res = String.fromBytes(buffer, length: maxLength)
                    }
                    hasReply = true
                    self.ended = true
                    return maxLength
                }

                return 0
            }

            if hasReply {
                return res
            }
        } while self.stream.hasBytesAvailable

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