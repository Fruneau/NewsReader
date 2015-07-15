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

    var isMultiline : Bool {
        switch (self) {
        case .Connect, .ModeReader, .Quit, .Group(_), .Last, .Next, .Post, .PostBody(_), .Ihave(_),
        .Date, .AuthinfoUser(_), .AuthinfoPass(_), .AuthinfoSASL:
            return false
        default:
            return true
        }
    }
}

private class NNTPReply {
    let command : NNTPCommand

    var code : UInt16?
    var message: String?

    var payload : [String]?

    init(command: NNTPCommand) {
        self.command = command

        if self.command.isMultiline {
            self.payload = []
        }
    }
}

public class NNTP {
    private let istream : NSInputStream
    private let ostream : NSOutputStream
    private let reader : BufferedReader
    private let pendingCommands = FifoQueue<NNTPCommand>()
    private let sentCommands = FifoQueue<NNTPReply>()
    private let outBuffer = Buffer(capacity: 2 << 20)

    private var login : String?
    private var password : String?

    private class Delegate : NSObject, NSStreamDelegate {
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
                print("Opened")
                break

            case NSStreamEvent.HasBytesAvailable:
                print("Read")
                do {
                    try self.nntp?.read()
                } catch {
                }

            case NSStreamEvent.HasSpaceAvailable:
                print("Can write")
                self.nntp?.flush()

            case NSStreamEvent.ErrorOccurred:
                break

            case NSStreamEvent.EndEncountered:
                break

            default:
                break
            }
        }
    }

    private var delegate : Delegate?

    public init?(host: String, port: Int, ssl: Bool) {
        var istream : NSInputStream?
        var ostream : NSOutputStream?

        NSStream.getStreamsToHostWithName(host, port: port,
            inputStream: &istream, outputStream: &ostream)

        self.delegate = nil
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

        self.delegate = Delegate(nntp: self)
        self.istream.delegate = self.delegate!
        self.ostream.delegate = self.delegate!
        if ssl {
            self.istream.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL,
                forKey: NSStreamSocketSecurityLevelKey)
        }

        self.sentCommands.push(NNTPReply(command: NNTPCommand.Connect))
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
            let cmd = self.pendingCommands.pop()!

            cmd.pack(self.outBuffer)
            self.sentCommands.push(NNTPReply(command: cmd))
        }

        self.outBuffer.read() {
            (buffer, length) in

            switch (self.ostream.write(UnsafePointer<UInt8>(buffer), maxLength: length)) {
            case let e where e >= 0:
                return e

            default:
                return 0
            }
        }
    }

    private func read() throws {
        while let line = try self.reader.readLine() {
            print("read line: \(line)")
            if let reply = self.sentCommands.head {
                if reply.code != nil {
                    if line == "." {
                        self.sentCommands.pop()
                        print(reply.message!)
                    } else {
                        reply.payload?.append(line)
                    }
                } else {
                    reply.code = 100
                    reply.message = line
                }
            } else {
                assert (false)
            }
        }
    }

    public func sendCommand(command: NNTPCommand) {
        self.pendingCommands.push(command)
        self.flush()
    }
}