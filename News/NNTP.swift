//
//  NNTP.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Lib

public enum NNTPCapability : Hashable {
    /* RFC 3977: NNTP Version 2 */
    case modeReader
    case reader
    case ihave
    case post
    case newNews
    case hdr
    case over
    case listActiveTimes
    case listDistribPats

    /* RFC 4642: STARTTLS */
    case startTls

    /* RFC 4643: NNTP Authentication */
    case authinfoUser
    case authinfoSASL

    /* SASL mechanism:
    * http://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xml
    */
    case saslPlain
    case saslLogin
    case saslCramMd5
    case saslNtml
    case saslDigestMd5

    /* RFC 4644: NNTP Streaming extension */
    case streaming

    /* Special capabilities */
    case version(Int)
    case implementation(String)

    public var hashValue : Int {
        switch (self) {
        case .modeReader:
            return 0
        case .reader:
            return 1
        case .ihave:
            return 2
        case .post:
            return 3
        case .newNews:
            return 4
        case .hdr:
            return 5
        case .over:
            return 6
        case .listActiveTimes:
            return 7
        case .listDistribPats:
            return 8
        case .startTls:
            return 9
        case .authinfoUser:
            return 10
        case .authinfoSASL:
            return 11
        case .saslPlain:
            return 12
        case .saslLogin:
            return 13
        case .saslCramMd5:
            return 14
        case .saslNtml:
            return 15
        case .saslDigestMd5:
            return 16
        case .streaming:
            return 17
        case .version(_):
            return 18
        case .implementation(_):
            return 19
        }
    }
}

public func ==(lhs: NNTPCapability, rhs: NNTPCapability) -> Bool {
    return lhs.hashValue == rhs.hashValue
}


public enum NNTPResponseStatus : Character {
    case information = "1"
    case completed = "2"
    case `continue` = "3"
    case failure = "4"
    case protocolError = "5"
}

public enum NNTPResponseContext : Character {
    case status = "0"
    case newsgroupSelection = "1"
    case articleSelection = "2"
    case distribution = "3"
    case posting = "4"
    case authentication = "8"
    case `extension` = "9"
}

public struct NNTPResponse : CustomStringConvertible {
    public let status : NNTPResponseStatus
    public let context : NNTPResponseContext
    public let code : Character
    public let message : String

    public var description : String {
        return "\(self.status.rawValue)\(self.context.rawValue)\(self.code) \(self.message)"
    }
}

public enum NNTPError : Swift.Error, CustomStringConvertible {
    case notConnected
    case noCommandProvided
    case cannotConnect
    case aborted

    case clientProtocolError(NNTPResponse)
    case unsupportedError(NNTPResponse)
    case serverProtocolError
    case unexpectedResponse(NNTPResponse)
    case malformedResponse(NNTPResponse)
    case malformedOverviewLine(Data)

    case serviceTemporarilyUnvailable /* Error 400 */
    case noSuchNewsgroup(group: String?) /* Error 411 */
    case noNewsgroupSelected /* Error 412 */
    case currentArticleNumberIsInvalid /* Error 420 */
    case noNextArticleInGroup /* Error 421 */
    case noPreviousArticleInGroup /* Error 422 */
    case noArticleWithThatNumber /* Error 423 */
    case noArticleWithThatMsgId /* Error 430 */
    case articleNotWanted /* Error 435 */
    case transferTemporaryFailure /* Error 436 */
    case transferPermanentFailure /* Error 437 */
    case postingNotPermitted(reason: String) /* Error 440 */
    case postingFailed(reason: String) /* Error 441 */
    case authenticationFailed(reason: String) /* Error 481 */
    case authenticationSequenceError /* Error 482 */

    case servicePermanentlyUnavailable /* Error 502 */

    public var description : String {
        switch self {
        case .notConnected:
            return "not connected"

        case .noCommandProvided:
            return "no command provided"

        case .cannotConnect:
            return "cannot connect to server"

        case .aborted:
            return "operation aborted"

        case .clientProtocolError(let response):
            return "client protocol error: \(response)"

        case .unsupportedError(let response):
            return "unsupported error: \(response)"

        case .serverProtocolError:
            return "server error"

        case .unexpectedResponse(let response):
            return "unexpected server response: \(response)"

        case .malformedResponse(let response):
            return "malformed server response: \(response)"

        case .malformedOverviewLine(let line):
            return "malformed message overview: \(String.fromData(line))"

        case .serviceTemporarilyUnvailable:
            return "service temporarily unavailable (retry later)"

        case .noSuchNewsgroup(group: let group):
            return "unknown newsgroup: \(group)"

        case .noNewsgroupSelected:
            return "no newsgroup selected"

        case .currentArticleNumberIsInvalid:
            return "current article number is invalid"

        case .noNextArticleInGroup:
            return "no next article in group"

        case .noPreviousArticleInGroup:
            return "no previous article in group"

        case .noArticleWithThatNumber:
            return "no article with the given number"

        case .noArticleWithThatMsgId:
            return "no article with the given message id"

        case .articleNotWanted:
            return "article not wanted"

        case .transferTemporaryFailure:
            return "transfer temporary failure"

        case .transferPermanentFailure:
            return "transfer permanent failure"

        case .postingNotPermitted:
            return "posting not permitted"

        case .postingFailed:
            return "posting failed"

        case .authenticationFailed:
            return "authentication failed"

        case .authenticationSequenceError:
            return "authentication sequence error"

        case .servicePermanentlyUnavailable:
            return "service permanently unavailable"
        }
    }
}

private struct Global {
    static fileprivate let dateFormatter : DateFormatter = {
        let f = DateFormatter()

        f.dateFormat = "yyyyMMdd HHmmss"
        f.timeZone = TimeZone(abbreviation: "GMT")!
        return f
    }()

    static fileprivate let dateParser : DateFormatter = {
        let f = DateFormatter()

        f.dateFormat = "yyyyMMddHHmmss"
        f.timeZone = TimeZone(abbreviation: "GMT")!
        return f
    }()

    static fileprivate let spaceCset = CharacterSet(charactersIn: " ")
}

private func packDate(_ date: Date, inBuffer buffer: Buffer) {
    buffer.appendString(Global.dateFormatter.string(from: date))
    buffer.appendString(" GMT")
}

public struct NNTPOverview {
    public let num : Int
    public let headers : MIMEHeaders

    public let bytes : Int?
    public let lines : Int?

    public init(num: Int, headers: MIMEHeaders, bytes: Int?, lines: Int?) {
        self.num = num
        self.headers = headers
        self.bytes = bytes
        self.lines = lines
    }
}

public enum NNTPPayload {
    case information(String)
    case capabilities(Set<NNTPCapability>)
    case passwordRequired
    case authenticationAccepted
    case messageIds([String])
    case groupContent(group: String, count: Int, lowestNumber: Int, highestNumber: Int, numbers: [Int]?)
    case articleFound(Int, String)
    case article(Int, String, MIMEPart)
    case headers(Int, String, MIMEHeaders)
    case body(Int, String, String)
    case groupList([(String, String)])
    case date(Foundation.Date)
    case overview([NNTPOverview])
    case sendArticle
}

public enum NNTPCommand : CustomStringConvertible {
    public enum ListHeadersVariant : String {
        case MSGID
        case RANGE
    }

    public enum ArticleRange {
        case number(Int)
        case from(Int)
        case inRange(NSRange)

        func pack(_ buffer: Buffer) {
            switch (self) {
            case .number(let num):
                buffer.appendString("\(num)")

            case .from(let from):
                buffer.appendString("\(from)-")

            case .inRange(let range):
                buffer.appendString("\(range.location)-\(NSMaxRange(range) - 1)")
            }
        }
    }

    public struct Wildmat {
        let pattern : String
        
        func pack(_ buffer: Buffer) {
            buffer.appendString(self.pattern)
        }
    }


    case connect

    /* RFC 3977: NNTP Version 2 */
    case capabilities(String?)
    case modeReader
    case quit

    /* Group and article selection */
    case group(group: String)
    case listGroup(group: String, range: ArticleRange?)
    case last(group: String)
    case next(group: String)

    /* Article retrieval */
    case articleByMsgid(msgid: String)
    case article(group: String, article: Int?)
    case headByMsgid(msgid: String)
    case head(group: String, article: Int?)
    case bodyByMsgid(msgid: String)
    case body(group: String, article: Int?)
    case statByMsgid(msgid: String)
    case stat(group: String, article: Int?)

    /* Posting */
    case post
    case postBody(String)
    case ihave(String)

    /* Information */
    case date
    case help
    case newGroups(Foundation.Date)
    case newNews(Wildmat, Foundation.Date)

    /* List */
    case listActive(Wildmat?)
    case listActiveTimes(Wildmat?)
    case listDistribPats
    case listNewsgroups(Wildmat?)

    /* Article field access */
    case overByMsgid(msgid: String)
    case over(group: String, range: ArticleRange?)
    case listOverviewFmt
    case hdrByMsgid(field: String, msgid: String)
    case hdr(group: String, field: String, range: ArticleRange?)
    case listHeaders(ListHeadersVariant?)

    /* RFC 4643: NNTP Authentication */
    case authinfoUser(String)
    case authinfoPass(String)
    case authinfoSASL

    fileprivate func pack(_ buffer: Buffer, forDisplay: Bool) {
        switch (self) {
        case .connect:
            return

        case .capabilities(let optKeyword):
            buffer.appendString("CAPABILITIES")
            if let keyword = optKeyword {
                buffer.appendString(" \(keyword)")
            }

        case .modeReader:
            buffer.appendString("MODE READER")

        case .quit:
            buffer.appendString("QUIT")

        case .group(group: let group):
            buffer.appendString("GROUP \(group)")

        case .listGroup(group: let group, range: let optRange):
            buffer.appendString("LISTGROUP")
            buffer.appendString(" \(group)")

            if let range = optRange {
                buffer.appendString(" ")
                range.pack(buffer)
            }

        case .last(group: _):
            buffer.appendString("LAST")

        case .next(group: _):
            buffer.appendString("NEXT")

        case .articleByMsgid(msgid: let msgid):
            buffer.appendString("ARTICLE \(msgid)")

        case .article(group: _, article: let optArticle):
            buffer.appendString("ARTICLE")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .headByMsgid(msgid: let msgid):
            buffer.appendString("HEAD \(msgid)")

        case .head(group: _, article: let optArticle):
            buffer.appendString("HEAD")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .bodyByMsgid(msgid: let msgid):
            buffer.appendString("BODY \(msgid)")

        case .body(group: _, article: let optArticle):
            buffer.appendString("BODY")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .statByMsgid(msgid: let msgid):
            buffer.appendString("STAT \(msgid)")

        case .stat(group: _, article: let optArticle):
            buffer.appendString("STAT")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .post:
            buffer.appendString("POST")

        case .postBody(let body):
            buffer.appendString(body)
            if forDisplay {
                buffer.appendString("\r\n.")
            } else {
                buffer.appendString("\r\n.\r\n")
            }

        case .ihave(let msgid):
            buffer.appendString("IHAVE \(msgid)")

        case .date:
            buffer.appendString("DATE")

        case .help:
            buffer.appendString("HELP")

        case .newGroups(let date):
            buffer.appendString("NEWGROUPS ")
            packDate(date, inBuffer: buffer)

        case .newNews(let wildmat, let date):
            buffer.appendString("NEWNEWS ")
            wildmat.pack(buffer)
            buffer.appendString(" ")
            packDate(date, inBuffer: buffer)

        case .listActive(let optWildmat):
            buffer.appendString("LIST ACTIVE")

            if let wildmat = optWildmat {
                buffer.appendString(" ")
                wildmat.pack(buffer)
            }

        case .listActiveTimes(let optWildmat):
            buffer.appendString("LIST ACTIVE.TIMES")

            if let wildmat = optWildmat {
                buffer.appendString(" ")
                wildmat.pack(buffer)
            }

        case .listDistribPats:
            buffer.appendString("LIST DISTRIB.PATS")

        case .listNewsgroups(let optWildmat):
            buffer.appendString("LIST NEWSGROUPS")

            if let wildmat = optWildmat {
                buffer.appendString(" ")
                wildmat.pack(buffer)
            }

        case .overByMsgid(msgid: let msgid):
            buffer.appendString("OVER \(msgid)")

        case .over(group: _, range: let optArticle):
            buffer.appendString("OVER")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .listOverviewFmt:
            buffer.appendString("LIST OVERVIEW.FMT")

        case .hdrByMsgid(field: let field, msgid: let msgid):
            buffer.appendString("HDR \(field) \(msgid)")

        case .hdr(group: _, field: let field, range: let optArticle):
            buffer.appendString("HDR \(field)")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .listHeaders(let optVariant):
            buffer.appendString("LIST HEADERS")

            if let variant = optVariant {
                buffer.appendString(" \(variant.rawValue)")
            }

        case .authinfoUser(let login):
            buffer.appendString("AUTHINFO USER \(login)")

        case .authinfoPass(let password):
            if forDisplay {
                buffer.appendString("AUTHINFO PASS ****")
            } else {
                buffer.appendString("AUTHINFO PASS \(password)")
            }

        case .authinfoSASL:
            assert (false)
            return
        }

        if !forDisplay {
            buffer.appendString("\r\n")
        }
    }

    fileprivate func pack(_ buffer: Buffer) {
        return pack(buffer, forDisplay: false)
    }

    public var description : String {
        let buffer = Buffer(capacity: 1024)
        var out : NSString?

        self.pack(buffer, forDisplay: true)
        buffer.read() {
            (buffer, length) in

            out = NSString(bytes: buffer, length: length, encoding: String.Encoding.utf8.rawValue)
            return length
        }

        return out! as String
    }

    fileprivate var isMultiline : Bool {
        switch self {
        case .connect, .modeReader, .quit, .group(_), .last, .next, .post, .postBody(_), .ihave(_),
        .date, .authinfoUser(_), .authinfoPass(_), .authinfoSASL:
            return false
        default:
            return true
        }
    }

    fileprivate var allowPipelining : Bool {
        switch self {
        case .connect, .modeReader, .post, .postBody(_), .ihave(_), .authinfoUser(_), .authinfoPass(_), .authinfoSASL:
            return false

        default:
            return true
        }
    }

    fileprivate var fatalOnError : Bool {
        switch self {
        case .connect, .modeReader, .authinfoUser(_), .authinfoPass(_), .authinfoSASL:
            return true

        default:
            return false
        }
    }

    fileprivate var group : String? {
        switch self {
        case .last(group: let x):
            return x

        case .next(group: let x):
            return x

        case .article(group: let x, _):
            return x

        case .head(group: let x, _):
            return x

        case .body(group: let x, _):
            return x

        case .stat(group: let x, _):
            return x

        case .over(group: let x, range: _):
            return x

        default:
            return nil
        }
    }
}

private class NNTPOperation {
    fileprivate let command : NNTPCommand
    fileprivate let onSuccess : (NNTPPayload) -> Void
    fileprivate let onError : (Swift.Error) -> Void
    fileprivate let isCancelled : (Void) -> Bool

    fileprivate var response : NNTPResponse?
    fileprivate var payload : Data?

    fileprivate init(command: NNTPCommand, onSuccess: @escaping (NNTPPayload) -> Void, onError: @escaping (Swift.Error) -> Void, isCancelled: @escaping (Void) -> Bool) {
        self.command = command
        self.onSuccess = onSuccess
        self.onError = onError
        self.isCancelled = isCancelled
    }

    fileprivate func acceptResponse(_ response: NNTPResponse) -> Bool {
        switch (self.command, response.status.rawValue, response.context.rawValue, response.code) {
        case (.connect, "2", "0", "0"), (.connect, "2", "0", "1"),
        (.capabilities, "1", "0", "1"),
        (.modeReader, "2", "0", "0"), (.modeReader, "2", "0", "1"),
        (.quit, "2", "0", "5"),
        (.group, "2", "1", "1"),
        (.listGroup, "2", "1", "1"),
        (.last, "2", "2", "3"),
        (.next, "2", "2", "3"),
        (.articleByMsgid, "2", "2", "0"),
        (.article, "2", "2", "0"),
        (.headByMsgid, "2", "2", "1"),
        (.head, "2", "2", "1"),
        (.bodyByMsgid, "2", "2", "2"),
        (.body, "2", "2", "2"),
        (.statByMsgid, "2", "2", "3"),
        (.stat, "2", "2", "3"),
        (.post, "3", "4", "0"),
        (.postBody, "2", "4", "0"),
        (.ihave, "3", "3", "5"), (.ihave, "2", "3", "5"),
        (.date, "1", "1", "1"),
        (.help, "1", "0", "0"),
        (.newGroups, "2", "3", "1"),
        (.newNews, "2", "3", "0"),
        (.listActive, "2", "1", "5"),
        (.listActiveTimes, "2", "1", "5"),
        (.listDistribPats, "2", "1", "5"),
        (.listNewsgroups, "2", "1", "5"),
        (.overByMsgid, "2", "2", "4"),
        (.over, "2", "2", "4"),
        (.listOverviewFmt, "2", "1", "5"),
        (.hdrByMsgid, "2", "2", "5"),
        (.hdr, "2", "2", "5"),
        (.listHeaders, "2", "1", "5"),
        (.authinfoUser, "2", "8", "1"), (.authinfoUser, "3", "8", "1"),
        (.authinfoPass, "2", "8", "1"),
        (_, "4", _, _), (_, "5", _, _):
            return true

        default:
            return false
        }
    }

    fileprivate func payloadForEachLine(action: @escaping (Data) throws -> ()) rethrows {
        try self.payload!.forEachChunk(separator: "\r\n") {
            (line, _) in try action(line)
        }
    }

    fileprivate func parseCapabilities() -> Set<NNTPCapability> {
        var set = Set<NNTPCapability>()
        self.payloadForEachLine {
            (line) in

            switch (line) {
            case "HDR":
                set.insert(.hdr)

            case "IHAVE":
                set.insert(.ihave)

            case "NEWNEWS":
                set.insert(.newNews)

            case "POST":
                set.insert(.post)

            case "MODE-READER":
                set.insert(.modeReader)

            case "READER":
                set.insert(.reader)

            case "OVER":
                set.insert(.over)

            case "STREAMING":
                set.insert(.streaming)

            default:
                guard let strLine = String.fromData(line) else {
                    return
                }

                let cset = CharacterSet(charactersIn: " ")
                let scanner = Scanner(string: strLine)
                var keyword : NSString?

                scanner.charactersToBeSkipped = nil
                if !scanner.scanUpToCharacters(from: cset, into: &keyword) {
                    return
                }
                switch (keyword!) {
                case "LIST":
                    list_cap: while !scanner.skipCharactersFromSet(cset) {
                        var cap : NSString?

                        if !scanner.scanUpToCharacters(from: cset, into: &cap) {
                            return
                        }

                        switch (cap!) {
                        case "ACTIVE.TIMES":
                            set.insert(.listActiveTimes)

                        case "DISTRIB.PATS":
                            set.insert(.listDistribPats)

                        default:
                            continue list_cap
                        }
                    }
                    break

                case "IMPLEMENTATION":
                    _ = scanner.skipCharactersFromSet(cset)
                    set.insert(.implementation(scanner.remainder))
                    break

                case "VERSION":
                    var version : Int = 0

                    if !scanner.skipCharactersFromSet(cset) {
                        return
                    }
                    if !scanner.scanInt(&version) {
                        return
                    }
                    set.insert(.version(Int(version)))
                    
                default:
                    break
                }
                break
            }
        }
        
        return set
    }

    fileprivate func parseArticleFound(_ response: NNTPResponse) throws -> (Int, String) {
        let scanner = Scanner(string: response.message)
        var number : Int = 0

        scanner.charactersToBeSkipped = nil
        if !scanner.scanInt(&number)
            || !scanner.skipCharactersFromSet(Global.spaceCset)
        {
            throw NNTPError.malformedResponse(response)
        }

        return (Int(number), scanner.remainder)
    }

    fileprivate func parsePayload() throws -> NNTPPayload {
        guard let response = self.response else {
            throw NNTPError.serverProtocolError
        }

        if !self.acceptResponse(response) {
            throw NNTPError.unexpectedResponse(response)
        }

        switch ((response.status.rawValue, response.context.rawValue, response.code)) {
        case ("2", "0", "0"), ("2", "0", "1"), ("2", "0", "5"):
            return NNTPPayload.information(response.message)

        case ("1", "0", "1"):
            return .capabilities(self.parseCapabilities())

        case ("1", "1", "1"):
            guard let date = Global.dateParser.date(from: response.message) else {
                throw NNTPError.unexpectedResponse(response)
            }

            return .date(date)

        case ("2", "8", "1"):
            return .authenticationAccepted

        case ("3", "8", "1"):
            return .passwordRequired

        case ("2", "3", "0"):
            var msgids : [String] = []

            self.payloadForEachLine {
                if let line = String.fromData($0) {
                    msgids.append(line)
                }
            }

            return .messageIds(msgids)

        case ("2", "1", "1"):
            let scanner = Scanner(string: response.message)
            var count : Int = 0
            var low : Int = 0
            var high : Int = 0
            var ids : [Int]?

            scanner.charactersToBeSkipped = nil
            if !scanner.scanInt(&count)
                || !scanner.skipCharactersFromSet(Global.spaceCset)
                || !scanner.scanInt(&low)
                || !scanner.skipCharactersFromSet(Global.spaceCset)
                || !scanner.scanInt(&high)
                || !scanner.skipCharactersFromSet(Global.spaceCset)
            {
                throw NNTPError.malformedResponse(response)
            }


            if self.payload != nil {
                ids = []

                try self.payloadForEachLine {
                    (line) in

                    guard let id = String.fromData(line) else {
                        throw NNTPError.malformedResponse(response)
                    }

                    guard let numId = Int(id) else {
                        throw NNTPError.malformedResponse(response)
                    }

                    ids?.append(numId)
                }
            }

            return .groupContent(group: scanner.remainder, count: Int(count),
                lowestNumber: Int(low), highestNumber: Int(high), numbers: ids)

        case ("2", "2", "0"):
            let (number, msgid) = try self.parseArticleFound(response)
            let msg = try MIMEPart.parse(payload!)

            return .article(number, msgid, msg)

        case ("2", "2", "1"):
            let (number, msgid) = try self.parseArticleFound(response)
            let headers = try MIMEHeaders.parse(payload!)

            return .headers(number, msgid, headers)

        case ("2", "2", "2"):
            let (number, msgid) = try self.parseArticleFound(response)
            guard let body = String.fromData(payload!) else {
                throw NNTPError.serverProtocolError
            }

            return .body(number, msgid, body)

        case ("2", "2", "3"):
            let (number, msgid) = try self.parseArticleFound(response)

            return .articleFound(number, msgid)

        case ("2", "2", "4"):
            var overviews : [NNTPOverview] = []

            try self.payloadForEachLine {
                (data) in

                var pos = 0
                var num : Int?
                var bytes : Int?
                var lines : Int?

                guard let headers = NSMutableData(capacity: data.count + 60) else {
                    throw NNTPError.serverProtocolError
                }

                try data.forEachChunk(separator: "\t") {
                    (chunk, _) in

                    switch (pos) {
                    case 0:
                        num = chunk.intValue
                        if num == nil {
                            throw NNTPError.malformedOverviewLine(data)
                        }

                    case 1...5:
                        if chunk.count != 0 {
                            let chunkHeader = [ "Subject: ", "From: ", "Date: ", "Message-ID: ", "References: "]
                            headers.appendString(chunkHeader[pos - 1])
                            headers.append(chunk)
                            headers.appendString("\r\n")
                        }

                    case 6:
                        if chunk.count != 0 {
                            bytes = chunk.intValue
                            if bytes == nil {
                                throw NNTPError.malformedOverviewLine(data)
                            }
                        }

                    case 7:
                        if chunk.count != 0 {
                            lines = chunk.intValue
                            if lines == nil {
                                throw NNTPError.malformedOverviewLine(data)
                            }
                        }

                    default:
                        headers.append(chunk)
                        headers.appendString("\r\n")
                    }
                    pos += 1
                }

                let overview = NNTPOverview(num: num!, headers: try MIMEHeaders.parse(headers as Data), bytes: bytes, lines: lines)
                overviews.append(overview)
            }
            return .overview(overviews)

        case ("2", "1", "5"):
            switch (self.command) {
            case .listNewsgroups(_):
                var res : [(String, String)] = []
                let cset = CharacterSet(charactersIn: " \t")

                try self.payloadForEachLine {
                    guard let line = String.fromData($0) else {
                        throw NNTPError.serverProtocolError
                    }

                    let scanner = Scanner(string: line)
                    var group : NSString?

                    scanner.charactersToBeSkipped = nil
                    if !scanner.scanUpToCharacters(from: cset, into: &group)
                        || !scanner.skipCharactersFromSet(cset)
                    {
                        throw NNTPError.malformedResponse(response)
                    }
                    
                    res.append((group! as String), scanner.remainder)
                }
                return .groupList(res)

            default:
                throw NNTPError.serverProtocolError
            }

        case ("3", "4", "0"):
            return .sendArticle

        case ("4", "0", "0"):
            throw NNTPError.serviceTemporarilyUnvailable

        case ("4", "1", "1"):
            throw NNTPError.noSuchNewsgroup(group: command.group)

        case ("4", "1", "2"):
            throw NNTPError.noNewsgroupSelected

        case ("4", "2", "0"):
            throw NNTPError.currentArticleNumberIsInvalid

        case ("4", "2", "1"):
            throw NNTPError.noNextArticleInGroup

        case ("4", "2", "2"):
            throw NNTPError.noPreviousArticleInGroup

        case ("4", "2", "3"):
            throw NNTPError.noArticleWithThatNumber

        case ("4", "3", "0"):
            throw NNTPError.noArticleWithThatMsgId

        case ("4", "3", "5"):
            throw NNTPError.articleNotWanted

        case ("4", "3", "6"):
            throw NNTPError.transferTemporaryFailure

        case ("4", "3", "7"):
            throw NNTPError.transferPermanentFailure

        case ("4", "4", "0"):
            throw NNTPError.postingNotPermitted(reason: response.message)

        case ("4", "4", "1"):
            throw NNTPError.postingFailed(reason: response.message)

        case ("4", "8", "1"):
            throw NNTPError.authenticationFailed(reason: response.message)

        case ("4", "8", "2"):
            throw NNTPError.authenticationSequenceError

        case ("4", _, _):
            throw NNTPError.unsupportedError(response)

        case ("5", "0", "2"):
            throw NNTPError.servicePermanentlyUnavailable

        case ("5", _, _):
            throw NNTPError.clientProtocolError(response)

        default:
            throw NNTPError.serverProtocolError
        }
    }

    fileprivate func parseResponse(_ line: String) throws -> NNTPResponse {
        let chars = line.characters
        var status : NNTPResponseStatus?
        var context : NNTPResponseContext?
        var pos = 0

        if chars.count < 5 {
            throw NNTPError.serverProtocolError
        }

        for char in chars {
            switch (pos) {
            case 0:
                status = NNTPResponseStatus(rawValue: char)
                if status == nil {
                    throw NNTPError.serverProtocolError
                }
            case 1:
                context = NNTPResponseContext(rawValue: char)
                if context == nil {
                    throw NNTPError.serverProtocolError
                }
            case 2:
                if char < "0" || char > "9" {
                    throw NNTPError.serverProtocolError
                }
                return NNTPResponse(status: status!, context: context!, code: char,
                    message: (line as NSString).substring(from: 4))

            default:
                throw NNTPError.serverProtocolError
            }
            pos += 1
        }
        
        throw NNTPError.serverProtocolError
    }

    fileprivate func readFrom(_ reader: BufferedReader) throws -> Bool {
        if self.response == nil {
            guard let data = try reader.readDataUpTo("\r\n", keepBound: false, endOfStreamIsBound: true) else {
                return false
            }

            guard let str = String.fromData(data) else {
                throw NNTPError.serverProtocolError
            }
            //print(">>> \(str)")

            self.response = try self.parseResponse(str)
            if self.response!.status != .completed {
                return true
            }
        }

        if self.command.isMultiline {
            guard let payload = try reader.readDataUpTo("\r\n.\r\n", keepBound: false, endOfStreamIsBound: false) else {
                return false
            }

            //print(">>> \(String.fromData(payload))")

            self.payload = payload
        }

        return true
    }

    fileprivate func fail(_ error: Swift.Error) {
        self.onError(error)
    }

    fileprivate func process() {
        do {
            self.onSuccess(try self.parsePayload())
        } catch let e {
            self.onError(e)
        }
    }
}

/// Manage a single connection to a NNTP server.
private class NNTPConnection {
    fileprivate let istream : InputStream
    fileprivate let ostream : OutputStream
    fileprivate let reader : BufferedReader
    fileprivate let pendingCommands = FifoQueue<NNTPOperation>()
    fileprivate let sentCommands = FifoQueue<NNTPOperation>()
    fileprivate let outBuffer = Buffer(capacity: 2 << 20)

    fileprivate init?(host: String, port: Int, ssl: Bool) {
        var istream : InputStream?
        var ostream : OutputStream?

        Stream.getStreamsToHost(withName: host, port: port,
            inputStream: &istream, outputStream: &ostream)

        guard let ins = istream, let ous = ostream else {
            return nil
        }
        guard !ssl || ins.setProperty(kCFStreamSocketSecurityLevelNegotiatedSSL, forKey: Stream.PropertyKey.socketSecurityLevelKey) else {
            return nil
        }
        self.istream = ins
        self.ostream = ous
        self.reader = BufferedReader(fromStream: ins)
    }

    fileprivate var delegate : StreamDelegate? {
        set {
            self.istream.delegate = newValue
            self.ostream.delegate = newValue
        }

        get {
            return self.istream.delegate
        }
    }

    fileprivate func open() {
        self.istream.open()
        self.ostream.open()
    }

    fileprivate func close() {
        while let reply = self.sentCommands.pop() {
            reply.fail(NNTPError.aborted)
        }

        while let reply = self.pendingCommands.pop() {
            reply.fail(NNTPError.aborted)
        }

        self.istream.close()
        self.ostream.close()
    }
    
    fileprivate func scheduleInRunLoop(_ runLoop: RunLoop, forMode mode: String) {
        self.istream.schedule(in: runLoop, forMode: RunLoopMode(rawValue: mode))
        self.ostream.schedule(in: runLoop, forMode: RunLoopMode(rawValue: mode))
    }

    fileprivate func removeFromRunLoop(_ runLoop: RunLoop, forMode mode: String) {
        self.istream.remove(from: runLoop, forMode: RunLoopMode(rawValue: mode))
        self.ostream.remove(from: runLoop, forMode: RunLoopMode(rawValue: mode))
    }

    fileprivate func read() throws {
        try self.reader.fillBuffer()

        while self.reader.hasBytesAvailable {
            guard let reply = self.sentCommands.head else {
                return
            }

            do {
                if !(try reply.readFrom(self.reader)) {
                    return
                }
                _ = self.sentCommands.pop()
                reply.process()
            } catch let e {
                _ = self.sentCommands.pop()
                reply.fail(e)
                self.close()
                return
            }
        }
    }

    fileprivate func queue(_ operation: NNTPOperation) {
        self.pendingCommands.push(operation)
    }

    fileprivate func flush() {
        if !self.ostream.hasSpaceAvailable {
            return
        }

        while !self.pendingCommands.isEmpty && self.outBuffer.length < 4096 {
            let cmd = self.pendingCommands.pop()!

            if !cmd.isCancelled() {
                print(">>> \(cmd.command)")
                cmd.command.pack(self.outBuffer)
                self.sentCommands.push(cmd)
            }
        }

        self.outBuffer.read() {
            (buffer, length) in

            if length == 0 {
                return  0
            }

            switch (self.ostream.write(buffer.bindMemory(to: UInt8.self, capacity: length), maxLength: length)) {
            case let e where e > 0:
                return e

            case let e where e < 0:
                return 0
                
            default:
                return 0
            }
        }
    }

    fileprivate var hasPendingCommands : Bool {
        return !self.sentCommands.isEmpty || !self.pendingCommands.isEmpty
    }
}

public enum NNTPClientEvent {
    case connected
    case disconnected
    case error(Swift.Error)
}

/// The delegate object for NNTPClient.
public protocol NNTPClientDelegate : class {
    func nntpClient(_ client: NNTPClient, onEvent event: NNTPClientEvent)
}

/// The NNTPClient class manages the connection to a news server.
///
/// The client wraps the connection to the server. It handles the command
/// queue as well as the current state of the connection, including the
/// current group and article.
open class NNTPClient {
    fileprivate var connection : NNTPConnection?
    fileprivate var runLoops : [(RunLoop, String)] = []

    fileprivate var pipelineBarrier : Promise<NNTPPayload>
    fileprivate var queueOnPipelineError = false

    fileprivate let host : String
    fileprivate let port : Int
    fileprivate let ssl : Bool
    fileprivate var login : String?
    fileprivate var password : String?

    fileprivate var requiredDisconnection = false
    fileprivate var reconnectionDelay = 0
    open weak var delegate : NNTPClientDelegate?

    /* {{{ Stream delegate */

    fileprivate class StreamDelegate : NSObject, Foundation.StreamDelegate {
        fileprivate weak var nntp : NNTPClient?

        init(nntp: NNTPClient) {
            self.nntp = nntp
            super.init()
        }

        @objc fileprivate func reconnect() {
            if !self.nntp!.requiredDisconnection {
                _ = self.nntp?.connect()
            }
        }

        @objc func stream(_ stream: Stream, handle eventCode: Stream.Event) {
            switch (eventCode) {
            case Stream.Event():
                break

            case Stream.Event.openCompleted:
                if stream == self.nntp?.connection?.istream {
                    print("connected")
                    self.nntp?.delegate?.nntpClient(self.nntp!, onEvent: .connected)
                    self.nntp?.reconnectionDelay = 0
                }

            case Stream.Event.hasBytesAvailable:
                do {
                    try self.nntp?.connection?.read()
                } catch {
                }

            case Stream.Event.hasSpaceAvailable:
                self.nntp?.connection?.flush()

            case Stream.Event.errorOccurred, Stream.Event.endEncountered:
                if let connection = self.nntp?.connection {
                    if let error = stream.streamError {
                        self.nntp?.delegate?.nntpClient(self.nntp!, onEvent: .error(error))
                    } else {
                        self.nntp?.delegate?.nntpClient(self.nntp!, onEvent: .disconnected)
                    }

                    self.nntp?.connection = nil
                    connection.delegate = nil
                    connection.close()

                    if !self.nntp!.requiredDisconnection {
                        let reconnectionDelay = self.nntp!.reconnectionDelay

                        print("auto reconnect in \(reconnectionDelay)s")
                        Timer.scheduledTimer(timeInterval: TimeInterval(reconnectionDelay),
                            target: self, selector: #selector(StreamDelegate.reconnect), userInfo: nil, repeats: false)
                        self.nntp!.reconnectionDelay = min((reconnectionDelay + 1) * 2, 60)
                    } else {
                        print("no auto-reconn")
                    }
                }

            default:
                break
            }
        }
    }

    fileprivate var streamDelegate : StreamDelegate?

    /* }}} */

    /// Build a new client to the given server.
    ///
    /// Create a connection to the given `host` and `port`, optionally enabling
    /// SSL on the connection.
    ///
    /// - parameter host: the hostname of the server
    /// - parameter port: the port of the newsserver on the server
    /// - parameter ssl: indicates wether the connection should use SSL
    public init(host: String, port: Int, ssl: Bool) {
        self.host = host
        self.port = port
        self.ssl = ssl
        self.pipelineBarrier = Promise(failure: NNTPError.notConnected)
        self.streamDelegate = StreamDelegate(nntp: self)

        self.pipelineBarrier = Promise<NNTPPayload>() {
            (onSuccess, onError) in

            self.connection?.queue(NNTPOperation(command: NNTPCommand.connect, onSuccess: onSuccess, onError: onError, isCancelled: { false }))
        }
        self.sendCommand(NNTPCommand.modeReader)
    }

    /// Build a new client to the given URL
    ///
    /// This convenience initializer build a client to an URL. The URL must
    /// use one of the following scheme:
    /// - `news://` or `nntp://` for simple connections to a server. In that
    ///   case the port defaults to 119
    /// - `nntps://` for SSL-wrapped connections to a server. In that case
    ///   the port defaults to 563
    ///
    /// The provided URL must include a host name and can optionally specify
    /// a port in order to overwrite the default one.
    ///
    /// A user and password can also optionally be specified if the connection
    /// required authentication.
    ///
    /// - parameter url: the URL of the news server
    /// - returns: The creation will fail if the URL is invalid or if the
    ///    underlying sockets cannot be created.
    public convenience init?(url: URL) {
        var ssl = false
        var port = 119

        switch (url.scheme) {
        case "news"?, "nntp"?:
            break
        case "nntps"?:
            port = 563
            ssl = true
        default:
            return nil
        }

        guard let host = url.host else {
            return nil
        }

        if let urlPort = (url as NSURL).port {
            port = urlPort.intValue
        }

        self.init(host: host, port: port, ssl: ssl)
        self.setCredentials(url.user, password: url.password)
    }

    /// Set the credentials to use for the connection to the news server
    ///
    /// You can set no credentials (default), a login or a pair of login and
    /// password.
    ///
    /// - parameter login: The login to use
    /// - parameter password: The password to use
    open func setCredentials(_ login: String?, password: String?) {
        self.login = login
        self.password = password

        if let lg = login {
            self.sendCommand(NNTPCommand.authinfoUser(lg))

            if let pwd = password {
                self.sendCommand(NNTPCommand.authinfoPass(pwd))
            }
        }
    }

    /// Connects to the remote sever
    ///
    /// - returns: a promise a will be fired when the connection is established
    @discardableResult open func connect() -> Promise<NNTPPayload> {
        self.requiredDisconnection = false
        if self.connection != nil {
            return self.pipelineBarrier
        }

        self.connection = NNTPConnection(host: self.host, port: self.port, ssl: self.ssl)
        if self.connection == nil {
            return Promise<NNTPPayload>(failure: NNTPError.cannotConnect)
        }

        self.connection?.delegate = self.streamDelegate
        self.connection?.open()
        for (runLoop, mode) in self.runLoops {
            self.connection?.scheduleInRunLoop(runLoop, forMode: mode)
        }

        let promise = Promise<NNTPPayload>() {
            (onSuccess, onError) in

            self.connection?.sentCommands.push(NNTPOperation(command: NNTPCommand.connect, onSuccess: onSuccess, onError: onError, isCancelled: { false }))
        }
        self.pipelineBarrier = promise
        self.sendCommand(NNTPCommand.modeReader)
        if let lg = self.login {
            self.sendCommand(NNTPCommand.authinfoUser(lg))

            if let pwd = self.password {
                self.sendCommand(NNTPCommand.authinfoPass(pwd))
            }
        }

        return promise
    }

    /// Disconnect the remote server
    ///
    /// Force disconnection of the underlying channel from the server.
    open func disconnect() {
        if let connection = self.connection {
            self.requiredDisconnection = true
            self.connection = nil
            connection.close()
        }
    }

    open func scheduleInRunLoop(_ runLoop: RunLoop, forMode mode: String) {
        self.runLoops.append((runLoop, mode))
        self.connection?.scheduleInRunLoop(runLoop, forMode: mode)
    }

    open func removeFromRunLoop(_ runLoop: RunLoop, forMode mode: String) {
        if let idx = self.runLoops.index(where: { $0.0 === runLoop && $0.1 == mode }) {
            self.runLoops.remove(at: idx)
            self.connection?.removeFromRunLoop(runLoop, forMode: mode)
        }
    }



    fileprivate var currentGroup : String?

    fileprivate func queue(_ operation: NNTPOperation) throws {
        guard let connection = self.connection else {
            throw NNTPError.aborted
        }

        connection.queue(operation)
    }

    /// Schedule the emission of a sequence of commands.
    ///
    /// This function put the given list of commands in the pending queue and
    /// return a promise that allow the caller to be notified of the execution
    /// of the last command and receive its result.
    ///
    /// This function can be used in order to send commands that must strictly
    /// follow each other. It updates the internal context of the connection
    /// maintaining the current group selection. Moreover it tries to get
    /// rid of useless `.Group()` or `.ListGroup()` commands.
    ///
    /// - parameter immutableCommands: the commands to send
    /// - returns: a promise that will fail if any command fail, or succeed 
    ///    with the payload of the last command if all commands succeed
    @discardableResult open func sendCommands(_ immutableCommands: [NNTPCommand]) -> Promise<NNTPPayload> {
        func chain() -> Promise<NNTPPayload> {
            if immutableCommands.count == 0 {
                return Promise(failure: NNTPError.noCommandProvided)
            }

            var commands = immutableCommands
            var isCancelled = false
            var i = 0

            while i < commands.count {
                switch commands[i] {
                case .group(let group):
                    if group == self.currentGroup && i < commands.count - 1 {
                        commands.remove(at: i)
                        i -= 1
                    } else {
                        self.currentGroup = group
                    }

                case .listGroup(let group, _):
                    if group != self.currentGroup && i < commands.count - 1 {
                        commands.remove(at: i)
                        i -= 1
                    } else {
                        self.currentGroup = group
                    }

                default:
                    if let group = commands[i].group {
                        if group != self.currentGroup {
                            commands.insert(.group(group: group), at: i)
                            self.currentGroup = group
                        }
                    }
                    break
                }
                i += 1
            }

            let promise = Promise<NNTPPayload>(action: {
                (onSuccess, onError) throws in
                var actualOnSuccess = onSuccess
                var actualOnError = onError


                if commands.count > 1 {
                    actualOnSuccess = {
                        (payload) in

                        if !isCancelled {
                            onSuccess(payload)
                        }
                    }

                    actualOnError = {
                        (error) in

                        if !isCancelled {
                            isCancelled = true
                            onError(error)
                        }
                    }
                }

                for i in 0 ..< commands.count - 1 {
                    try self.queue(NNTPOperation(command: commands[i],
                        onSuccess: { (_) in () }, onError: actualOnError,
                        isCancelled: { isCancelled }))
                }

                try self.queue(NNTPOperation(command: commands.last!,
                    onSuccess: actualOnSuccess, onError: actualOnError,
                    isCancelled: { isCancelled }))
                self.connection?.flush()
            }, onCancel: { isCancelled = true })
            return promise
        }

        var out = self.pipelineBarrier.thenChain({
            (_) in chain()
        })

        if self.queueOnPipelineError {
            out = out.otherwiseChain({
                (error) in

                if case NNTPError.aborted = error {
                    return Promise<NNTPPayload>(failure: error)
                } else {
                    return chain()
                }
            })
        }
        return out
    }

    /// Sends a single command to the news server.
    ///
    /// This function is a convenience helper to send a single command. It
    /// behaves like `sendCommands()`
    ///
    /// - seealso: NNTPClient.sendCommands()
    /// - parameter command: The command to send
    /// - returns: a promise waiting allowing notification when the command is
    ///    executed
    @discardableResult open func sendCommand(_ command: NNTPCommand) -> Promise<NNTPPayload> {
        let promise = self.sendCommands([command])

        if !command.allowPipelining {
            self.pipelineBarrier = promise
            self.queueOnPipelineError = !command.fatalOnError
        }
        return promise
    }

    open var hasPendingCommands : Bool {
        if let res = self.connection?.hasPendingCommands {
            return res
        }
        return false
    }

    open func listArticles(_ group: String, since: Date) -> Promise<NNTPPayload> {
        return self.sendCommand(.newNews(NNTPCommand.Wildmat(pattern: group), since))
    }

    open func post(_ message: String) -> Promise<NNTPPayload> {
        print("sending POST")

        let send = self.sendCommand(.post)
        send.otherwise {
            print("\($0)")
        }

        return send.thenChain() {
            (payload) in

            print("sending body")
            return self.sendCommand(.postBody(message))
        }
    }
}
