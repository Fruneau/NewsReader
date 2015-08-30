//
//  MIME.swift
//  NewsReader
//
//  Created by Florent Bruneau on 26/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Lib

public enum Error : ErrorType, CustomStringConvertible, CustomDebugStringConvertible {
    case MalformedHeader(name: NSData, content: NSData, error: ErrorType?)
    case EmptyHeaderLine
    case MalformedHeaderName(NSData)
    case MalformedHeaderContent(NSData)
    case MalformedDate(String)

    case MissingHeaderEndMark
    case UnexpectedHeaderEndMark
    case UnsupportedHeaderEncoding(encoding: String)
    case UnsupportedHeaderCharset(charset: String)
    case EncodingError(value: String)

    public var description : String {
        return self.debugDescription
    }

    public var debugDescription : String {
        switch (self) {
        case .MalformedHeader(name: let name, content: let content, error: let e):
            return "MalformedHeader(\(String.fromData(name)!), \(String.fromData(content)!), \(e))"

        case .EmptyHeaderLine:
            return "EmptyHeaderLine"

        case .MalformedHeaderName(let s):
            return "MalformedHeaderName(\(String.fromData(s)!))"

        case .MalformedHeaderContent(let s):
            return "MalformedHeaderContent(\(String.fromData(s)!))"

        case .MissingHeaderEndMark:
            return "MissingHeaderEndMark"

        case .UnexpectedHeaderEndMark:
            return "UnexpectedHeaderEndMark"

        case .UnsupportedHeaderEncoding(let s):
            return "UnsupportedHeaderEncoding(\(s))"

        case .UnsupportedHeaderCharset(let s):
            return "UnsupportedHeaderCharset(\(s))"

        case .EncodingError(let s):
            return "EncodingError(\(s))"

        case .MalformedDate(let s):
            return "MaformedDate(\(s))"
        }
    }
}

public struct MIMEAddress {
    public let address : String
    public let email : String
    public let name : String?

    static private let nameEmailRe = try!
        NSRegularExpression(pattern: "\"?([^<>\"]+)\"? +<(.+@.+)>", options: [])
    static private let emailNameRe = try!
        NSRegularExpression(pattern: "([^ ]+@[^ ]+) \\((.*)\\)", options: [])
    static private let emailRe = try!
        NSRegularExpression(pattern: "<?([^< ]+@[^> ]+)>?", options: [])

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

    public var dictionary : NSDictionary {
        var dict = [ "full": self.address, "email": self.email ]

        if let name = self.name {
            dict["name"] = name
        }

        return NSDictionary(dictionary: dict)
    }
}

public enum MIMEHeader {
    case Generic(name: String, content: String)
    case Address(name: String, address: MIMEAddress)
    case Newsgroup(name: String, group: String)
    case NewsgroupRef(group: String, number: Int)
    case MessageId(name: String, msgid: String)
    case Date(NSDate)

    private static let dateParser : NSDateFormatter = {
        let f = NSDateFormatter()

        f.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        f.timeZone = NSTimeZone(abbreviation: "GMT")
        f.dateFormat = "E, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    private static let dateAltParser : NSDateFormatter = {
        let f = NSDateFormatter()

        f.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        f.timeZone = NSTimeZone(abbreviation: "GMT")
        f.dateFormat = "E, dd MMM yyyy HH:mm:ss Z (zzz)"
        return f
    }()

    private static let dateDetector : NSDataDetector = {
        return try! NSDataDetector(types: NSTextCheckingType.Date.rawValue)
    }()

    static private func parseDate(content : String) -> NSDate? {
        if let date = MIMEHeader.dateParser.dateFromString(content) {
            return date
        } else if let date = MIMEHeader.dateAltParser.dateFromString(content) {
            return date
        } else if let match = MIMEHeader.dateDetector.firstMatchInString(content, options: [], range: NSMakeRange(0, content.characters.count)) {
            return match.date
        }

        return nil
    }

    private var name : String {
        switch (self) {
        case .Generic(name: let name, content: _):
            return name

        case .Address(name: let name, address: _):
            return name

        case .Newsgroup(name: let name, group: _):
            return name

        case .NewsgroupRef(group: _, number: _):
            return "xref"

        case .MessageId(name: let name, msgid: _):
            return name

        case .Date(_):
            return "date"
        }
    }

    public var dictionary : NSDictionary {
        switch (self) {
        case .Generic(name: _, content: let string):
            return NSDictionary(dictionary: [ "type": "generic", "content": string ])

        case .Address(name: _, address: let address):
            return NSDictionary(dictionary: [ "type": "address", "address": address.dictionary ])

        case .Newsgroup(name: _, group: let group):
            return NSDictionary(dictionary: [ "type": "newsgroup", "group": group ])

        case .NewsgroupRef(group: let group, number: let num):
            return NSDictionary(dictionary: [ "type": "newsgroupref", "group": group, "number": num ])

        case .MessageId(name: _, msgid: let msgid):
            return NSDictionary(dictionary: [ "type": "messageid", "msgid": msgid ])

        case .Date(let date):
            return NSDictionary(dictionary: [ "type": "date", "date": date ])
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
            guard let data = NSData(base64EncodedString: chunk, options: []) else {
                print("bad base64")
                throw Error.EncodingError(value: chunk)
            }
            guard let decoded = String.fromData(data, encoding: charset) else {
                print("bad charset")
                throw Error.EncodingError(value: chunk)
            }

            return decoded as String

        case "q", "Q":
            guard let data = NSData(quotedPrintableString: chunk) else {
                throw Error.EncodingError(value: chunk)
            }
            guard let decoded = String.fromData(data, encoding: charset) else {
                throw Error.EncodingError(value: chunk)
            }

            return decoded as String

        default:
            throw Error.UnsupportedHeaderEncoding(encoding: encoding)
        }
    }

    static private func decodeRFC2047(headerLine: NSData) throws -> String {
        guard var content = String.fromData(headerLine) else {
            throw Error.MalformedHeaderContent(headerLine)
        }

        if !content.containsString("=?") {
            return content
        }

        var matches = rfc2047Re.matchesInString(content, options: [], range: NSMakeRange(0, content.characters.count))

        matches.sortInPlace { $0.range.location > $1.range.location }

        for match in matches {
            let charset = (content as NSString).substringWithRange(match.rangeAtIndex(1))
            let encoding = (content as NSString).substringWithRange(match.rangeAtIndex(2))
            let chunk = (content as NSString).substringWithRange(match.rangeAtIndex(3))

            content = (content as NSString).stringByReplacingCharactersInRange(match.range, withString: try MIMEHeader.decodeRFC2047Chunk(chunk, withEncoding: encoding, andCharset: charset))
        }

        return content
    }

    static func appendHeader(inout headers : [MIMEHeader], name: NSData, encodedContent : NSData) throws {
        let cset = NSCharacterSet.whitespaceCharacterSet()
        var content : String
        do {
            content = try MIMEHeader.decodeRFC2047(encodedContent)
        } catch let e {
            throw Error.MalformedHeader(name: name, content: encodedContent, error: e)
        }

        guard let originalName = String.fromData(name) else {
            throw Error.MalformedHeaderName(name)
        }

        if originalName.stringByTrimmingCharactersInSet(cset) != originalName {
            throw Error.MalformedHeaderName(name)
        }

        let lower = originalName.lowercaseString

        switch lower {
        case "from":
            headers.append(.Address(name: lower, address: MIMEAddress.parse(content)))

        case "cc", "to":
            for slice in content.characters.split(",") {
                let addr = String(slice).stringByTrimmingCharactersInSet(cset)

                headers.append(.Address(name: lower, address: MIMEAddress.parse(addr)))
            }

        case "newsgroups", "followup-to":
            for slice in content.characters.split(",") {
                let group = String(slice).stringByTrimmingCharactersInSet(cset)

                headers.append(.Newsgroup(name: lower, group: group))
            }

        case "message-id", "in-reply-to":
            headers.append(.MessageId(name: lower, msgid: content))

        case "references":
            let scanner = NSScanner(string: content)

            scanner.charactersToBeSkipped = NSCharacterSet.whitespaceCharacterSet()
            while !scanner.atEnd {
                var msgid : NSString?

                if !scanner.scanUpToString(">", intoString: &msgid)
                || !scanner.skipString(">")
                {
                    throw Error.MalformedHeader(name: name, content: encodedContent, error: nil)
                }

                headers.append(.MessageId(name: lower, msgid: (msgid! as String) + ">"))
            }

        case "date":
            guard let date = MIMEHeader.parseDate(content) else {
                throw Error.MalformedDate(content)
            }

            headers.append(.Date(date))

        case "xref":
            let slices = content.characters.split(" ")

            for slice in slices[1..<slices.count] {
                let scanner = NSScanner(string: String(slice))
                var group : NSString?
                var num : Int = 0

                if !scanner.scanUpToString(":", intoString: &group)
                || !scanner.skipString(":")
                || !scanner.scanInteger(&num)
                || !scanner.atEnd
                {
                    throw Error.MalformedHeader(name: name, content: encodedContent, error: nil)
                }

                headers.append(.NewsgroupRef(group: group! as String, number: num))
            }
            break

        default:
            headers.append(.Generic(name: lower, content: content))
        }
    }

    private enum ParseHeader : ErrorType {
        case EndOfHeaders(body: NSData)
    }

    static func parse(data: NSData) throws -> ([MIMEHeader], NSData?) {
        let cset = NSCharacterSet.whitespaceCharacterSet()
        var headers : [MIMEHeader] = []

        do {
            var currentHeader : NSData?
            var currentValue : NSMutableData?

            try data.forEachChunk("\r\n") {
                (line, pos) in

                switch line {
                case _ where line.length == 0:
                    /* Reached end of headers */
                    let dataBytes = data.bytes + pos
                    let remaining = data.length - pos

                    if let hdr = currentHeader, let value = currentValue {
                        try MIMEHeader.appendHeader(&headers, name: hdr, encodedContent: value)
                    }

                    if remaining < 2 {
                        throw ParseHeader.EndOfHeaders(body: NSData(data: line))
                    } else {
                        throw ParseHeader.EndOfHeaders(body: NSData(bytes: dataBytes + 2, length: remaining - 2))
                    }

                case _ where cset.characterIsMember(unichar(UnsafePointer<UInt8>(line.bytes)[0])):
                    var bytes = UnsafePointer<UInt8>(line.bytes)
                    var len = line.length


                    while len > 0 && cset.characterIsMember(unichar(bytes[0])) {
                        bytes++
                        len--
                    }

                    if len == 0 {
                        throw Error.MalformedHeader(name: currentHeader!, content: currentValue!, error: nil)
                    }

                    var space : UInt8 = 0x20 /* space */
                    currentValue?.appendBytes(&space, length: 1)
                    currentValue?.appendBytes(bytes, length: len)


                default:
                    if let hdr = currentHeader, let value = currentValue {
                        try MIMEHeader.appendHeader(&headers, name: hdr, encodedContent: value)
                        currentHeader = nil
                        currentValue = nil
                    }

                    do {
                        try line.forEachChunk(":") {
                            (data, pos) in

                            if currentHeader == nil {
                                currentHeader = NSData(data: data)
                            } else {
                                var bytes = UnsafePointer<UInt8>(line.bytes) + pos
                                var len = line.length - pos

                                while len > 0 && cset.characterIsMember(unichar(bytes[0])) {
                                    bytes++
                                    len--
                                }

                                if len == 0 {
                                    throw Error.MalformedHeader(name: currentHeader!, content: data, error: nil)
                                }
                                
                                currentValue = NSMutableData(bytes: bytes, length: len)
                                throw ParseHeader.EndOfHeaders(body: currentValue!)
                            }
                        }
                    } catch ParseHeader.EndOfHeaders(body: _) {
                    }
                }
            }
            if let hdr = currentHeader, let value = currentValue {
                try MIMEHeader.appendHeader(&headers, name: hdr, encodedContent: value)
            }

            return (headers, nil)
        } catch ParseHeader.EndOfHeaders(body: let body) {

            return (headers, body)
        }
    }

    static func parseHeaders(data: NSData) throws -> [MIMEHeader] {
        let (headers, body) = try MIMEHeader.parse(data)

        if body != nil {
            throw Error.UnexpectedHeaderEndMark
        }

        return headers
    }

    static func parseHeadersAndGetBody(data: NSData) throws -> ([MIMEHeader], NSData) {
        let (headers, optBody) = try MIMEHeader.parse(data)

        guard let body = optBody else {
            throw Error.MissingHeaderEndMark
        }

        return (headers, body)
    }
}

public class MIMEHeaders {
    private let headers : [String: [MIMEHeader]]

    private init(headers: [MIMEHeader]) {
        var map : [String: [MIMEHeader]] = [:]

        for hdr in headers {
            let name = hdr.name.lowercaseString

            if map[name] == nil {
                map[name] = [hdr]
            } else {
                map[name]?.append(hdr)
            }
        }

        self.headers = map
    }

    public subscript(name: String) -> [MIMEHeader]? {
        return self.headers[name.lowercaseString]
    }

    static public func parse(data: NSData) throws -> MIMEHeaders {
        let headers = try MIMEHeader.parseHeaders(data)

        return MIMEHeaders(headers: headers)
    }

    public var dictionary : NSDictionary {
        let dict = NSMutableDictionary()

        for (name, values) in self.headers {
            let array = NSMutableArray()

            for header in values {
                array.addObject(header.dictionary)
            }
            dict[name] = array
        }
        return dict
    }
}

public class MIMEPart {
    public let headers : MIMEHeaders
    public let body : NSData

    private init(headers: [MIMEHeader], body: NSData) {
        self.headers = MIMEHeaders(headers: headers)
        self.body = body
    }

    static public func parse(data: NSData) throws -> MIMEPart {
        let (headers, body) = try MIMEHeader.parseHeadersAndGetBody(data)

        return MIMEPart(headers: headers, body: body)
    }
}