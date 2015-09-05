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
    case UnsupportedCharset(charset: String)
    case HeaderEncodingError(value: String)
    case BodyEncodingError(encoding: MIMEEncoding, body: NSData)
    case BodyCharsetError(charset: String, body: NSData)


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

        case .UnsupportedCharset(let s):
            return "UnsupportedCharset(\(s))"

        case .HeaderEncodingError(let s):
            return "HeaderEncodingError(\(s))"

        case .BodyEncodingError(encoding: let enc, body: let s):
            return "BodyEncodingError(\(enc), \(String.fromData(s)))"

        case .BodyCharsetError(charset: let charset, body: let s):
            return "BodyCharsetError(\(charset), \(String.fromData(s)))"

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

    public init(address: String, email: String, name: String?) {
        self.address = address
        self.email = email
        self.name = name
    }

    public init?(fromDictionary dictionary: NSDictionary) {
        guard let address = dictionary["full"] as? String else {
            return nil
        }
        self.address = address

        guard let email = dictionary["email"] as? String else {
            return nil
        }
        self.email = email
        self.name = dictionary["name"] as? String
    }
}

public enum MIMEEncoding : CustomStringConvertible {
    case Bit7
    case Bit8
    case Binary
    case QuotedPrintable
    case Base64
    case Unsupported(String)

    public init(encoding: String) {
        switch encoding.lowercaseString {
        case "7bit": self = .Bit7
        case "8bit": self = .Bit8
        case "binary": self = .Binary
        case "quoted-printable": self = .QuotedPrintable
        case "base64": self = .Base64
        case let e: self = .Unsupported(e)
        }
    }

    public var description : String {
        switch self {
        case .Bit7: return "7bit"
        case .Bit8: return "8bit"
        case .Binary: return "binary"
        case .QuotedPrintable: return "quoted-printable"
        case .Base64: return "base64"
        case .Unsupported(let e): return e
        }
    }
}

public enum MIMEHeader {
    case Generic(name: String, content: String)
    case Address(name: String, address: MIMEAddress)
    case Newsgroup(name: String, group: String)
    case NewsgroupRef(group: String, number: Int)
    case MessageId(name: String, msgid: String)
    case Date(NSDate)
    case ContentType(type: String, subtype: String, parameters: [String: String])
    case ContentTransferEncoding(MIMEEncoding)

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

        case .ContentType(type: _, subtype: _, parameters: _):
            return "content-type"

        case .ContentTransferEncoding(_):
            return "content-transfer-encoding"
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

        case .ContentType(type: let type, subtype: let subtype, parameters: let parameters):
            return NSDictionary(dictionary: [ "type": "content-type", "content-type": type, "content-subtype": subtype, "parameters": parameters])

        case .ContentTransferEncoding(let enc):
            return NSDictionary(dictionary: [ "type": "content-transfer-encoding", "encoding": enc.description ])
        }
    }

    public init?(fromDictionary dictionary: NSDictionary, forHeader header: String) {
        switch dictionary["type"] as? String {
        case "generic"?:
            guard let content = dictionary["content"] as? String else {
                return nil
            }
            self = .Generic(name: header, content: content)

        case "address"?:
            guard let address = dictionary["address"] as? NSDictionary,
                  let mimeAddress = MIMEAddress(fromDictionary: address) else {
                return nil
            }
            self = .Address(name: header, address: mimeAddress)

        case "newsgroup"?:
            guard let group = dictionary["group"] as? String else {
                return nil
            }
            self = .Newsgroup(name: header, group: group)

        case "newsgroupref"?:
            guard let group = dictionary["group"] as? String,
                  let number = dictionary["number"] as? Int else {
                return nil
            }
            self = .NewsgroupRef(group: group, number: number)

        case "messageid"?:
            guard let msgid = dictionary["msgid"] as? String else {
                return nil
            }
            self = .MessageId(name: header, msgid: msgid)

        case "date"?:
            guard let date = dictionary["date"] as? NSDate else {
                return nil
            }
            self = .Date(date)

        case "content-type"?:
            guard let type = dictionary["content-type"] as? String,
                  let subtype = dictionary["content-subtype"] as? String,
                  let parameters = dictionary["parameters"] as? [String: String] else {
                return nil
            }
            self = .ContentType(type: type, subtype: subtype, parameters: parameters)

        case "content-transfer-encoding"?:
            guard let enc = dictionary["encoding"] as? String else {
                return nil
            }
            self = .ContentTransferEncoding(MIMEEncoding(encoding: enc))

        default:
            return nil
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
            throw Error.UnsupportedCharset(charset: charset)
        }

        let charset = CFStringConvertEncodingToNSStringEncoding(cfCharset)

        switch (encoding) {
        case "b", "B":
            guard let data = NSData(base64EncodedString: chunk, options: []) else {
                print("bad base64")
                throw Error.HeaderEncodingError(value: chunk)
            }
            guard let decoded = String.fromData(data, encoding: charset) else {
                print("bad charset")
                throw Error.HeaderEncodingError(value: chunk)
            }

            return decoded as String

        case "q", "Q":
            guard let data = NSData(quotedPrintableString: chunk) else {
                throw Error.HeaderEncodingError(value: chunk)
            }
            guard let decoded = String.fromData(data, encoding: charset) else {
                throw Error.HeaderEncodingError(value: chunk)
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

        case "message-id", "in-reply-to", "content-id":
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

        case "content-type":
            let cset = NSCharacterSet(charactersInString: " \t;")
            let scanner = NSScanner(string: content)
            var type : NSString?
            var subtype : NSString?

            scanner.charactersToBeSkipped = nil
            scanner.skipCharactersFromSet(NSCharacterSet.whitespaceCharacterSet())

            if !scanner.scanUpToString("/", intoString: &type)
            || !scanner.skipString("/")
            {
                print("1")
                throw Error.MalformedHeader(name: name, content: encodedContent, error: nil)
            }

            if !scanner.scanUpToCharactersFromSet(cset, intoString: &subtype) {
                subtype = scanner.remainder as NSString
                headers.append(.ContentType(type: type! as String, subtype: subtype! as String, parameters: [:]))
                break
            }

            subtype = subtype?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            var parameters : [String: String] = [:]
            while scanner.skipString(";") {
                scanner.skipCharactersFromSet(cset)

                var attrName : NSString?
                var attrValue : NSString?

                if !scanner.scanUpToString("=", intoString: &attrName)
                || !scanner.skipString("=")
                {
                    print("2")
                    throw Error.MalformedHeader(name: name, content: encodedContent, error: nil)
                }

                if scanner.skipString("\"") {
                    if !scanner.scanUpToString("\"", intoString: &attrValue)
                    || !scanner.skipString("\"")
                    {
                        print("3")
                        throw Error.MalformedHeader(name: name, content: encodedContent, error: nil)
                    }
                } else if !scanner.scanUpToCharactersFromSet(cset, intoString: &attrValue) {
                    attrValue = scanner.remainder as NSString
                } else {
                    attrValue = attrValue?.stringByTrimmingCharactersInSet(cset)
                }

                parameters[(attrName! as String).lowercaseString] = attrValue! as String
                scanner.skipCharactersFromSet(NSCharacterSet.whitespaceCharacterSet())
            }

            if !scanner.atEnd {
                print("4: \(scanner.remainder) (\(type!) \(subtype!), \(parameters)")
                throw Error.MalformedHeader(name: name, content: encodedContent, error: nil)
            }

            headers.append(.ContentType(type: type! as String, subtype: subtype! as String, parameters: parameters))

        case "content-transfer-encoding":
            headers.append(.ContentTransferEncoding(MIMEEncoding(encoding: content)))

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

public struct MIMEHeaders {
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

    public var contentType : (type: String, subtype: String, parameters: [String:String]) {
        if case .ContentType(type: let type, subtype: let subtype, parameters: let parameters)? = self["content-type"]?.first {
            return (type: type, subtype: subtype, parameters: parameters)
        } else {
            return (type: "text", subtype: "plain", parameters: [:])
        }
    }

    public var contentTransferEncoding : MIMEEncoding {
        if case .ContentTransferEncoding(let e)? = self["content-transfer-encoding"]?.first {
            return e
        } else {
            return .Bit7
        }
    }

    public var contentCharset : String {
        if let charset = self.contentType.parameters["content-type"] {
            return charset
        } else {
            return "us-ascii"
        }
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

    public init?(fromDictionary dictionary: NSDictionary) {
        var headers : [String: [MIMEHeader]] = [:]

        for (name, values) in dictionary {
            guard let name = name as? String else {
                return nil
            }

            guard let values = values as? NSArray else {
                return nil
            }

            var content : [MIMEHeader] = []
            for value in values {
                guard let value = value as? NSDictionary else {
                    return nil
                }

                guard let header = MIMEHeader(fromDictionary: value, forHeader: name) else {
                    return nil
                }
                content.append(header)
            }
            headers[name] = content
        }
        self.headers = headers
    }
}

public class MIMEPart {
    public let headers : MIMEHeaders

    private init(headers: MIMEHeaders) {
        self.headers = headers
    }

    public func getBodyAsPlainText() -> String {
        assert (false)
    }

    static public func parse(data: NSData) throws -> MIMEPart {
        var (hdrs, body) = try MIMEHeader.parseHeadersAndGetBody(data)
        let headers = MIMEHeaders(headers: hdrs)

        switch headers.contentTransferEncoding {
        case .Bit7, .Bit8, .Binary, .Unsupported(_):
            break

        case .QuotedPrintable:
            guard let decodedData = NSData(quotedPrintableData: body) else {
                throw Error.BodyEncodingError(encoding: .QuotedPrintable, body: body)
            }

            body = decodedData

        case .Base64:
            guard let decodedData = NSData(base64EncodedData: body, options: [ .IgnoreUnknownCharacters ]) else {
                throw Error.BodyEncodingError(encoding: .Base64, body: body)
            }

            body = decodedData
        }

        switch headers.contentType {
        case (type: "text", subtype: _, parameters: _), (type: "message", subtype: _, parameters: _):
            let strCharset = headers.contentCharset
            let cfCharset = CFStringConvertIANACharSetNameToEncoding(strCharset)
            
            if cfCharset == kCFStringEncodingInvalidId {
                throw Error.UnsupportedCharset(charset: strCharset)
            }
            
            let charset = CFStringConvertEncodingToNSStringEncoding(cfCharset)
            guard let strBody = String.fromData(body, encoding: charset) else {
                throw Error.BodyCharsetError(charset: strCharset, body: body)
            }

            return MIMETextPart(headers: headers, body: strBody)

        default:
            return MIMEDataPart(headers: headers, body: body)
        }

    }
}

private class MIMETextPart : MIMEPart {
    private let body : String

    private init(headers: MIMEHeaders, body: String) {
        self.body = body
        super.init(headers: headers)
    }

    override func getBodyAsPlainText() -> String {
        return self.body
    }
}

private class MIMEDataPart : MIMEPart {
    private let body : NSData

    private init(headers: MIMEHeaders, body: NSData) {
        self.body = body
        super.init(headers: headers)
    }

    override func getBodyAsPlainText() -> String {
        return String.fromData(body)!
    }
}