//
//  MIME.swift
//  NewsReader
//
//  Created by Florent Bruneau on 26/07/2015.
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

extension NSData {
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

public enum Error : ErrorType {
    case MalformedHeader(String)
    case EmptyHeaderLine
    case MalformedHeaderName(String)

    case MissingHeaderEndMark
    case UnsupportedHeaderEncoding(encoding: String)
    case UnsupportedHeaderCharset(charset: String)
    case EncodingError(value: String)
}

private enum Header {
    case Generic(name: String, content: String)

    private init(name: String, content: String) {
        self = .Generic(name: name, content: content)
    }

    static func decodeRFC2047(headerLine: String) throws -> String? {
        if  headerLine.characters.count <= 5
            ||  !headerLine.startsWith("=?")
            ||  !headerLine.endsWith("?=")
        {
            return nil
        }

        let set = split(headerLine.characters) { $0 == "?" }.map(String.init)
        if set.count != 5 {
            return nil
        }

        let cfCharset = CFStringConvertIANACharSetNameToEncoding(set[1])
        if cfCharset == kCFStringEncodingInvalidId {
            throw Error.UnsupportedHeaderCharset(charset: set[1])
        }

        let charset = CFStringConvertEncodingToNSStringEncoding(cfCharset)
        let content = set[3]

        switch (set[2]) {
        case "b", "B":
            guard let data = NSData(base64EncodedString: content, options: NSDataBase64DecodingOptions(rawValue: 0)) else {
                throw Error.EncodingError(value: content)
            }
            guard let decoded = NSString(data: data, encoding: charset) else {
                throw Error.EncodingError(value: content)
            }

            return decoded as String

        case "q", "Q":
            guard let data = NSData(quotedPrintableString: content) else {
                throw Error.EncodingError(value: content)
            }
            guard let decoded = NSString(data: data, encoding: charset) else {
                throw Error.EncodingError(value: content)
            }

            return decoded as String

        default:
            throw Error.UnsupportedHeaderEncoding(encoding: set[2])
        }


    }

    static func appendToHeaderLine(current: String?, headerLine: String) throws -> String {
        if let decoded = try Header.decodeRFC2047(headerLine) {
            if let prev = current {
                return prev + decoded
            } else {
                return decoded
            }
        } else if let prev = current {
            return prev + " " + headerLine
        } else {
            return headerLine
        }
    }

    static func parseHeaders<S : SequenceType where S.Generator.Element == String>(data: S) throws -> [Header] {
        let cset = NSCharacterSet.whitespaceCharacterSet()
        var headers : [Header] = []
        var currentHeader : String?
        var currentValue : String?

        for var line in data {
            if line.isEmpty {
                throw Error.EmptyHeaderLine
            } else if line.characters.first! == " " {
                guard let hdr = currentValue else {
                    throw Error.MalformedHeader(line)
                }

                line = line.stringByTrimmingCharactersInSet(cset)
                currentValue = try Header.appendToHeaderLine(hdr, headerLine: line)
            } else {
                if let hdr = currentHeader {
                    headers.append(Header(name: hdr, content: currentValue!))
                }

                let vals = split(line.characters, maxSplit: 2, allowEmptySlices: false){ $0 == ":" }.map(String.init)

                if vals.count != 2 {
                    throw Error.MalformedHeaderName(vals[0])
                }

                if vals[0].stringByTrimmingCharactersInSet(cset) != vals[0] {
                    throw Error.MalformedHeaderName(vals[0])
                }

                line = vals[1].stringByTrimmingCharactersInSet(cset)
                currentValue = try Header.appendToHeaderLine(nil, headerLine: line)
                currentHeader = vals[0]
            }
        }

        if let hdr = currentHeader {
            headers.append(Header(name: hdr, content: currentValue!))
        }

        return headers
    }

    static func parseHeadersAndGetBody(data: [String]) throws -> ([Header], ArraySlice<String>) {
        guard let idx = data.indexOf("") else {
            throw Error.MissingHeaderEndMark
        }

        let sub = data[data.startIndex..<idx]
        let headers = try Header.parseHeaders(sub)
        return (headers, data[idx..<data.endIndex])
    }
}