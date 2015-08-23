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
    case ModeReader
    case Reader
    case Ihave
    case Post
    case NewNews
    case Hdr
    case Over
    case ListActiveTimes
    case ListDistribPats

    /* RFC 4642: STARTTLS */
    case StartTls

    /* RFC 4643: NNTP Authentication */
    case AuthinfoUser
    case AuthinfoSASL

    /* SASL mechanism:
    * http://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xml
    */
    case SaslPlain
    case SaslLogin
    case SaslCramMd5
    case SaslNtml
    case SaslDigestMd5

    /* RFC 4644: NNTP Streaming extension */
    case Streaming

    /* Special capabilities */
    case Version(Int)
    case Implementation(String)

    public var hashValue : Int {
        switch (self) {
        case .ModeReader:
            return 0
        case .Reader:
            return 1
        case .Ihave:
            return 2
        case .Post:
            return 3
        case .NewNews:
            return 4
        case .Hdr:
            return 5
        case .Over:
            return 6
        case .ListActiveTimes:
            return 7
        case .ListDistribPats:
            return 8
        case .StartTls:
            return 9
        case .AuthinfoUser:
            return 10
        case .AuthinfoSASL:
            return 11
        case .SaslPlain:
            return 12
        case .SaslLogin:
            return 13
        case .SaslCramMd5:
            return 14
        case .SaslNtml:
            return 15
        case .SaslDigestMd5:
            return 16
        case .Streaming:
            return 17
        case .Version(_):
            return 18
        case .Implementation(_):
            return 19
        }
    }
}

public func ==(lhs: NNTPCapability, rhs: NNTPCapability) -> Bool {
    return lhs.hashValue == rhs.hashValue
}


public enum NNTPResponseStatus : Character {
    case Information = "1"
    case Completed = "2"
    case Continue = "3"
    case Failure = "4"
    case ProtocolError = "5"
}

public enum NNTPResponseContext : Character {
    case Status = "0"
    case NewsgroupSelection = "1"
    case ArticleSelection = "2"
    case Distribution = "3"
    case Posting = "4"
    case Authentication = "8"
    case Extension = "9"
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

public enum NNTPError : ErrorType, CustomStringConvertible {
    case NotConnected
    case NoCommandProvided
    case CannotConnect
    case Aborted

    case ClientProtocolError(NNTPResponse)
    case UnsupportedError(NNTPResponse)
    case ServerProtocolError
    case UnexpectedResponse(NNTPResponse)
    case MalformedResponse(NNTPResponse)
    case MalformedOverviewLine(String)

    case ServiceTemporarilyUnvailable /* Error 400 */
    case NoSuchNewsgroup(group: String?) /* Error 411 */
    case NoNewsgroupSelected /* Error 412 */
    case CurrentArticleNumberIsInvalid /* Error 420 */
    case NoNextArticleInGroup /* Error 421 */
    case NoPreviousArticleInGroup /* Error 422 */
    case NoArticleWithThatNumber /* Error 423 */
    case NoArticleWithThatMsgId /* Error 430 */
    case ArticleNotWanted /* Error 435 */
    case TransferTemporaryFailure /* Error 436 */
    case TransferPermanentFailure /* Error 437 */
    case PostingNotPermitted(reason: String) /* Error 440 */
    case PostingFailed(reason: String) /* Error 441 */
    case AuthenticationFailed(reason: String) /* Error 481 */
    case AuthenticationSequenceError /* Error 482 */

    case ServicePermanentlyUnavailable /* Error 502 */

    public var description : String {
        switch self {
        case .NotConnected:
            return "not connected"

        case .NoCommandProvided:
            return "no command provided"

        case .CannotConnect:
            return "cannot connect to server"

        case .Aborted:
            return "operation aborted"

        case .ClientProtocolError(let response):
            return "client protocol error: \(response)"

        case .UnsupportedError(let response):
            return "unsupported error: \(response)"

        case .ServerProtocolError:
            return "server error"

        case .UnexpectedResponse(let response):
            return "unexpected server response: \(response)"

        case .MalformedResponse(let response):
            return "malformed server response: \(response)"

        case .MalformedOverviewLine(let line):
            return "malformed message overview: \(line)"

        case .ServiceTemporarilyUnvailable:
            return "service temporarily unavailable (retry later)"

        case .NoSuchNewsgroup(group: let group):
            return "unknown newsgroup: \(group)"

        case .NoNewsgroupSelected:
            return "no newsgroup selected"

        case .CurrentArticleNumberIsInvalid:
            return "current article number is invalid"

        case .NoNextArticleInGroup:
            return "no next article in group"

        case .NoPreviousArticleInGroup:
            return "no previous article in group"

        case .NoArticleWithThatNumber:
            return "no article with the given number"

        case .NoArticleWithThatMsgId:
            return "no article with the given message id"

        case .ArticleNotWanted:
            return "article not wanted"

        case .TransferTemporaryFailure:
            return "transfer temporary failure"

        case .TransferPermanentFailure:
            return "transfer permanent failure"

        case .PostingNotPermitted:
            return "posting not permitted"

        case .PostingFailed:
            return "posting failed"

        case .AuthenticationFailed:
            return "authentication failed"

        case .AuthenticationSequenceError:
            return "authentication sequence error"

        case .ServicePermanentlyUnavailable:
            return "service permanently unavailable"
        }
    }
}

private struct Global {
    static private let dateFormatter : NSDateFormatter = {
        let f = NSDateFormatter()

        f.dateFormat = "yyyyMMdd HHmmss"
        f.timeZone = NSTimeZone(abbreviation: "GMT")!
        return f
    }()

    static private let dateParser : NSDateFormatter = {
        let f = NSDateFormatter()

        f.dateFormat = "yyyyMMddHHmmss"
        f.timeZone = NSTimeZone(abbreviation: "GMT")!
        return f
    }()

    static private let spaceCset = NSCharacterSet(charactersInString: " ")
}

private func packDate(date: NSDate, inBuffer buffer: Buffer) {
    buffer.appendString(Global.dateFormatter.stringFromDate(date))
    buffer.appendString(" GMT")
}

public struct NNTPOverview {
    public let num : Int
    public let headers : MIMEHeaders

    public let bytes : Int?
    public let lines : Int?
}

public enum NNTPPayload {
    case Information(String)
    case Capabilities(Set<NNTPCapability>)
    case PasswordRequired
    case AuthenticationAccepted
    case MessageIds([String])
    case GroupContent(group: String, count: Int, lowestNumber: Int, highestNumber: Int, numbers: [Int]?)
    case ArticleFound(Int, String)
    case Article(Int, String, MIMEPart)
    case Headers(Int, String, MIMEHeaders)
    case Body(Int, String, String)
    case GroupList([(String, String)])
    case Date(NSDate)
    case Overview([NNTPOverview])
}

public enum NNTPCommand : CustomStringConvertible {
    public enum ListHeadersVariant : String {
        case MSGID
        case RANGE
    }

    public enum ArticleRange {
        case Number(Int)
        case From(Int)
        case Between(Int, Int)

        func pack(buffer: Buffer) {
            switch (self) {
            case .Number(let num):
                buffer.appendString("\(num)")

            case .From(let from):
                buffer.appendString("\(from)-")

            case .Between(let from, let to):
                buffer.appendString("\(from)-\(to)")
            }
        }
    }

    public struct Wildmat {
        let pattern : String
        
        func pack(buffer: Buffer) {
            buffer.appendString(self.pattern)
        }
    }


    case Connect

    /* RFC 3977: NNTP Version 2 */
    case Capabilities(String?)
    case ModeReader
    case Quit

    /* Group and article selection */
    case Group(group: String)
    case ListGroup(group: String, range: ArticleRange?)
    case Last(group: String)
    case Next(group: String)

    /* Article retrieval */
    case ArticleByMsgid(msgid: String)
    case Article(group: String, article: Int?)
    case HeadByMsgid(msgid: String)
    case Head(group: String, article: Int?)
    case BodyByMsgid(msgid: String)
    case Body(group: String, article: Int?)
    case StatByMsgid(msgid: String)
    case Stat(group: String, article: Int?)

    /* Posting */
    case Post
    case PostBody(String)
    case Ihave(String)

    /* Information */
    case Date
    case Help
    case NewGroups(NSDate)
    case NewNews(Wildmat, NSDate)

    /* List */
    case ListActive(Wildmat?)
    case ListActiveTimes(Wildmat?)
    case ListDistribPats
    case ListNewsgroups(Wildmat?)

    /* Article field access */
    case OverByMsgid(msgid: String)
    case Over(group: String, range: ArticleRange?)
    case ListOverviewFmt
    case HdrByMsgid(field: String, msgid: String)
    case Hdr(group: String, field: String, range: ArticleRange?)
    case ListHeaders(ListHeadersVariant?)

    /* RFC 4643: NNTP Authentication */
    case AuthinfoUser(String)
    case AuthinfoPass(String)
    case AuthinfoSASL

    private func pack(buffer: Buffer, forDisplay: Bool) {
        switch (self) {
        case .Connect:
            return

        case .Capabilities(let optKeyword):
            buffer.appendString("CAPABILITIES")
            if let keyword = optKeyword {
                buffer.appendString(" \(keyword)")
            }

        case .ModeReader:
            buffer.appendString("MODE READER")

        case .Quit:
            buffer.appendString("QUIT")

        case .Group(group: let group):
            buffer.appendString("GROUP \(group)")

        case .ListGroup(group: let group, range: let optRange):
            buffer.appendString("LISTGROUP")
            buffer.appendString(" \(group)")

            if let range = optRange {
                buffer.appendString(" ")
                range.pack(buffer)
            }

        case .Last(group: _):
            buffer.appendString("LAST")

        case .Next(group: _):
            buffer.appendString("NEXT")

        case .ArticleByMsgid(msgid: let msgid):
            buffer.appendString("ARTICLE \(msgid)")

        case .Article(group: _, article: let optArticle):
            buffer.appendString("ARTICLE")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .HeadByMsgid(msgid: let msgid):
            buffer.appendString("HEAD \(msgid)")

        case .Head(group: _, article: let optArticle):
            buffer.appendString("HEAD")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .BodyByMsgid(msgid: let msgid):
            buffer.appendString("BODY \(msgid)")

        case .Body(group: _, article: let optArticle):
            buffer.appendString("BODY")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .StatByMsgid(msgid: let msgid):
            buffer.appendString("STAT \(msgid)")

        case .Stat(group: _, article: let optArticle):
            buffer.appendString("STAT")

            if let article = optArticle {
                buffer.appendString(" \(article)")
            }

        case .Post:
            buffer.appendString("POST")

        case .PostBody(let body):
            buffer.appendString(body)
            if forDisplay {
                buffer.appendString("\r\n.")
            } else {
                buffer.appendString("\r\n.\r\n")
            }

        case .Ihave(let msgid):
            buffer.appendString("IHAVE \(msgid)")

        case .Date:
            buffer.appendString("DATE")

        case .Help:
            buffer.appendString("HELP")

        case .NewGroups(let date):
            buffer.appendString("NEWGROUPS ")
            packDate(date, inBuffer: buffer)

        case .NewNews(let wildmat, let date):
            buffer.appendString("NEWNEWS ")
            wildmat.pack(buffer)
            buffer.appendString(" ")
            packDate(date, inBuffer: buffer)

        case .ListActive(let optWildmat):
            buffer.appendString("LIST ACTIVE")

            if let wildmat = optWildmat {
                buffer.appendString(" ")
                wildmat.pack(buffer)
            }

        case .ListActiveTimes(let optWildmat):
            buffer.appendString("LIST ACTIVE.TIMES")

            if let wildmat = optWildmat {
                buffer.appendString(" ")
                wildmat.pack(buffer)
            }

        case .ListDistribPats:
            buffer.appendString("LIST DISTRIB.PATS")

        case .ListNewsgroups(let optWildmat):
            buffer.appendString("LIST NEWSGROUPS")

            if let wildmat = optWildmat {
                buffer.appendString(" ")
                wildmat.pack(buffer)
            }

        case .OverByMsgid(msgid: let msgid):
            buffer.appendString("OVER \(msgid)")

        case .Over(group: _, range: let optArticle):
            buffer.appendString("OVER")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .ListOverviewFmt:
            buffer.appendString("LIST OVERVIEW.FMT")

        case .HdrByMsgid(field: let field, msgid: let msgid):
            buffer.appendString("HDR \(field) \(msgid)")

        case .Hdr(group: _, field: let field, range: let optArticle):
            buffer.appendString("HDR \(field)")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .ListHeaders(let optVariant):
            buffer.appendString("LIST HEADERS")

            if let variant = optVariant {
                buffer.appendString(" \(variant.rawValue)")
            }

        case .AuthinfoUser(let login):
            buffer.appendString("AUTHINFO USER \(login)")

        case .AuthinfoPass(let password):
            if forDisplay {
                buffer.appendString("AUTHINFO PASS ****")
            } else {
                buffer.appendString("AUTHINFO PASS \(password)")
            }

        case .AuthinfoSASL:
            assert (false)
            return
        }

        if !forDisplay {
            buffer.appendString("\r\n")
        }
    }

    private func pack(buffer: Buffer) {
        return pack(buffer, forDisplay: false)
    }

    public var description : String {
        let buffer = Buffer(capacity: 1024)
        var out : NSString?

        self.pack(buffer, forDisplay: true)
        buffer.read() {
            (buffer, length) in

            out = NSString(bytes: buffer, length: length, encoding: NSUTF8StringEncoding)
            return length
        }

        return out! as String
    }

    private var isMultiline : Bool {
        switch self {
        case .Connect, .ModeReader, .Quit, .Group(_), .Last, .Next, .Post, .PostBody(_), .Ihave(_),
        .Date, .AuthinfoUser(_), .AuthinfoPass(_), .AuthinfoSASL:
            return false
        default:
            return true
        }
    }

    private var allowPipelining : Bool {
        switch self {
        case .Connect, .ModeReader, .Post, .PostBody(_), .Ihave(_), .AuthinfoUser(_), .AuthinfoPass(_), .AuthinfoSASL:
            return false

        default:
            return true
        }
    }

    private var fatalOnError : Bool {
        switch self {
        case .Connect, .ModeReader, AuthinfoUser(_), .AuthinfoPass(_), .AuthinfoSASL:
            return true

        default:
            return false
        }
    }

    private var group : String? {
        switch self {
        case .Last(group: let x):
            return x

        case .Next(group: let x):
            return x

        case .Article(group: let x, _):
            return x

        case .Head(group: let x, _):
            return x

        case .Body(group: let x, _):
            return x

        case .Stat(group: let x, _):
            return x

        case .Over(group: let x, range: _):
            return x

        default:
            return nil
        }
    }
}

private class NNTPOperation {
    private let command : NNTPCommand
    private let onSuccess : (NNTPPayload) -> Void
    private let onError : (ErrorType) -> Void
    private let isCancelled : (Void) -> Bool

    private var response : NNTPResponse?
    private var payload : [String]?

    private init(command: NNTPCommand, onSuccess: (NNTPPayload) -> Void, onError: (ErrorType) -> Void, isCancelled: (Void) -> Bool) {
        self.command = command
        self.onSuccess = onSuccess
        self.onError = onError
        self.isCancelled = isCancelled

        if self.command.isMultiline {
            self.payload = []
        }
    }

    private func acceptResponse(response: NNTPResponse) -> Bool {
        switch (self.command, response.status.rawValue, response.context.rawValue, response.code) {
        case (.Connect, "2", "0", "0"), (.Connect, "2", "0", "1"),
        (.Capabilities, "1", "0", "1"),
        (.ModeReader, "2", "0", "0"), (.ModeReader, "2", "0", "1"),
        (.Quit, "2", "0", "5"),
        (.Group, "2", "1", "1"),
        (.ListGroup, "2", "1", "1"),
        (.Last, "2", "2", "3"),
        (.Next, "2", "2", "3"),
        (.ArticleByMsgid, "2", "2", "0"),
        (.Article, "2", "2", "0"),
        (.HeadByMsgid, "2", "2", "1"),
        (.Head, "2", "2", "1"),
        (.BodyByMsgid, "2", "2", "2"),
        (.Body, "2", "2", "2"),
        (.StatByMsgid, "2", "2", "3"),
        (.Stat, "2", "2", "3"),
        (.Post, "3", "4", "0"),
        (.PostBody, "2", "4", "0"),
        (.Ihave, "3", "3", "5"), (.Ihave, "2", "3", "5"),
        (.Date, "1", "1", "1"),
        (.Help, "1", "0", "0"),
        (.NewGroups, "2", "3", "1"),
        (.NewNews, "2", "3", "0"),
        (.ListActive, "2", "1", "5"),
        (.ListActiveTimes, "2", "1", "5"),
        (.ListDistribPats, "2", "1", "5"),
        (.ListNewsgroups, "2", "1", "5"),
        (.OverByMsgid, "2", "2", "4"),
        (.Over, "2", "2", "4"),
        (.ListOverviewFmt, "2", "1", "5"),
        (.HdrByMsgid, "2", "2", "5"),
        (.Hdr, "2", "2", "5"),
        (.ListHeaders, "2", "1", "5"),
        (.AuthinfoUser, "2", "8", "1"), (.AuthinfoUser, "3", "8", "1"),
        (.AuthinfoPass, "2", "8", "1"),
        (_, "4", _, _), (_, "5", _, _):
            return true

        default:
            return false
        }
    }

    private func parseCapabilities() -> Set<NNTPCapability> {
        guard let payload = self.payload else {
            assert (false)
        }

        var set = Set<NNTPCapability>()
        lines: for line in payload {
            switch (line) {
            case "HDR":
                set.insert(.Hdr)

            case "IHAVE":
                set.insert(.Ihave)

            case "NEWNEWS":
                set.insert(.NewNews)

            case "POST":
                set.insert(.Post)

            case "MODE-READER":
                set.insert(.ModeReader)

            case "READER":
                set.insert(.Reader)

            case "OVER":
                set.insert(.Over)

            case "STREAMING":
                set.insert(.Streaming)

            default:
                let cset = NSCharacterSet(charactersInString: " ")
                let scanner = NSScanner(string: line)
                var keyword : NSString?

                scanner.charactersToBeSkipped = nil
                if !scanner.scanUpToCharactersFromSet(cset, intoString: &keyword) {
                    continue lines
                }
                switch (keyword!) {
                case "LIST":
                    list_cap: while !scanner.skipCharactersFromSet(cset) {
                        var cap : NSString?

                        if !scanner.scanUpToCharactersFromSet(cset, intoString: &cap) {
                            continue lines
                        }

                        switch (cap!) {
                        case "ACTIVE.TIMES":
                            set.insert(.ListActiveTimes)

                        case "DISTRIB.PATS":
                            set.insert(.ListDistribPats)

                        default:
                            continue list_cap
                        }
                    }
                    break

                case "IMPLEMENTATION":
                    scanner.skipCharactersFromSet(cset)
                    set.insert(.Implementation(scanner.remainder))
                    break

                case "VERSION":
                    var version : Int = 0

                    if !scanner.skipCharactersFromSet(cset) {
                        continue lines
                    }
                    if !scanner.scanInteger(&version) {
                        continue lines
                    }
                    set.insert(.Version(Int(version)))
                    
                default:
                    break
                }
                break
            }
        }
        
        return set
    }

    private func parseArticleFound(response: NNTPResponse) throws -> (Int, String) {
        let scanner = NSScanner(string: response.message)
        var number : Int = 0

        scanner.charactersToBeSkipped = nil
        if !scanner.scanInteger(&number)
            || !scanner.skipCharactersFromSet(Global.spaceCset)
        {
            throw NNTPError.MalformedResponse(response)
        }

        return (Int(number), scanner.remainder)
    }

    private func parsePayload() throws -> NNTPPayload {
        guard let response = self.response else {
            throw NNTPError.ServerProtocolError
        }

        if !self.acceptResponse(response) {
            throw NNTPError.UnexpectedResponse(response)
        }

        switch ((response.status.rawValue, response.context.rawValue, response.code)) {
        case ("2", "0", "0"), ("2", "0", "1"), ("2", "0", "5"):
            return NNTPPayload.Information(response.message)

        case ("1", "0", "1"):
            return .Capabilities(self.parseCapabilities())

        case ("1", "1", "1"):
            guard let date = Global.dateParser.dateFromString(response.message) else {
                throw NNTPError.UnexpectedResponse(response)
            }

            return .Date(date)

        case ("2", "8", "1"):
            return .AuthenticationAccepted

        case ("3", "8", "1"):
            return .PasswordRequired

        case ("2", "3", "0"):
            return .MessageIds(payload!)

        case ("2", "1", "1"):
            let scanner = NSScanner(string: response.message)
            var count : Int = 0
            var low : Int = 0
            var high : Int = 0
            var ids : [Int]?

            scanner.charactersToBeSkipped = nil
            if !scanner.scanInteger(&count)
                || !scanner.skipCharactersFromSet(Global.spaceCset)
                || !scanner.scanInteger(&low)
                || !scanner.skipCharactersFromSet(Global.spaceCset)
                || !scanner.scanInteger(&high)
                || !scanner.skipCharactersFromSet(Global.spaceCset)
            {
                throw NNTPError.MalformedResponse(response)
            }

            if let idList = payload {
                ids = []

                for id in idList {
                    let numId = Int(id)

                    if numId == nil {
                        throw NNTPError.MalformedResponse(response)
                    }
                    ids?.append(numId!)
                }
            }

            return .GroupContent(group: scanner.remainder, count: Int(count),
                lowestNumber: Int(low), highestNumber: Int(high), numbers: ids)

        case ("2", "2", "0"):
            let (number, msgid) = try self.parseArticleFound(response)
            let msg = try MIMEPart.parse(payload!)

            return .Article(number, msgid, msg)

        case ("2", "2", "1"):
            let (number, msgid) = try self.parseArticleFound(response)
            let headers = try MIMEHeaders.parse(payload!)

            return .Headers(number, msgid, headers)

        case ("2", "2", "2"):
            let (number, msgid) = try self.parseArticleFound(response)

            return .Body(number, msgid, "\r\n".join(payload!))

        case ("2", "2", "3"):
            let (number, msgid) = try self.parseArticleFound(response)

            return .ArticleFound(number, msgid)

        case ("2", "2", "4"):
            var overviews : [NNTPOverview] = []
            var headers : [String] = []

            for line in payload! {
                let tokens = line.characters.split("\t", maxSplit: 100, allowEmptySlices: true).map(String.init)

                if tokens.count < 8 {
                    throw NNTPError.MalformedOverviewLine(line)
                }

                guard let num = Int(tokens[0]) else {
                    throw NNTPError.MalformedOverviewLine(line)
                }

                headers.removeAll()
                if !tokens[1].isEmpty {
                    headers.append("Subject: " + tokens[1])
                }
                if !tokens[2].isEmpty {
                    headers.append("From: " + tokens[2])
                }
                if !tokens[3].isEmpty {
                    headers.append("Date: " + tokens[3])
                }
                if !tokens[4].isEmpty {
                    headers.append("Message-ID: " + tokens[4])
                }
                if !tokens[5].isEmpty {
                    headers.append("References: " + tokens[5])
                }

                var bytes : Int?
                if !tokens[6].isEmpty {
                    bytes = Int(tokens[6])
                    if bytes == nil {
                        throw NNTPError.MalformedOverviewLine(line)
                    }
                }

                var lines : Int?
                if !tokens[7].isEmpty {
                    lines = Int(tokens[7])
                    if lines == nil {
                        throw NNTPError.MalformedOverviewLine(line)
                    }
                }

                if tokens.count > 8 {
                    headers.extend(tokens[8..<tokens.count])
                }

                let overview = NNTPOverview(num: num, headers: try MIMEHeaders.parse(headers), bytes: bytes, lines: lines)
                overviews.append(overview)
            }
            return .Overview(overviews)

        case ("2", "1", "5"):
            switch (self.command) {
            case .ListNewsgroups(_):
                var res : [(String, String)] = []
                let cset = NSCharacterSet(charactersInString: " \t")

                for line in payload! {
                    let scanner = NSScanner(string: line)
                    var group : NSString?

                    scanner.charactersToBeSkipped = nil
                    if !scanner.scanUpToCharactersFromSet(cset, intoString: &group)
                        || !scanner.skipCharactersFromSet(cset)
                    {
                        throw NNTPError.MalformedResponse(response)
                    }
                    
                    res.append((group! as String), scanner.remainder)
                }
                return .GroupList(res)

            default:
                throw NNTPError.ServerProtocolError
            }

        case ("4", "0", "0"):
            throw NNTPError.ServiceTemporarilyUnvailable

        case ("4", "1", "1"):
            throw NNTPError.NoSuchNewsgroup(group: command.group)

        case ("4", "1", "2"):
            throw NNTPError.NoNewsgroupSelected

        case ("4", "2", "0"):
            throw NNTPError.CurrentArticleNumberIsInvalid

        case ("4", "2", "1"):
            throw NNTPError.NoNextArticleInGroup

        case ("4", "2", "2"):
            throw NNTPError.NoPreviousArticleInGroup

        case ("4", "2", "3"):
            throw NNTPError.NoArticleWithThatNumber

        case ("4", "3", "0"):
            throw NNTPError.NoArticleWithThatMsgId

        case ("4", "3", "5"):
            throw NNTPError.ArticleNotWanted

        case ("4", "3", "6"):
            throw NNTPError.TransferTemporaryFailure

        case ("4", "3", "7"):
            throw NNTPError.TransferPermanentFailure

        case ("4", "4", "0"):
            throw NNTPError.PostingNotPermitted(reason: response.message)

        case ("4", "4", "1"):
            throw NNTPError.PostingFailed(reason: response.message)

        case ("4", "8", "1"):
            throw NNTPError.AuthenticationFailed(reason: response.message)

        case ("4", "8", "2"):
            throw NNTPError.AuthenticationSequenceError

        case ("4", _, _):
            throw NNTPError.UnsupportedError(response)

        case ("5", "0", "2"):
            throw NNTPError.ServicePermanentlyUnavailable

        case ("5", _, _):
            throw NNTPError.ClientProtocolError(response)

        default:
            throw NNTPError.ServerProtocolError
        }
    }

    private func parseResponse(line: String) throws -> NNTPResponse {
        let chars = line.characters
        var status : NNTPResponseStatus?
        var context : NNTPResponseContext?
        var pos = 0

        if chars.count < 5 {
            throw NNTPError.ServerProtocolError
        }

        for char in chars {
            switch (pos) {
            case 0:
                status = NNTPResponseStatus(rawValue: char)
                if status == nil {
                    throw NNTPError.ServerProtocolError
                }
            case 1:
                context = NNTPResponseContext(rawValue: char)
                if context == nil {
                    throw NNTPError.ServerProtocolError
                }
            case 2:
                if char < "0" || char > "9" {
                    throw NNTPError.ServerProtocolError
                }
                return NNTPResponse(status: status!, context: context!, code: char,
                    message: (line as NSString).substringFromIndex(4))

            default:
                throw NNTPError.ServerProtocolError
            }
            pos++
        }
        
        throw NNTPError.ServerProtocolError
    }

    private func receivedLine(line: String) throws -> Bool {
        if self.response == nil {
            self.response = try self.parseResponse(line)
            return self.response!.status != .Completed || !self.command.isMultiline
        } else {
            assert(self.command.isMultiline)

            if line == "." {
                return true
            }
            self.payload?.append(line)
            return false
        }
    }

    private func fail(error: ErrorType) {
        self.onError(error)
    }

    private func process() {
        do {
            self.onSuccess(try self.parsePayload())
        } catch let e {
            self.onError(e)
        }
    }
}

/// Manage a single connection to a NNTP server.
private class NNTPConnection {
    private let istream : NSInputStream
    private let ostream : NSOutputStream
    private let reader : BufferedReader
    private let pendingCommands = FifoQueue<NNTPOperation>()
    private let sentCommands = FifoQueue<NNTPOperation>()
    private let outBuffer = Buffer(capacity: 2 << 20)

    private init?(host: String, port: Int, ssl: Bool) {
        var istream : NSInputStream?
        var ostream : NSOutputStream?

        NSStream.getStreamsToHostWithName(host, port: port,
            inputStream: &istream, outputStream: &ostream)

        if let ins = istream, let ous = ostream {
            self.istream = ins
            self.ostream = ous
            self.reader = BufferedReader(fromStream: ins)

        } else {
            self.istream = NSInputStream(data: NSData(bytes: nil, length: 0))
            self.ostream = NSOutputStream(toBuffer: nil, capacity: 0)
            self.reader = BufferedReader(fromStream: self.istream)
            return nil
        }
        if ssl {
            self.istream.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL,
                forKey: NSStreamSocketSecurityLevelKey)
        }
    }

    private var delegate : NSStreamDelegate? {
        set {
            self.istream.delegate = newValue
            self.ostream.delegate = newValue
        }

        get {
            return self.istream.delegate
        }
    }

    private func open() {
        self.istream.open()
        self.ostream.open()
    }

    private func close() {
        while let reply = self.sentCommands.pop() {
            reply.fail(NNTPError.Aborted)
        }

        while let reply = self.pendingCommands.pop() {
            reply.fail(NNTPError.Aborted)
        }

        self.istream.close()
        self.ostream.close()
    }
    
    private func scheduleInRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.istream.scheduleInRunLoop(runLoop, forMode: mode)
        self.ostream.scheduleInRunLoop(runLoop, forMode: mode)
    }

    private func removeFromRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.istream.removeFromRunLoop(runLoop, forMode: mode)
        self.ostream.removeFromRunLoop(runLoop, forMode: mode)
    }

    private func read() throws {
        while let lineData = try self.reader.readDataUpTo("\r\n", keepBound: false, endOfStreamIsBound: true) {
            guard let line = String.fromData(lineData) else {
                return
            }

            //print("<<< \(line)")
            if let reply = self.sentCommands.head {
                do {
                    if try reply.receivedLine(line) {
                        self.sentCommands.pop()
                        reply.process()
                    }
                } catch let e {
                    self.sentCommands.pop()
                    reply.fail(e)
                    self.close()
                    return
                }
            } else {
                self.close()
                return
            }
        }
    }

    private func queue(operation: NNTPOperation) {
        self.pendingCommands.push(operation)
    }

    private func flush() {
        if !self.ostream.hasSpaceAvailable {
            return
        }

        while !self.pendingCommands.isEmpty && self.outBuffer.length < 4096 {
            let cmd = self.pendingCommands.pop()!

            if !cmd.isCancelled() {
                //print(">>> \(cmd.command)")
                cmd.command.pack(self.outBuffer)
                self.sentCommands.push(cmd)
            }
        }

        self.outBuffer.read() {
            (buffer, length) in

            if length == 0 {
                return  0
            }

            switch (self.ostream.write(UnsafePointer<UInt8>(buffer), maxLength: length)) {
            case let e where e > 0:
                return e

            case let e where e < 0:
                return 0
                
            default:
                return 0
            }
        }
    }

    private var hasPendingCommands : Bool {
        return !self.sentCommands.isEmpty || !self.pendingCommands.isEmpty
    }
}

/// The NNTPClient class manages the connection to a news server.
///
/// The client wraps the connection to the server. It handles the command
/// queue as well as the current state of the connection, including the
/// current group and article.
public class NNTPClient {
    private var connection : NNTPConnection?
    private var runLoops : [(NSRunLoop, String)] = []

    private var pipelineBarrier : Promise<NNTPPayload>
    private var queueOnPipelineError = false

    private let host : String
    private let port : Int
    private let ssl : Bool
    private var login : String?
    private var password : String?

    /* {{{ Stream delegate */

    private class StreamDelegate : NSObject, NSStreamDelegate {
        private weak var nntp : NNTPClient?

        init(nntp: NNTPClient) {
            self.nntp = nntp
            super.init()
        }

        @objc func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
            switch (eventCode) {
            case NSStreamEvent.None:
                break

            case NSStreamEvent.OpenCompleted:
                break

            case NSStreamEvent.HasBytesAvailable:
                do {
                    try self.nntp?.connection?.read()
                } catch {
                }

            case NSStreamEvent.HasSpaceAvailable:
                self.nntp?.connection?.flush()

            case NSStreamEvent.ErrorOccurred, NSStreamEvent.EndEncountered:
                if let connection = self.nntp?.connection {
                    self.nntp?.connection = nil
                    connection.close()
                }

            default:
                break
            }
        }
    }

    private var streamDelegate : StreamDelegate?

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
        self.pipelineBarrier = Promise(failure: NNTPError.NotConnected)
        self.streamDelegate = StreamDelegate(nntp: self)

        self.pipelineBarrier = Promise<NNTPPayload>() {
            (onSuccess, onError) in

            self.connection?.queue(NNTPOperation(command: NNTPCommand.Connect, onSuccess: onSuccess, onError: onError, isCancelled: { false }))
        }
        self.sendCommand(NNTPCommand.ModeReader)
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
    public convenience init?(url: NSURL) {
        var ssl = false
        var port = 119

        switch (url.scheme) {
        case "news", "nntp":
            break
        case "nntps":
            port = 563
            ssl = true
        default:
            return nil
        }

        guard let host = url.host else {
            return nil
        }

        if let urlPort = url.port {
            port = urlPort.integerValue
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
    public func setCredentials(login: String?, password: String?) {
        self.login = login
        self.password = password

        if let lg = login {
            self.sendCommand(NNTPCommand.AuthinfoUser(lg))

            if let pwd = password {
                self.sendCommand(NNTPCommand.AuthinfoPass(pwd))
            }
        }
    }

    /// Connects to the remote sever
    ///
    /// - returns: a promise a will be fired when the connection is established
    public func connect() -> Promise<NNTPPayload> {
        if self.connection != nil {
            return self.pipelineBarrier
        }

        self.connection = NNTPConnection(host: self.host, port: self.port, ssl: self.ssl)
        if self.connection == nil {
            return Promise<NNTPPayload>(failure: NNTPError.CannotConnect)
        }

        self.connection?.delegate = self.streamDelegate
        self.connection?.open()
        for (runLoop, mode) in self.runLoops {
            self.connection?.scheduleInRunLoop(runLoop, forMode: mode)
        }

        let promise = Promise<NNTPPayload>() {
            (onSuccess, onError) in

            self.connection?.sentCommands.push(NNTPOperation(command: NNTPCommand.Connect, onSuccess: onSuccess, onError: onError, isCancelled: { false }))
        }
        self.pipelineBarrier = promise
        self.sendCommand(NNTPCommand.ModeReader)
        if let lg = self.login {
            self.sendCommand(NNTPCommand.AuthinfoUser(lg))

            if let pwd = self.password {
                self.sendCommand(NNTPCommand.AuthinfoPass(pwd))
            }
        }

        return promise
    }

    /// Disconnect the remote server
    ///
    /// Force disconnection of the underlying channel from the server.
    public func disconnect() {
        if let connection = self.connection {
            self.connection = nil
            connection.close()
        }
    }

    public func scheduleInRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.runLoops.append((runLoop, mode))
        self.connection?.scheduleInRunLoop(runLoop, forMode: mode)
    }

    public func removeFromRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        if let idx = self.runLoops.indexOf({ $0.0 === runLoop && $0.1 == mode }) {
            self.runLoops.removeAtIndex(idx)
            self.connection?.removeFromRunLoop(runLoop, forMode: mode)
        }
    }



    private var currentGroup : String?

    private func queue(operation: NNTPOperation) throws {
        guard let connection = self.connection else {
            throw NNTPError.Aborted
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
    public func sendCommands(immutableCommands: [NNTPCommand]) -> Promise<NNTPPayload> {
        func chain() -> Promise<NNTPPayload> {
            if immutableCommands.count == 0 {
                return Promise(failure: NNTPError.NoCommandProvided)
            }

            var commands = immutableCommands
            var isCancelled = false

            for var i = 0; i < commands.count; i++ {
                switch commands[i] {
                case .Group(let group):
                    if group == self.currentGroup && i < commands.count - 1 {
                        commands.removeAtIndex(i)
                        i--
                    } else {
                        self.currentGroup = group
                    }

                case .ListGroup(let group, _):
                    if group != self.currentGroup && i < commands.count - 1 {
                        commands.removeAtIndex(i)
                        i--
                    } else {
                        self.currentGroup = group
                    }

                default:
                    if let group = commands[i].group {
                        if group != self.currentGroup {
                            commands.insert(.Group(group: group), atIndex: i)
                            self.currentGroup = group
                        }
                    }
                    break
                }
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

                for var i = 0; i < commands.count - 1; i++ {
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

                if case NNTPError.Aborted = error {
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
    public func sendCommand(command: NNTPCommand) -> Promise<NNTPPayload> {
        let promise = self.sendCommands([command])

        if !command.allowPipelining {
            self.pipelineBarrier = promise
            self.queueOnPipelineError = !command.fatalOnError
        }
        return promise
    }

    public var hasPendingCommands : Bool {
        if let res = self.connection?.hasPendingCommands {
            return res
        }
        return false
    }

    public func listArticles(group: String, since: NSDate) -> Promise<NNTPPayload> {
        return self.sendCommand(.NewNews(NNTPCommand.Wildmat(pattern: group), since))
    }

    public func post(message: String) -> Promise<NNTPPayload> {
        return self.sendCommand(.Post).thenChain() {
            (payload) in

            return self.sendCommand(.PostBody(message))
        }
    }
}