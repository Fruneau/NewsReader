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

public struct NNTPResponse {
    public let status : NNTPResponseStatus
    public let context : NNTPResponseContext
    public let code : Character
    public let message : String
}

public enum NNTPError : ErrorType {
    case NotConnected
    case NoCommandProvided

    case ClientProtocolError(NNTPResponseContext, Character, String)
    case UnsupportedError(NNTPResponseContext, Character, String)
    case ServerProtocolError
    case UnexpectedResponse(NNTPResponseStatus, NNTPResponseContext, Character, String)
    case MalformedResponse(NNTPResponseStatus, NNTPResponseContext, Character, String)
    case MalformedOverviewLine(String)

    case ServiceTemporarilyUnvailable /* Error 400 */
    case NoSuchNewsgroup /* Error 411 */
    case NoNewsgroupSelected /* Error 412 */
    case CurrentArticleNumberIsInvalid /* Error 420 */
    case NoNextArticleInGroup /* Error 421 */
    case NoPreviousArticleInGroup /* Error 422 */
    case NoArticleWithThatNumber /* Error 423 */
    case NoArticleWithThatMsgId /* Error 430 */
    case ArticleNotWanted /* Error 435 */
    case TransferTemporaryFailure /* Error 436 */
    case TransferPermanentFailure /* Error 437 */
    case PostingNotPermitted /* Error 440 */
    case PostingFailed /* Error 441 */
    case AuthenticationFailed /* Error 481 */
    case AuthenticationSequenceError /* Error 482 */

    case ServicePermanentlyUnavailable /* Error 502 */

    private init?(response: NNTPResponse) {
        switch ((response.status, response.context, response.code, response.message)) {
        case (.Failure, .Status, "0", _):
            self = .ServiceTemporarilyUnvailable

        case (.Failure, .NewsgroupSelection, "1", _):
            self = .NoSuchNewsgroup

        case (.Failure, .NewsgroupSelection, "2", _):
            self = .NoNewsgroupSelected

        case (.Failure, .ArticleSelection, "0", _):
            self = .CurrentArticleNumberIsInvalid

        case (.Failure, .ArticleSelection, "1", _):
            self = .NoNextArticleInGroup

        case (.Failure, .ArticleSelection, "2", _):
            self = .NoPreviousArticleInGroup

        case (.Failure, .ArticleSelection, "3", _):
            self = .NoArticleWithThatNumber

        case (.Failure, .Distribution, "0", _):
            self = .NoArticleWithThatMsgId

        case (.Failure, .Distribution, "5", _):
            self = .ArticleNotWanted

        case (.Failure, .Distribution, "6", _):
            self = .TransferTemporaryFailure

        case (.Failure, .Distribution, "7", _):
            self = .TransferPermanentFailure

        case (.Failure, .Posting, "0", _):
            self = .PostingNotPermitted

        case (.Failure, .Posting, "1", _):
            self = .PostingFailed

        case (.Failure, .Authentication, "1", _):
            self = .AuthenticationFailed

        case (.Failure, .Authentication, "2", _):
            self = .AuthenticationSequenceError

        case (.Failure, let context, let code, let message):
            self = .UnsupportedError(context, code, message)

        case (.ProtocolError, .Status, "2", _):
            self = .ServicePermanentlyUnavailable

        case (.ProtocolError, let context, let code, let message):
            self = .ClientProtocolError(context, code, message)
            
        default:
            return nil
        }
    }
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

public enum ArticleId {
    case MessageId(String)
    case Number(Int)

    func pack(buffer: Buffer) {
        switch (self) {
        case .MessageId(let msgid):
            buffer.appendString("\(msgid)")

        case .Number(let num):
            buffer.appendString("\(num)")
        }
    }
}

public enum ArticleRangeOrId {
    case MessageId(String)
    case Number(Int)
    case From(Int)
    case Between(Int, Int)

    func pack(buffer: Buffer) {
        switch (self) {
        case .MessageId(let msgid):
            buffer.appendString("\(msgid)")

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

    public let bytes : Int
    public let lines : Int
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

public enum NNTPCommand {
    public enum ListHeadersVariant : String {
        case MSGID = "MSGID"
        case RANGE = "RANGE"
    }

    case Connect

    /* RFC 3977: NNTP Version 2 */
    case Capabilities(String?)
    case ModeReader
    case Quit

    /* Group and article selection */
    case Group(String)
    case ListGroup(String?, ArticleRange?)
    case Last
    case Next

    /* Article retrieval */
    case Article(ArticleId?)
    case Head(ArticleId?)
    case Body(ArticleId?)
    case Stat(ArticleId?)

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
    case Over(ArticleRangeOrId?)
    case ListOverviewFmt
    case Hdr(String, ArticleRangeOrId?)
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

        case .Group(let group):
            buffer.appendString("GROUP \(group)")

        case .ListGroup(let optGroup, let optRange):
            buffer.appendString("LISTGROUP")
            if let group = optGroup {
                buffer.appendString(" \(group)")

                if let range = optRange {
                    buffer.appendString(" ")
                    range.pack(buffer)
                }
            }

        case .Last:
            buffer.appendString("LAST")

        case .Next:
            buffer.appendString("NEXT")

        case .Article(let optArticle):
            buffer.appendString("ARTICLE")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .Head(let optArticle):
            buffer.appendString("HEAD")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .Body(let optArticle):
            buffer.appendString("BODY")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .Stat(let optArticle):
            buffer.appendString("STAT")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
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

        case .Over(let optArticle):
            buffer.appendString("OVER")

            if let article = optArticle {
                buffer.appendString(" ")
                article.pack(buffer)
            }

        case .ListOverviewFmt:
            buffer.appendString("LIST OVERVIEW.FMT")

        case .Hdr(let field, let optArticle):
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
        switch (self) {
        case .Connect, .ModeReader, .Quit, .Group(_), .Last, .Next, .Post, .PostBody(_), .Ihave(_),
        .Date, .AuthinfoUser(_), .AuthinfoPass(_), .AuthinfoSASL:
            return false
        default:
            return true
        }
    }

    private func acceptResponse(response: NNTPResponse) -> Bool {
        switch ((self, response.status.rawValue, response.context.rawValue, response.code)) {
        case (.Connect, "2", "0", "0"), (.Connect, "2", "0", "1"),
            (.Capabilities, "1", "0", "1"),
            (.ModeReader, "2", "0", "0"), (.ModeReader, "2", "0", "1"),
            (.Quit, "2", "0", "5"),
            (.Group, "2", "1", "1"),
            (.ListGroup, "2", "1", "1"),
            (.Last, "2", "2", "3"),
            (.Next, "2", "2", "3"),
            (.Article, "2", "2", "0"),
            (.Head, "2", "2", "1"),
            (.Body, "2", "2", "2"),
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
            (.Over, "2", "2", "4"),
            (.ListOverviewFmt, "2", "1", "5"),
            (.Hdr, "2", "2", "5"),
            (.ListHeaders, "2", "1", "5"),
            (.AuthinfoUser, "2", "8", "1"), (.AuthinfoUser, "3", "8", "1"),
            (.AuthinfoPass, "2", "8", "1"):
            return true

        default:
            return false
        }
    }

    private func parseCapabilities(payload: [String]) -> Set<NNTPCapability> {
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
            throw NNTPError.MalformedResponse(response.status, response.context, response.code, response.message)
        }

        return (Int(number), scanner.remainder)
    }

    private func parseResponse(response: NNTPResponse, payload: [String]?) throws -> NNTPPayload {
        if let error = NNTPError(response: response) {
            throw error
        }

        if !self.acceptResponse(response) {
            throw NNTPError.UnexpectedResponse(response.status, response.context, response.code, response.message)
        }

        switch ((response.status.rawValue, response.context.rawValue, response.code)) {
        case ("2", "0", "0"), ("2", "0", "1"), ("2", "0", "5"):
            return NNTPPayload.Information(response.message)

        case ("1", "0", "1"):
            return .Capabilities(self.parseCapabilities(payload!))

        case ("1", "1", "1"):
            guard let date = Global.dateParser.dateFromString(response.message) else {
                throw NNTPError.UnexpectedResponse(response.status, response.context, response.code, response.message)
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
                throw NNTPError.MalformedResponse(response.status, response.context, response.code, response.message)
            }

            if let idList = payload {
                ids = []

                for id in idList {
                    let numId = Int(id)

                    if numId == nil {
                        throw NNTPError.MalformedResponse(response.status, response.context, response.code, response.message)
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
                let tokens = split(line.characters, maxSplit: 100, allowEmptySlices: true){ $0 == "\t" }.map(String.init)

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

                guard let bytes = Int(tokens[6]) else {
                    throw NNTPError.MalformedOverviewLine(line)
                }
                guard let lines = Int(tokens[7]) else {
                    throw NNTPError.MalformedOverviewLine(line)
                }

                if tokens.count > 8 {
                    headers.extend(tokens[8..<tokens.count])
                }

                let overview = NNTPOverview(num: num, headers: try MIMEHeaders.parse(headers), bytes: bytes, lines: lines)
                overviews.append(overview)
            }
            return .Overview(overviews)

        case ("2", "1", "5"):
            switch (self) {
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
                        throw NNTPError.MalformedResponse(response.status, response.context, response.code, response.message)
                    }

                    res.append((group! as String), scanner.remainder)
                }
                return .GroupList(res)

            default:
                throw NNTPError.ServerProtocolError
            }

        default:
            throw NNTPError.ServerProtocolError
        }
    }
}

public enum NNTPStatus {
    case Disconnected
    case Connecting
    case Connected
    case Ready
}

public class NNTP {
    private class Reply {
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
    }

    private let istream : NSInputStream
    private let ostream : NSOutputStream
    private let reader : BufferedReader
    private let pendingCommands = FifoQueue<NNTP.Reply>()
    private let sentCommands = FifoQueue<NNTP.Reply>()
    private let outBuffer = Buffer(capacity: 2 << 20)
    private var onConnected : Promise<NNTPPayload>

    private var login : String?
    private var password : String?

    /* {{{ Stream delegate */

    private class StreamDelegate : NSObject, NSStreamDelegate {
        weak var nntp : NNTP?

        init(nntp: NNTP) {
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
                    try self.nntp?.read()
                } catch {
                }

            case NSStreamEvent.HasSpaceAvailable:
                self.nntp?.flush()

            case NSStreamEvent.ErrorOccurred:
                self.nntp?.status = .Disconnected

            case NSStreamEvent.EndEncountered:
                self.nntp?.status = .Disconnected

            default:
                break
            }
        }
    }

    private var streamDelegate : StreamDelegate?

    /* }}} */

    public init?(host: String, port: Int, ssl: Bool) {
        var istream : NSInputStream?
        var ostream : NSOutputStream?

        NSStream.getStreamsToHostWithName(host, port: port,
            inputStream: &istream, outputStream: &ostream)

        self.onConnected = Promise(failed: NNTPError.NotConnected)
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

        self.streamDelegate = StreamDelegate(nntp: self)
        self.istream.delegate = self.streamDelegate!
        self.ostream.delegate = self.streamDelegate!
        if ssl {
            self.istream.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL,
                forKey: NSStreamSocketSecurityLevelKey)
        }

        self.onConnected = Promise<NNTPPayload>() {
            (onSuccess, onError) in

            self.sentCommands.push(NNTP.Reply(command: NNTPCommand.Connect, onSuccess: onSuccess, onError: onError, isCancelled: { false }))
        }
        self.onConnected = self.sendCommand(NNTPCommand.ModeReader)
    }

    public convenience init?(url: NSURL) {
        var ssl = false
        var port = 465

        switch (url.scheme) {
        case "news", "nntp":
            break
        case "nntps":
            port = 563
            ssl = true
        default:
            return nil
        }

        if url.host == nil {
            return nil
        }

        if let urlPort = url.port {
            port = urlPort.integerValue
        }

        self.init(host: url.host!, port: port, ssl: ssl)
        self.setCredentials(url.user, password: url.password)
    }

    public func setCredentials(login: String?, password: String?) {
        self.login = login
        self.password = password

        if let lg = login {
            self.onConnected = self.sendCommand(NNTPCommand.AuthinfoUser(lg))

            if let pwd = password {
                self.onConnected = self.sendCommand(NNTPCommand.AuthinfoPass(pwd))
            }
        }
    }

    public func open() {
        self.istream.open()
        self.ostream.open()
    }

    public func close() {
        self.istream.close()
        self.ostream.close()
    }

    public func scheduleInRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.istream.scheduleInRunLoop(runLoop, forMode: mode)
        self.ostream.scheduleInRunLoop(runLoop, forMode: mode)
    }

    public func removeFromRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.istream.removeFromRunLoop(runLoop, forMode: mode)
        self.ostream.removeFromRunLoop(runLoop, forMode: mode)
    }

    private func commandProcessed(reply: NNTP.Reply) {
        guard let response = reply.response else {
            reply.onError(NNTPError.ServerProtocolError)
            return
        }
        do {
            reply.onSuccess(try reply.command.parseResponse(response, payload: reply.payload))
        } catch let e {
            reply.onError(e)
        }
    }

    private func parseResponse(line: String) -> NNTPResponse? {
        let chars = line.characters
        var status : NNTPResponseStatus?
        var context : NNTPResponseContext?
        var pos = 0

        if chars.count < 5 {
            return nil
        }

        for char in chars {
            switch (pos) {
            case 0:
                status = NNTPResponseStatus(rawValue: char)
                if status == nil {
                    return nil
                }
            case 1:
                context = NNTPResponseContext(rawValue: char)
                if context == nil {
                    return nil
                }
            case 2:
                if char < "0" || char > "9" {
                    return nil
                }
                return NNTPResponse(status: status!, context: context!, code: char,
                    message: (line as NSString).substringFromIndex(4))

            default:
                return nil
            }
            pos++
        }

        return nil
    }

    private func read() throws {
        while let line = try self.reader.readLine() {
            if let reply = self.sentCommands.head {
                if reply.response == nil {
                    reply.response = self.parseResponse(line)

                    if let response = reply.response {
                        if response.status != .Completed || !reply.command.isMultiline {
                            self.sentCommands.pop()
                            self.commandProcessed(reply)
                        }
                    } else {
                        self.close()
                        return
                    }
                } else {
                    if line == "." {
                        self.sentCommands.pop()
                        commandProcessed(reply)
                    } else {
                        reply.payload?.append(line)
                    }
                }
            } else {
                self.close()
                return
            }
        }
    }

    private func flush() {
        if !self.ostream.hasSpaceAvailable {
            return
        }

        while !self.pendingCommands.isEmpty && self.outBuffer.length < 4096 {
            let cmd = self.pendingCommands.pop()!

            if !cmd.isCancelled() {
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

    private var currentGroup : String?

    public func sendCommands(immutableCommands: [NNTPCommand]) -> Promise<NNTPPayload> {
        return self.onConnected.thenChain({
            (_) in

            if immutableCommands.count == 0 {
                return Promise(failed: NNTPError.NoCommandProvided)
            }

            var commands : [NNTPCommand] = immutableCommands
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

                case .ListGroup(let group, _) where group != nil:
                    if group != self.currentGroup && i < commands.count - 1 {
                        commands.removeAtIndex(i)
                        i--
                    } else {
                        self.currentGroup = group
                    }

                default:
                    break
                }
            }

            let promise = Promise<NNTPPayload>(action: {
                (onSuccess, onError) in
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
                    print("chaining commands")
                    self.pendingCommands.push(NNTP.Reply(command: commands[i],
                        onSuccess: { (_) in () }, onError: actualOnError,
                        isCancelled: { isCancelled }))
                }

                self.pendingCommands.push(NNTP.Reply(command: commands.last!,
                    onSuccess: actualOnSuccess, onError: actualOnError,
                    isCancelled: { isCancelled }))
                self.flush()
            }, onCancel: { isCancelled = true })
            return promise
        })
    }

    public func sendCommand(command: NNTPCommand) -> Promise<NNTPPayload> {
        return self.sendCommands([command])
    }

    public func sendCommand(command: NNTPCommand, inGroup group: String) -> Promise<NNTPPayload> {
        return self.sendCommands([ .Group(group), command ])
    }

    private var status : NNTPStatus = .Disconnected
    public var nntpStatus : NNTPStatus {
        return status
    }

    public var hasPendingCommands : Bool {
        return !self.sentCommands.isEmpty || !self.pendingCommands.isEmpty
    }

    public func listArticles(group: String, since: NSDate) -> Promise<NNTPPayload> {
        return self.sendCommand(.NewNews(Wildmat(pattern: group), since))
    }

    public func post(message: String) -> Promise<NNTPPayload> {
        return self.sendCommand(.Post).thenChain() {
            (payload) in

            return self.sendCommand(.PostBody(message))
        }
    }
}