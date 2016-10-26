//
//  BufferedReader.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

open class BufferedReader {
    fileprivate let stream : InputStream
    fileprivate let buffer: Buffer
    fileprivate var ended = false
    fileprivate var lastReadTo = 0
    fileprivate var lastBound = ""

    public enum Error : Swift.Error {
        case readError
    }

    public init(fromStream stream: InputStream) {
        self.stream = stream
        self.buffer = Buffer(capacity: 2 << 20)
    }

    public convenience init(fromData data: Data) {
        let stream = InputStream(data: data)

        stream.open()
        self.init(fromStream: stream)
    }

    public convenience init?(fromString string: String) {
        if let data = (string as NSString).data(using: String.Encoding.utf8.rawValue) {
            self.init(fromData: data)
        } else {
            return nil
        }
    }

    fileprivate func fillBuffer(_ minSize: Int) throws -> Bool {
        var filledAll = false

        try self.buffer.append(maxLength: minSize) {
            (buffer, length) throws in

            switch (self.stream.read(buffer.bindMemory(to: UInt8.self, capacity: length), maxLength: length)) {
            case 0:
                return 0

            case length:
                filledAll = true
                return length

            case let e where e > 0:
                return e

            default:
                throw Error.readError
            }
        }

        return filledAll
    }

    open func fillBuffer() throws {
        while try self.fillBuffer(64 << 10) {
        }
    }

    open func readDataUpTo(_ bound: String, keepBound: Bool, endOfStreamIsBound: Bool) throws -> Data? {
        assert (!bound.isEmpty)
        if self.ended {
            return nil
        }

        if bound != self.lastBound {
            self.lastReadTo = 0
            self.lastBound = bound
        }

        var res : Data?
        bound.withCString {
            (boundChars) in

            let boundLen = Int(strlen(boundChars))

            self.buffer.read() {
                (buffer, maxLength) in
                
                assert (maxLength >= self.lastReadTo)
                
                let end = UnsafeRawPointer(memmem(buffer + self.lastReadTo, maxLength - self.lastReadTo, boundChars, boundLen))
                self.lastReadTo = max(maxLength - boundLen, 0)

                if let end = end {
                    let len = end - buffer
                    
                    if len + 1 < maxLength {
                        if keepBound {
                            res = Data(bytes: buffer, count: len + boundLen)
                        } else {
                            res = Data(bytes: buffer, count: len)
                        }
                        return len + boundLen
                    }
                } else if self.stream.streamStatus == Stream.Status.atEnd {
                    assert (!self.stream.hasBytesAvailable)
                    if maxLength > 0 && endOfStreamIsBound {
                        res = Data(bytes: buffer, count: maxLength)
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

    open func close() {
        self.stream.close()
    }

    open var streamError : NSError? {
        return self.stream.streamError as NSError?
    }

    open var streamStatus : Stream.Status {
        return self.stream.streamStatus
    }

    open var hasBytesAvailable : Bool {
        return self.buffer.length > 0
    }
}
