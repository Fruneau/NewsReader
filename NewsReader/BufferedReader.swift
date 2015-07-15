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

    public enum Error : ErrorType {
        case ReadError
        case NotEnoughBytes
    }

    public init(fromStream stream: NSInputStream) {
        self.stream = stream
        self.buffer = Buffer(capacity: 2 << 20)
    }

    public convenience init?(fromString string: String) {
        if let data = (string as NSString).dataUsingEncoding(NSUTF8StringEncoding) {
            let stream = NSInputStream(data: data)

            stream.open()
            self.init(fromStream: stream)
        } else {
            return nil
        }
    }

    private func fillBuffer(minSize: Int) throws {
        var remain = minSize

        while remain > 0 {
            if !self.stream.hasBytesAvailable {
                throw Error.NotEnoughBytes
            }
            try self.buffer.append(remain) {
                (buffer, length) throws in

                switch (self.stream.read(UnsafeMutablePointer<UInt8>(buffer), maxLength: length)) {
                case 0:
                    throw Error.NotEnoughBytes

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
        var shouldContinue = true

        if self.ended {
            return nil
        }

        while true {
            var res : String?
            var hasReply = false

            self.buffer.read() {
                (buffer, maxLength) in

                let end = memchr(buffer, 0x0d, maxLength)

                if end != nil {
                    let len = end - buffer

                    if len + 1 < maxLength {
                        res = NSString(bytes: buffer, length: len, encoding: NSUTF8StringEncoding) as String?
                        hasReply = true
                        return len + 2
                    }
                } else if self.stream.streamStatus == NSStreamStatus.AtEnd {
                    if end != nil {
                        res = NSString(bytes: buffer, length: maxLength - 1, encoding: NSUTF8StringEncoding) as String?
                    } else if maxLength > 0 {
                        res = NSString(bytes: buffer, length: maxLength, encoding: NSUTF8StringEncoding) as String?
                    }
                    hasReply = true
                    return maxLength
                }

                return 0
            }

            if hasReply {
                return res
            }

            if !shouldContinue {
                return nil
            }

            do {
                try self.fillBuffer(4 << 10)
            } catch Error.NotEnoughBytes {
                shouldContinue = false
            }
        }
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