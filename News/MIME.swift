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

    public var detail : String {
        switch (self) {
        case .MalformedHeader(let s):
            return "MalformedHeader(\(s))"

        case .EmptyHeaderLine:
            return "EmptyHeaderLine"

        case .MalformedHeaderName(let s):
            return "MalformedHeaderName(\(s))"

        case .MissingHeaderEndMark:
            return "MissingHeaderEndMark"

        case .UnsupportedHeaderEncoding(let s):
            return "UnsupportedHeaderEncoding(\(s))"

        case .UnsupportedHeaderCharset(let s):
            return "UnsupportedHeaderCharset(\(s))"

        case .EncodingError(let s):
            return "EncodingError(\(s))"
        }
    }
}

public struct MIMEAddress {
    public let address : String
    public let email : String
    public let name : String?

    static private let nameEmailRe = try!
        NSRegularExpression(pattern: "\"?([^<>\"]+)\"? +<(.+@.+)>",
            options: NSRegularExpressionOptions(rawValue: 0))
    static private let emailNameRe = try!
        NSRegularExpression(pattern: "([^ ]+@[^ ]+) \\((.*)\\)",
            options: NSRegularExpressionOptions(rawValue: 0))
    static private let emailRe = try!
        NSRegularExpression(pattern: "<?([^< ]+@[^> ]+)>?",
            options: NSRegularExpressionOptions(rawValue: 0))

    private static func parse(address: String) -> MIMEAddress {
        let range = NSMakeRange(0, address.characters.count)
        let options = NSMatchingOptions.Anchored

        if let match = nameEmailRe.firstMatchInString(address, options: options, range: range) {
            return MIMEAddress(address: address,
                email: (address as NSString).substringWithRange(match.rangeAtIndex(2)),
                name: (address as NSString).substringWithRange(match.rangeAtIndex(1)))
        }

        if let match = emailNameRe.firstMatchInString(address, options: options, range: range) {
            return MIMEAddress(address: address,
                email: (address as NSString).substringWithRange(match.rangeAtIndex(1)),
                name: (address as NSString).substringWithRange(match.rangeAtIndex(2)))
        }

        if let match = emailRe.firstMatchInString(address, options: options, range: range) {
            return MIMEAddress(address: address,
                email: (address as NSString).substringWithRange(match.rangeAtIndex(1)),
                name: nil)
        }

        return MIMEAddress(address: address, email: address, name: nil)
    }
}

public enum MIMEHeader {
    case Generic(name: String, content: String)
    case Address(name: String, address: MIMEAddress)

    private init(name: String, content: String) throws {
        let lower = name.lowercaseString

        switch (lower) {
        case "from", "cc", "to":
            self = .Address(name: lower, address: MIMEAddress.parse(content))

        default:
            self = .Generic(name: lower, content: content)
        }
    }

    private var name : String {
        switch (self) {
        case .Generic(name: let name, content: _):
            return name

        case .Address(name: let name, address: _):
            return name
        }
    }

    static private var rfc2047Re = try!
        NSRegularExpression(pattern: "=\\?([^?]*)\\?([bq])\\?([^?]*)\\?=", options: NSRegularExpressionOptions.CaseInsensitive)

    static private func decodeRFC2047Chunk(chunk: String,
        withEncoding encoding: String,
        andCharset charset: String) throws -> String
    {

        let cfCharset = CFStringConvertIANACharSetNameToEncoding(charset)
        if cfCharset == kCFStringEncodingInvalidId {
            throw Error.UnsupportedHeaderCharset(charset: charset)
        }

        let charset = CFStringConvertEncodingToNSStringEncoding(cfCharset)

        switch (encoding) {
        case "b", "B":
            guard let data = NSData(base64EncodedString: chunk, options: NSDataBase64DecodingOptions(rawValue: 0)) else {
                throw Error.EncodingError(value: chunk)
            }
            guard let decoded = NSString(data: data, encoding: charset) else {
                throw Error.EncodingError(value: chunk)
            }

            return decoded as String

        case "q", "Q":
            guard let data = NSData(quotedPrintableString: chunk) else {
                throw Error.EncodingError(value: chunk)
            }
            guard let decoded = NSString(data: data, encoding: charset) else {
                throw Error.EncodingError(value: chunk)
            }

            return decoded as String

        default:
            throw Error.UnsupportedHeaderEncoding(encoding: encoding)
        }
    }

    static private func decodeRFC2047(var headerLine: String) throws -> String {
        var matches = rfc2047Re.matchesInString(headerLine, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, headerLine.characters.count))

        matches.sortInPlace { $0.range.location > $1.range.location }

        for match in matches {
            let charset = (headerLine as NSString).substringWithRange(match.rangeAtIndex(1))
            let encoding = (headerLine as NSString).substringWithRange(match.rangeAtIndex(2))
            let chunk = (headerLine as NSString).substringWithRange(match.rangeAtIndex(3))

            print("found one chunk with enc \(encoding) and charset \(charset)")
            headerLine = (headerLine as NSString).stringByReplacingCharactersInRange(match.range, withString: try MIMEHeader.decodeRFC2047Chunk(chunk, withEncoding: encoding, andCharset: charset))
        }

        return headerLine
    }

    static func parseHeaders<S : SequenceType where S.Generator.Element == String>(data: S) throws -> [MIMEHeader] {
        let cset = NSCharacterSet.whitespaceCharacterSet()
        var headers : [MIMEHeader] = []
        var currentHeader : String?
        var currentValue : String?

        for var line in data {
            if line.isEmpty {
                throw Error.EmptyHeaderLine
            } else if cset.characterIsMember(line.utf16.first!) {
                line = line.stringByTrimmingCharactersInSet(cset)
                currentValue?.append(Character(" "))
                currentValue?.extend(line)
            } else {
                if let hdr = currentHeader {
                    let val = try MIMEHeader.decodeRFC2047(currentValue!)
                    headers.append(try MIMEHeader(name: hdr, content: val))
                }

                let vals = split(line.characters, maxSplit: 1, allowEmptySlices: true){ $0 == ":" }.map(String.init)

                if vals.count != 2 {
                    throw Error.MalformedHeader(line)
                }

                if vals[0].stringByTrimmingCharactersInSet(cset) != vals[0] {
                    throw Error.MalformedHeaderName(vals[0])
                }

                line = vals[1].stringByTrimmingCharactersInSet(cset)
                currentValue = line
                currentHeader = vals[0]
            }
        }

        if let hdr = currentHeader {
            let val = try MIMEHeader.decodeRFC2047(currentValue!)
            headers.append(try MIMEHeader(name: hdr, content: val))
        }

        return headers
    }

    static func parseHeadersAndGetBody(data: [String]) throws -> ([MIMEHeader], ArraySlice<String>) {
        guard let idx = data.indexOf("") else {
            throw Error.MissingHeaderEndMark
        }

        let sub = data[data.startIndex..<idx]
        let headers = try MIMEHeader.parseHeaders(sub)
        return (headers, data[idx..<data.endIndex])
    }
}

public class MIMEHeaders {
    private let headers : [String: MIMEHeader]
    public let from : MIMEAddress?
    public let to : MIMEAddress?
    public let subject : String?

    private init(headers: [String: MIMEHeader], from: MIMEAddress?, to: MIMEAddress?,
        subject: String?) {
        self.from = from
        self.to = to
        self.subject = subject
        self.headers = headers
    }

    private convenience init(headers: [MIMEHeader]) {
        var map : [String: MIMEHeader] = [:]
        var from : MIMEAddress?
        var to : MIMEAddress?
        var subject : String?

        for hdr in headers {
            map[hdr.name] = hdr

            switch hdr {
            case .Address(name: let n, address: let a) where n == "from":
                from = a

            case .Address(name: let n, address: let a) where n == "to":
                to = a

            case .Generic(name: let n, content: let v) where n == "subject":
                subject = v

            default:
                break
            }
        }
        self.init(headers: map, from: from, to: to, subject: subject)
    }

    public subscript(name: String) -> MIMEHeader? {
        return self.headers[name.lowercaseString]
    }

    static public func parse(data: [String]) throws -> MIMEHeaders {
        let headers = try MIMEHeader.parseHeaders(data)

        return MIMEHeaders(headers: headers)
    }
}

public class MIMEPart {
    public let headers : MIMEHeaders
    public let body : String

    private init(headers: [MIMEHeader], body: ArraySlice<String>) {
        self.headers = MIMEHeaders(headers: headers)
        self.body = "\r\n".join(body)
    }

    static public func parse(data: [String]) throws -> MIMEPart {
        let (headers, body) = try MIMEHeader.parseHeadersAndGetBody(data)

        return MIMEPart(headers: headers, body: body)
    }
}