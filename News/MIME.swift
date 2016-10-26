//
//  MIME.swift
//  NewsReader
//
//  Created by Florent Bruneau on 26/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Lib

public indirect enum Error : Swift.Error, CustomStringConvertible, CustomDebugStringConvertible {
    case malformedHeader(name: Data, content: Data, error: Swift.Error?)
    case emptyHeaderLine
    case malformedHeaderName(Data)
    case malformedHeaderContent(Data)
    case malformedDate(String)

    case missingHeaderEndMark
    case unexpectedHeaderEndMark
    case unsupportedHeaderEncoding(encoding: String)
    case unsupportedCharset(charset: String)
    case headerEncodingError(value: String)
    case bodyEncodingError(encoding: MIMEEncoding, body: Data)
    case bodyCharsetError(charset: String, body: Data)
    case invalidRfc1521Parameter
    case invalidContentType

    public var description : String {
        return self.debugDescription
    }

    public var debugDescription : String {
        switch (self) {
        case .malformedHeader(name: let name, content: let content, error: let e):
            return "MalformedHeader(\(String.fromData(name)!), \(String.fromData(content)!), \(e))"

        case .emptyHeaderLine:
            return "EmptyHeaderLine"

        case .malformedHeaderName(let s):
            return "MalformedHeaderName(\(String.fromData(s)!))"

        case .malformedHeaderContent(let s):
            return "MalformedHeaderContent(\(String.fromData(s)!))"

        case .missingHeaderEndMark:
            return "MissingHeaderEndMark"

        case .unexpectedHeaderEndMark:
            return "UnexpectedHeaderEndMark"

        case .unsupportedHeaderEncoding(let s):
            return "UnsupportedHeaderEncoding(\(s))"

        case .unsupportedCharset(let s):
            return "UnsupportedCharset(\(s))"

        case .headerEncodingError(let s):
            return "HeaderEncodingError(\(s))"

        case .bodyEncodingError(encoding: let enc, body: let s):
            return "BodyEncodingError(\(enc), \(String.fromData(s)))"

        case .bodyCharsetError(charset: let charset, body: let s):
            return "BodyCharsetError(\(charset), \(String.fromData(s)))"

        case .malformedDate(let s):
            return "MaformedDate(\(s))"

        case .invalidRfc1521Parameter:
            return "InvalidRfc1521Parameter"

        case .invalidContentType:
            return "InvalidContentType"
        }
    }
}

public struct MIMEAddress {
    public let address : String
    public let email : String
    public let name : String?

    static fileprivate let nameEmailRe = try!
        NSRegularExpression(pattern: "\"?([^<>\"]+)\"? +<(.+@.+)>", options: [])
    static fileprivate let emailNameRe = try!
        NSRegularExpression(pattern: "([^ ]+@[^ ]+) \\((.*)\\)", options: [])
    static fileprivate let emailRe = try!
        NSRegularExpression(pattern: "<?([^< ]+@[^> ]+)>?", options: [])

    fileprivate static func parse(_ address: String) -> MIMEAddress {
        let range = NSMakeRange(0, address.characters.count)
        let options = NSRegularExpression.MatchingOptions.anchored

        if let match = nameEmailRe.firstMatch(in: address, options: options, range: range) {
            return MIMEAddress(address: address,
                email: (address as NSString).substring(with: match.rangeAt(2)),
                name: (address as NSString).substring(with: match.rangeAt(1)))
        }

        if let match = emailNameRe.firstMatch(in: address, options: options, range: range) {
            return MIMEAddress(address: address,
                email: (address as NSString).substring(with: match.rangeAt(1)),
                name: (address as NSString).substring(with: match.rangeAt(2)))
        }

        if let match = emailRe.firstMatch(in: address, options: options, range: range) {
            return MIMEAddress(address: address,
                email: (address as NSString).substring(with: match.rangeAt(1)),
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

/** MIME Encodings as described in RFC 2045.
 */
public enum MIMEEncoding : CustomStringConvertible {
    case bit7
    case bit8
    case binary
    case quotedPrintable
    case base64
    case unsupported(String)

    public init(encoding: String) {
        switch encoding.lowercased() {
        case "7bit": self = .bit7
        case "8bit": self = .bit8
        case "binary": self = .binary
        case "quoted-printable": self = .quotedPrintable
        case "base64": self = .base64
        case let e: self = .unsupported(e)
        }
    }

    public var description : String {
        switch self {
        case .bit7: return "7bit"
        case .bit8: return "8bit"
        case .binary: return "binary"
        case .quotedPrintable: return "quoted-printable"
        case .base64: return "base64"
        case .unsupported(let e): return e
        }
    }
}

/** MIME Dispositions as described in RFC 1806
 */
public enum MIMEDisposition : CustomStringConvertible {
    case inline
    case attachment
    case unsupported(String)

    public init(disposition: String) {
        switch disposition.lowercased() {
        case "inline": self = .inline
        case "attachment": self = .attachment
        case let e: self = .unsupported(e)
        }
    }

    public var description : String {
        switch self {
        case .inline: return "inline"
        case .attachment: return "attachment"
        case .unsupported(let e): return e
        }
    }
}

public enum MIMEHeader {
    case generic(name: String, content: String)
    case address(name: String, address: MIMEAddress)
    case newsgroup(name: String, group: String)
    case newsgroupRef(group: String, number: Int)
    case messageId(name: String, msgid: String)
    case date(Foundation.Date)

    /** Content-Type header as described in RFC 2045
     */
    case contentType(type: String, subtype: String, parameters: [String: String])

    /** Content-Transfer-Encoding header as described in RFC 2045.
     */
    case contentTransferEncoding(MIMEEncoding)

    /** Content disposition header as described in RFC 1806.
     */
    case contentDisposition(disposition: MIMEDisposition, parameters: [String: String])

    fileprivate static let dateParser : DateFormatter = {
        let f = DateFormatter()

        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "GMT")
        f.dateFormat = "E, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    fileprivate static let dateAltParser : DateFormatter = {
        let f = DateFormatter()

        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "GMT")
        f.dateFormat = "E, dd MMM yyyy HH:mm:ss Z (zzz)"
        return f
    }()

    fileprivate static let dateDetector : NSDataDetector = {
        return try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }()

    static fileprivate func parseDate(_ content : String) -> Foundation.Date? {
        if let date = MIMEHeader.dateParser.date(from: content) {
            return date
        } else if let date = MIMEHeader.dateAltParser.date(from: content) {
            return date
        } else if let match = MIMEHeader.dateDetector.firstMatch(in: content, options: [], range: NSMakeRange(0, content.characters.count)) {
            return match.date
        }

        return nil
    }

    fileprivate var name : String {
        switch (self) {
        case .generic(name: let name, content: _):
            return name

        case .address(name: let name, address: _):
            return name

        case .newsgroup(name: let name, group: _):
            return name

        case .newsgroupRef(group: _, number: _):
            return "xref"

        case .messageId(name: let name, msgid: _):
            return name

        case .date(_):
            return "date"

        case .contentType(type: _, subtype: _, parameters: _):
            return "content-type"

        case .contentTransferEncoding(_):
            return "content-transfer-encoding"

        case .contentDisposition(disposition: _, parameters: _):
            return "content-disposition"
        }
    }

    public var dictionary : NSDictionary {
        switch (self) {
        case .generic(name: _, content: let string):
            return NSDictionary(dictionary: [ "type": "generic", "content": string ])

        case .address(name: _, address: let address):
            return NSDictionary(dictionary: [ "type": "address", "address": address.dictionary ])

        case .newsgroup(name: _, group: let group):
            return NSDictionary(dictionary: [ "type": "newsgroup", "group": group ])

        case .newsgroupRef(group: let group, number: let num):
            return NSDictionary(dictionary: [ "type": "newsgroupref", "group": group, "number": num ])

        case .messageId(name: _, msgid: let msgid):
            return NSDictionary(dictionary: [ "type": "messageid", "msgid": msgid ])

        case .date(let date):
            return NSDictionary(dictionary: [ "type": "date", "date": date ])

        case .contentType(type: let type, subtype: let subtype, parameters: let parameters):
            return NSDictionary(dictionary: [ "type": "content-type", "content-type": type, "content-subtype": subtype, "parameters": parameters])

        case .contentTransferEncoding(let enc):
            return NSDictionary(dictionary: [ "type": "content-transfer-encoding", "encoding": enc.description ])

        case .contentDisposition(disposition: let disposition, parameters: let parameters):
            return NSDictionary(dictionary: [ "type": "content-disposition", "disposition": disposition.description, "parameters": parameters])
        }
    }

    public init?(fromDictionary dictionary: NSDictionary, forHeader header: String) {
        switch dictionary["type"] as? String {
        case "generic"?:
            guard let content = dictionary["content"] as? String else {
                return nil
            }
            self = .generic(name: header, content: content)

        case "address"?:
            guard let address = dictionary["address"] as? NSDictionary,
                  let mimeAddress = MIMEAddress(fromDictionary: address) else {
                return nil
            }
            self = .address(name: header, address: mimeAddress)

        case "newsgroup"?:
            guard let group = dictionary["group"] as? String else {
                return nil
            }
            self = .newsgroup(name: header, group: group)

        case "newsgroupref"?:
            guard let group = dictionary["group"] as? String,
                  let number = dictionary["number"] as? Int else {
                return nil
            }
            self = .newsgroupRef(group: group, number: number)

        case "messageid"?:
            guard let msgid = dictionary["msgid"] as? String else {
                return nil
            }
            self = .messageId(name: header, msgid: msgid)

        case "date"?:
            guard let date = dictionary["date"] as? Foundation.Date else {
                return nil
            }
            self = .date(date)

        case "content-type"?:
            guard let type = dictionary["content-type"] as? String,
                  let subtype = dictionary["content-subtype"] as? String,
                  let parameters = dictionary["parameters"] as? [String: String] else {
                return nil
            }
            self = .contentType(type: type, subtype: subtype, parameters: parameters)

        case "content-transfer-encoding"?:
            guard let enc = dictionary["encoding"] as? String else {
                return nil
            }
            self = .contentTransferEncoding(MIMEEncoding(encoding: enc))

        case "content-disposition"?:
            guard let disposition = dictionary["disposition"] as? String,
                  let parameters = dictionary["parameters"] as? [String: String] else {
                return nil
            }
            self = .contentDisposition(disposition: MIMEDisposition(disposition: disposition), parameters: parameters)

        default:
            return nil
        }
    }

    static fileprivate var rfc2047Re = try!
        NSRegularExpression(pattern: "=\\?([^?]*)\\?([bq])\\?([^?]*)\\?=", options: NSRegularExpression.Options.caseInsensitive)

    static fileprivate func decodeRFC2047Chunk(_ chunk: String,
        withEncoding encoding: String,
        andCharset charset: String) throws -> String
    {

        let cfCharset = CFStringConvertIANACharSetNameToEncoding(charset as CFString!)
        if cfCharset == kCFStringEncodingInvalidId {
            throw Error.unsupportedCharset(charset: charset)
        }

        let charset = CFStringConvertEncodingToNSStringEncoding(cfCharset)

        switch (encoding) {
        case "b", "B":
            guard let data = Data(base64Encoded: chunk, options: []) else {
                print("bad base64")
                throw Error.headerEncodingError(value: chunk)
            }
            guard let decoded = String.fromData(data, encoding: charset) else {
                print("bad charset")
                throw Error.headerEncodingError(value: chunk)
            }

            return decoded as String

        case "q", "Q":
            guard let data = NSData(quotedPrintableString: chunk) else {
                throw Error.headerEncodingError(value: chunk)
            }
            guard let decoded = String.fromData(data as Data, encoding: charset) else {
                throw Error.headerEncodingError(value: chunk)
            }

            return decoded as String

        default:
            throw Error.unsupportedHeaderEncoding(encoding: encoding)
        }
    }

    static fileprivate func decodeRFC2047(_ headerLine: Data) throws -> String {
        guard var content = String.fromData(headerLine) else {
            throw Error.malformedHeaderContent(headerLine)
        }

        if !content.contains("=?") {
            return content
        }

        var matches = rfc2047Re.matches(in: content, options: [], range: NSMakeRange(0, content.characters.count))

        matches.sort { $0.range.location > $1.range.location }

        for match in matches {
            let charset = (content as NSString).substring(with: match.rangeAt(1))
            let encoding = (content as NSString).substring(with: match.rangeAt(2))
            let chunk = (content as NSString).substring(with: match.rangeAt(3))

            content = (content as NSString).replacingCharacters(in: match.range, with: try MIMEHeader.decodeRFC2047Chunk(chunk, withEncoding: encoding, andCharset: charset))
        }

        return content
    }

    static fileprivate func parseRfc1521Parameters(_ header: String) throws -> (String, [String: String]) {
        let cset = CharacterSet(charactersIn: " \t;")
        let scanner = Scanner(string: header)
        var payload : NSString?

        scanner.charactersToBeSkipped = nil
        _ = scanner.skipCharactersFromSet(CharacterSet.whitespaces)

        if !scanner.scanUpToCharacters(from: cset, into: &payload) {
            return (header, [:])
        }

        payload = payload?.trimmingCharacters(in: CharacterSet.whitespaces) as NSString?
        var parameters : [String: String] = [:]
        while scanner.skipString(";") {
            _ = scanner.skipCharactersFromSet(cset)

            var attrName : NSString?
            var attrValue : NSString?

            if !scanner.scanUpTo("=", into: &attrName)
            || !scanner.skipString("=")
            {
                throw Error.invalidRfc1521Parameter
            }

            if scanner.skipString("\"") {
                if !scanner.scanUpTo("\"", into: &attrValue)
                || !scanner.skipString("\"")
                {
                    throw Error.invalidRfc1521Parameter
                }
            } else if !scanner.scanUpToCharacters(from: cset, into: &attrValue) {
                attrValue = scanner.remainder as NSString
            } else {
                attrValue = attrValue?.trimmingCharacters(in: cset) as NSString?
            }

            parameters[(attrName! as String).lowercased()] = attrValue! as String
            _ = scanner.skipCharactersFromSet(CharacterSet.whitespaces)
        }

        if !scanner.isAtEnd {
            throw Error.invalidRfc1521Parameter
        }

        return (payload! as String, parameters)
    }

    static func appendHeader(_ headers : inout [MIMEHeader], name: Data, encodedContent : Data) throws {
        let cset = CharacterSet.whitespaces
        var content : String
        do {
            content = try MIMEHeader.decodeRFC2047(encodedContent)
        } catch let e {
            throw Error.malformedHeader(name: name, content: encodedContent, error: e)
        }

        guard let originalName = String.fromData(name) else {
            throw Error.malformedHeaderName(name)
        }

        if originalName.trimmingCharacters(in: cset) != originalName {
            throw Error.malformedHeaderName(name)
        }

        let lower = originalName.lowercased()

        switch lower {
        case "from":
            headers.append(.address(name: lower, address: MIMEAddress.parse(content)))

        case "cc", "to":
            for slice in content.characters.split(separator: ",") {
                let addr = String(slice).trimmingCharacters(in: cset)

                headers.append(.address(name: lower, address: MIMEAddress.parse(addr)))
            }

        case "newsgroups", "followup-to":
            for slice in content.characters.split(separator: ",") {
                let group = String(slice).trimmingCharacters(in: cset)

                headers.append(.newsgroup(name: lower, group: group))
            }

        case "message-id", "in-reply-to", "content-id":
            headers.append(.messageId(name: lower, msgid: content))

        case "references":
            let scanner = Scanner(string: content)

            scanner.charactersToBeSkipped = CharacterSet.whitespaces
            while !scanner.isAtEnd {
                var msgid : NSString?

                if !scanner.scanUpTo(">", into: &msgid)
                || !scanner.skipString(">")
                {
                    throw Error.malformedHeader(name: name, content: encodedContent, error: nil)
                }

                headers.append(.messageId(name: lower, msgid: (msgid! as String) + ">"))
            }

        case "date":
            guard let date = MIMEHeader.parseDate(content) else {
                throw Error.malformedDate(content)
            }

            headers.append(.date(date))

        case "content-type":
            do {
                let (payload, parameters) = try MIMEHeader.parseRfc1521Parameters(content)
                let parts = payload.characters.split(separator: "/")

                if parts.count != 2 {
                    throw Error.invalidRfc1521Parameter
                }

                headers.append(.contentType(type: String(parts[0]), subtype: String(parts[1]), parameters: parameters))
            } catch let e {
                throw Error.malformedHeader(name: name, content: encodedContent, error: e)
            }

        case "content-transfer-encoding":
            headers.append(.contentTransferEncoding(MIMEEncoding(encoding: content)))

        case "content-disposition":
            do {
                let (payload, parameters) = try MIMEHeader.parseRfc1521Parameters(content)

                headers.append(.contentDisposition(disposition: MIMEDisposition(disposition: payload), parameters: parameters))
            } catch let e {
                throw Error.malformedHeader(name: name, content: encodedContent, error: e)
            }

        case "xref":
            let slices = content.characters.split(separator: " ")

            for slice in slices[1..<slices.count] {
                let scanner = Scanner(string: String(slice))
                var group : NSString?
                var num : Int = 0

                if !scanner.scanUpTo(":", into: &group)
                || !scanner.skipString(":")
                || !scanner.scanInt(&num)
                || !scanner.isAtEnd
                {
                    throw Error.malformedHeader(name: name, content: encodedContent, error: nil)
                }

                headers.append(.newsgroupRef(group: group! as String, number: num))
            }
            break

        default:
            headers.append(.generic(name: lower, content: content))
        }
    }

    fileprivate enum ParseHeader : Swift.Error {
        case endOfHeaders(body: Data)
    }

    static func parse(_ data: Data) throws -> ([MIMEHeader], Data?) {
        let cset = CharacterSet.whitespaces
        var headers : [MIMEHeader] = []

        do {
            var currentHeader : Data?
            var currentValue : NSMutableData?

            try data.forEachChunk(separator: "\r\n") {
                (line, pos) in

                switch line {
                case _ where line.count == 0:
                    /* Reached end of headers */
                    let dataBytes = (data as NSData).bytes + pos
                    let remaining = data.count - pos

                    if let hdr = currentHeader, let value = currentValue {
                        try MIMEHeader.appendHeader(&headers, name: hdr, encodedContent: value as Data)
                    }

                    if remaining < 2 {
                        throw ParseHeader.endOfHeaders(body: line)
                    } else {
                        throw ParseHeader.endOfHeaders(body: NSData(bytes: dataBytes + 2, length: remaining - 2) as Data)
                    }

                case _ where cset.contains(UnicodeScalar(line.first!)):
                    var bytes = (line as NSData).bytes
                    var len = line.count


                    while len > 0 && cset.contains(UnicodeScalar(bytes.load(as: UInt8.self))) {
                        bytes = bytes + 1
                        len -= 1
                    }

                    if len == 0 {
                        throw Error.malformedHeader(name: currentHeader!, content: currentValue! as Data, error: nil)
                    }

                    var space : UInt8 = 0x20 /* space */
                    currentValue?.append(&space, length: 1)
                    currentValue?.append(bytes, length: len)


                default:
                    if let hdr = currentHeader, let value = currentValue {
                        try MIMEHeader.appendHeader(&headers, name: hdr, encodedContent: value as Data)
                        currentHeader = nil
                        currentValue = nil
                    }

                    do {
                        try line.forEachChunk(separator: ":") {
                            (data, pos) in

                            if currentHeader == nil {
                                currentHeader = NSData(data: data) as Data
                            } else {
                                var bytes = (line as NSData).bytes + pos
                                var len = line.count - pos

                                while len > 0 && cset.contains(UnicodeScalar(bytes.load(as: UInt8.self))) {
                                    bytes = bytes + 1
                                    len -= 1
                                }

                                if len == 0 {
                                    throw Error.malformedHeader(name: currentHeader!, content: data, error: nil)
                                }
                                
                                currentValue = NSMutableData(bytes: bytes, length: len)
                                throw ParseHeader.endOfHeaders(body: currentValue! as Data)
                            }
                        }
                    } catch ParseHeader.endOfHeaders(body: _) {
                    }
                }
            }
            if let hdr = currentHeader, let value = currentValue {
                try MIMEHeader.appendHeader(&headers, name: hdr, encodedContent: value as Data)
            }

            return (headers, nil)
        } catch ParseHeader.endOfHeaders(body: let body) {

            return (headers, body)
        }
    }

    static func parseHeaders(_ data: Data) throws -> [MIMEHeader] {
        let (headers, body) = try MIMEHeader.parse(data)

        if body != nil {
            throw Error.unexpectedHeaderEndMark
        }

        return headers
    }

    static func parseHeadersAndGetBody(_ data: Data) throws -> ([MIMEHeader], Data) {
        let (headers, optBody) = try MIMEHeader.parse(data)

        guard let body = optBody else {
            throw Error.missingHeaderEndMark
        }

        return (headers, body)
    }
}

public struct MIMEHeaders {
    fileprivate let headers : [String: [MIMEHeader]]

    fileprivate init(headers: [MIMEHeader]) {
        var map : [String: [MIMEHeader]] = [:]

        for hdr in headers {
            let name = hdr.name.lowercased()

            if map[name] == nil {
                map[name] = [hdr]
            } else {
                map[name]?.append(hdr)
            }
        }

        self.headers = map
    }

    public subscript(name: String) -> [MIMEHeader]? {
        return self.headers[name.lowercased()]
    }

    public var contentType : (type: String, subtype: String, parameters: [String:String]) {
        if case .contentType(type: let type, subtype: let subtype, parameters: let parameters)? = self["content-type"]?.first {
            return (type: type, subtype: subtype, parameters: parameters)
        } else {
            return (type: "text", subtype: "plain", parameters: [:])
        }
    }

    public var contentTransferEncoding : MIMEEncoding {
        if case .contentTransferEncoding(let e)? = self["content-transfer-encoding"]?.first {
            return e
        } else {
            return .bit7
        }
    }

    public var contentCharset : String {
        if let charset = self.contentType.parameters["charset"] {
            return charset
        } else {
            return "us-ascii"
        }
    }

    static public func parse(_ data: Data) throws -> MIMEHeaders {
        let headers = try MIMEHeader.parseHeaders(data)

        return MIMEHeaders(headers: headers)
    }

    public var dictionary : NSDictionary {
        let dict = NSMutableDictionary()

        for (name, values) in self.headers {
            let array = NSMutableArray()

            for header in values {
                array.add(header.dictionary)
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

open class MIMEPart : NSObject {
    open let headers : MIMEHeaders

    fileprivate init(headers: MIMEHeaders) {
        self.headers = headers
    }

    open func getBodyAsPlainText() -> String {
        assert (false)
    }

    static open func parse(_ data: Data) throws -> MIMEPart {
        var (hdrs, body) = try MIMEHeader.parseHeadersAndGetBody(data)
        let headers = MIMEHeaders(headers: hdrs)

        switch headers.contentTransferEncoding {
        case .bit7, .bit8, .binary, .unsupported(_):
            break

        case .quotedPrintable:
            guard let decodedData = NSData(quotedPrintableData: body) else {
                throw Error.bodyEncodingError(encoding: .quotedPrintable, body: body)
            }

            body = decodedData as Data

        case .base64:
            guard let decodedData = Data(base64Encoded: body, options: [ .ignoreUnknownCharacters ]) else {
                throw Error.bodyEncodingError(encoding: .base64, body: body)
            }

            body = decodedData
        }

        if let mimeClass = MIMEPart.registry[headers.contentType.type] {
            return try mimeClass.parsePart(headers, body: body)
        } else {
            return try MIMEDataPart.parsePart(headers, body: body)
        }
    }

    open class func parsePart(_ headers: MIMEHeaders, body: Data) throws -> MIMEPart {
        assert (false)
    }
}

extension MIMEPart {
    static fileprivate var registry = [String: MIMEPart.Type]()

    public class func handleType(_ type: String) {
        MIMEPart.registry[type] = self
    }
}

private class MIMETextPart : MIMEPart {
    fileprivate let body : String

    fileprivate init(headers: MIMEHeaders, body: String) {
        self.body = body
        super.init(headers: headers)
    }

    override func getBodyAsPlainText() -> String {
        return self.body
    }

    override class func parsePart(_ headers: MIMEHeaders, body: Data) throws -> MIMEPart {
        let strCharset = headers.contentCharset
        let cfCharset = CFStringConvertIANACharSetNameToEncoding(strCharset as CFString!)

        if cfCharset == kCFStringEncodingInvalidId {
            throw Error.unsupportedCharset(charset: strCharset)
        }

        let charset = CFStringConvertEncodingToNSStringEncoding(cfCharset)
        guard let strBody = String.fromData(body, encoding: charset) else {
            throw Error.bodyCharsetError(charset: strCharset, body: body)
        }

        return MIMETextPart(headers: headers, body: strBody)
    }

    override class func initialize() {
        self.handleType("text")
        self.handleType("message")
    }
}

/** Multipart MIME Type as described in RFC 2046.
 */
private class MIMEMultiPart : MIMEPart {
    fileprivate let parts : [MIMEPart]

    fileprivate init(headers: MIMEHeaders, parts: [MIMEPart]) {
        self.parts = parts
        super.init(headers: headers)
    }

    override class func parsePart(_ headers: MIMEHeaders, body: Data) throws -> MIMEPart {
        return MIMEDataPart(headers: headers, body: body)
    }

    override class func initialize() {
        self.handleType("multipart")
    }
}

private class MIMEDataPart : MIMEPart {
    fileprivate let body : Data

    fileprivate init(headers: MIMEHeaders, body: Data) {
        self.body = body
        super.init(headers: headers)
    }

    override func getBodyAsPlainText() -> String {
        return String.fromData(body)!
    }

    override class func parsePart(_ headers: MIMEHeaders, body: Data) throws -> MIMEPart {
        return MIMEDataPart(headers: headers, body: body)
    }

    override class func initialize() {
        self.handleType("audio")
        self.handleType("video")
        self.handleType("image")
    }
}
