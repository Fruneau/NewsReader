//
//  NNTP.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

public enum NNTPCapability {
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

private let formatter = NSDateFormatter()

private func packDate(date: NSDate, inBuffer buffer: Buffer) {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "yyyyMMDD HHmmss"
    formatter.timeZone = NSTimeZone(abbreviation: "GMT")!

    buffer.appendString(formatter.stringFromDate(date))
    buffer.appendString(" GMT")
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

    /*
    private struct Description {
        let command : String?
        let validCodes : [UInt16]
        let requiredCapability : NNTPCapability?
        let isMultiline : Bool
        let isPipelineable : Bool
    }

    static private let descriptions : [NNTPCommand: NNTPCommand.Description] = [
        .Connect: Description(command: nil,
            validCodes: [ 200, 201, 400, 502 ],
            requiredCapability: nil,
            isMultiline: false,
            isPipelineable: false),
        .Capabilities: Description(command: "CAPABILITIES",
            validCodes: [ 101 ],
            requiredCapability: nil,
            isMultiline: true,
            isPipelineable: false),
        .ModeReader: Description(command: "MODE READER",
            validCodes: [ 200, 201, 502 ],
            requiredCapability: nil,
            isMultiline: false,
            isPipelineable: false),
        .Quit: Description(command: "QUIT",
            validCodes: [ 205 ],
            requiredCapability: nil,
            isMultiline: false,
            isPipelineable: false),

        .Group: Description(command: "GROUP",
            validCodes: [ 211, 411 ],
            requiredCapability: .Reader,
            isMultiline: false,
            isPipelineable: true),
        .ListGroup: Description(command: "LISTGROUP",
            validCodes: [ 211, 411, 412 ],
            requiredCapability: .Reader,
            isMultiline: true,
            isPipelineable: true),
        .Last: Description(command: "LAST",
            validCodes: [ 223, 412, 420, 422 ],
            requiredCapability: .Reader,
            isMultiline: false,
            isPipelineable: true),
        .Next: Description(command: "NEXT",
            validCodes: [ 223, 412, 420, 421 ],
            requiredCapability: .Reader,
            isMultiline: false,
            isPipelineable: true),

        .Article: Description(command: "ARTICLE",
            validCodes: [ 220, 412, 420, 423, 430 ],
            requiredCapability: .Reader,
            isMultiline: true,
            isPipelineable: true),
        .Head: Description(command: "HEAD",
            validCodes: [ 221, 412, 420, 423, 430 ],
            requiredCapability: nil,
            isMultiline: true,
            isPipelineable: true),
        .Body: Description(command: "BODY",
            validCodes: [ 222, 412, 420, 423, 430 ],
            requiredCapability: .Reader,
            isMultiline: true,
            isPipelineable: true),
        .Stat: Description(command: "STAT",
            validCodes: [ 223, 412, 420, 423, 430 ],
            requiredCapability: nil,
            isMultiline: true,
            isPipelineable: true),

        .Post: Description(command: "POST",
            validCodes: [ 340, 440 ],
            requiredCapability: .Post,
            isMultiline: false,
            isPipelineable: false),
        .Ihave: Description(command: "IHAVE",
            validCodes: [ 335, 435, 436 ],
            requiredCapability: .Ihave,
            isMultiline: false,
            isPipelineable: false),

        .Date: Description(command: "DATE",
            validCodes: [ 111 ],
            requiredCapability: .Reader,
            isMultiline: false,
            isPipelineable: true),
        .Help: Description(command: "HELP",
            validCodes: [ 100 ],
            requiredCapability: nil,
            isMultiline: true,
            isPipelineable: true),
        .NewGroups: Description(command: "NEWGROUPS",
            validCodes: [ 231 ],
            requiredCapability: .Reader,
            isMultiline: true,
            isPipelineable: true),
        .NewNews: Description(command: "NEWNEWS",
            validCodes: [ 230 ],
            requiredCapability: .NewNews,
            isMultiline: true,
            isPipelineable: true),

        .ListActive: Description(command: "LIST ACTIVE",
            validCodes: [ 215 ],
            requiredCapability: .Reader,
            isMultiline: true,
            isPipelineable: true),
        .ListActiveTimes: Description(command: "LIST ACTIVE.TIMES",
            validCodes: [ 215 ],
            requiredCapability: .ListActiveTimes,
            isMultiline: true,
            isPipelineable: true),
        .ListDistribPats: Description(command: "LIST DISTRIB.PATS",
            validCodes: [ 215 ],
            requiredCapability: .ListDistribPats,
            isMultiline: true,
            isPipelineable: true),
        .ListNewsgroups: Description(command: "LIST NEWSGROUPS",
            validCodes: [ 215 ],
            requiredCapability: .Reader,
            isMultiline: true,
            isPipelineable: true),

        .Over: Description(command: "OVER",
            validCodes: [ 224, 412, 420, 423, 430 ],
            requiredCapability: .Over,
            isMultiline: true,
            isPipelineable: true),
        .ListOverviewFmt: Description(command: "LIST OVERVIEW.FMT",
            validCodes: [ 215 ],
            requiredCapability: .Over,
            isMultiline: true,
            isPipelineable: true),
        .Hdr: Description(command: "HDR",
            validCodes: [ 225, 412, 420, 423, 430 ],
            requiredCapability: .Hdr,
            isMultiline: true,
            isPipelineable: true),
        .ListHeaders: Description(command: "LIST HEADERS",
            validCodes: [ 215 ],
            requiredCapability: .Hdr,
            isMultiline: true,
            isPipelineable: true),

        .AuthinfoUser: Description(command: "AUTHINFO USER",
            validCodes: [ 281, 381, 481, 482, 502 ],
            requiredCapability: .AuthinfoUser,
            isMultiline: false,
            isPipelineable: false),
        .AuthinfoPass: Description(command: "AUTHINFO PASS",
            validCodes: [ 281, 481, 482, 502],
            requiredCapability: .AuthinfoUser,
            isMultiline: false,
            isPipelineable: false),
        .AuthinfoSASL: Description(command: "AUTHINFO SASL",
            validCodes: [ 281, 283, 383, 481, 482, 402 ],
            requiredCapability: .AuthinfoSASL,
            isMultiline: false,
            isPipelineable: false)
    ]

    private var description : Description {
        return NNTPCommand.descriptions[self]!
    }
    */

    func pack(buffer: Buffer) {
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
            buffer.appendString("\r\n.\r\n")

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
            buffer.appendString("AUTHINFO PASS \(password)")

        case .AuthinfoSASL:
            assert (false)
            return
        }

        buffer.appendString("\r\n")
    }
}

public class NNTP {
    private let istream : NSInputStream
    private let ostream : NSOutputStream
    private let reader : BufferedReader
    private let pendingCommands = FifoQueue<NNTPCommand>()
    private let sentCommands = FifoQueue<NNTPCommand>()
    private let outBuffer = Buffer(capacity: 2 << 20)

    private var login : String?
    private var password : String?

    init?(host: String, port: Int, ssl: Bool) {
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

        self.sentCommands.push(NNTPCommand.Connect)
    }

    public func setCredentials(login: String?, password: String?) {
        self.login = login
        self.password = password
    }

    public func open() {
        self.istream.open()
        self.ostream.open()
    }

    public func scheduleInRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.istream.scheduleInRunLoop(runLoop, forMode: mode)
        self.ostream.scheduleInRunLoop(runLoop, forMode: mode)
    }

    private func flush() {
        while !self.pendingCommands.isEmpty && self.outBuffer.length < 4096 {
            self.pendingCommands.pop()!.pack(self.outBuffer)
        }
    }

    public func sendCommand(command: NNTPCommand) {
        self.pendingCommands.push(command)
        self.flush()
    }
}