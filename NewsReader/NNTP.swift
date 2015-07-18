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
}

private struct NNTPResponse {
    private enum Status : Character {
        case Information = "1"
        case Completed = "2"
        case Continue = "3"
        case Failure = "4"
        case ProtocolError = "5"
    }

    private enum Context : Character {
        case Status = "0"
        case NewsgroupSelection = "1"
        case ArticleSelection = "2"
        case Distribution = "3"
        case Posting = "4"
        case Authentication = "8"
        case Extension = "9"
    }

    private let status : Status
    private let context : Context
    private let code : Character
    private let message : String
}

private class NNTPReply {
    let command : NNTPCommand

    var response : NNTPResponse?
    var payload : [String]?

    init(command: NNTPCommand) {
        self.command = command

        if self.command.isMultiline {
            self.payload = []
        }
    }
}

public enum NNTPEvent {
    case Connected
    case Disconnected
    case Authenticated
    case Ready

    case ClientProtocolError
    case ServerProtocolError
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

    /* {{{ Connnection delegate */

    public class Delegate {
        public init() {
        }

        public func nntp(nntp: NNTP, handleEvent event: NNTPEvent) {
            preconditionFailure("this method must be overridden")
        }
    }

    public weak var delegate : Delegate?

    /* }}} */
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
                self.nntp?.delegate?.nntp(self.nntp!, handleEvent: .Disconnected)

            case NSStreamEvent.EndEncountered:
                if self.nntp?.ostream == stream {
                    print("out end \(stream.streamStatus.rawValue)")
                } else {
                    print("in end \(stream.streamStatus.rawValue)")
                }

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

    public func close() {
        self.istream.close()
        self.ostream.close()
    }

    public func scheduleInRunLoop(runLoop: NSRunLoop, forMode mode: String) {
        self.istream.scheduleInRunLoop(runLoop, forMode: mode)
        self.ostream.scheduleInRunLoop(runLoop, forMode: mode)
    }

    private func commandProcessed(reply: NNTPReply) {
        switch (reply.command) {
        case .Connect:
            self.delegate?.nntp(self, handleEvent: .Connected)
            self.sendCommand(.ModeReader)

        case .ModeReader:
            if let login = self.login {
                self.sendCommand(.AuthinfoUser(login))
            } else {
                self.delegate?.nntp(self, handleEvent: .Ready)
            }

        case .AuthinfoUser(_):
            if let password = self.password {
                self.sendCommand(.AuthinfoPass(password))
            } else {
                self.delegate?.nntp(self, handleEvent: .Authenticated)
                self.delegate?.nntp(self, handleEvent: .Ready)
            }

        case .AuthinfoPass(_):
            self.delegate?.nntp(self, handleEvent: .Authenticated)
            self.delegate?.nntp(self, handleEvent: .Ready)

        default:
            break
        }
    }

    private func parseResponse(line: String) -> NNTPResponse? {
        let chars = line.characters
        var status : NNTPResponse.Status?
        var context : NNTPResponse.Context?
        var pos = 0

        if chars.count < 5 {
            return nil
        }

        for char in chars {
            switch (pos) {
            case 0:
                status = NNTPResponse.Status(rawValue: char)
                if status == nil {
                    return nil
                }
            case 1:
                context = NNTPResponse.Context(rawValue: char)
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
                        self.delegate?.nntp(self, handleEvent: .ServerProtocolError)
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
                self.delegate?.nntp(self, handleEvent: .ServerProtocolError)
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

            cmd.pack(self.outBuffer)
            self.sentCommands.push(NNTPReply(command: cmd))
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
    
    public func sendCommand(command: NNTPCommand) {
        self.pendingCommands.push(command)
        self.flush()
    }
}