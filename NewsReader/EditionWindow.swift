//
//  EditionWindow.swift
//  NewsReader
//
//  Created by Florent Bruneau on 13/09/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation
import Cocoa

class EditionWindow: NSWindowController {
    private let account : Account
    private let inReplyTo : Article?

    @IBOutlet weak var toField: NSTokenField!
    @IBOutlet weak var followupToField: NSTokenField!
    @IBOutlet weak var subjectField: NSTextField!
    @IBOutlet var bodyField: NSTextView!


    private init(newMessageForAccount account: Account, inReplyTo article: Article?) {
        self.account = account
        self.inReplyTo = article
        super.init(window: nil)

        NSBundle.mainBundle().loadNibNamed("EditionWindow", owner: self, topLevelObjects: nil)

        if article == nil {
            self.bodyField.string = "\n-- \n\(self.account.userName)"
        }
    }

    convenience init(newMessageForAccount account: Account) {
        self.init(newMessageForAccount: account, inReplyTo: nil)
    }

    convenience init(replyToArticle article: Article) {
        self.init(newMessageForAccount: article.account, inReplyTo: article)
    }

    convenience init(newMessageInGroup group: Group) {
        self.init(newMessageForAccount: group.account)
        self.toField.objectValue = [group.fullName]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.window?.titleVisibility = .Hidden
        self.toField.setDelegate(self.account)
        self.followupToField.setDelegate(self.account)
    }
}

extension EditionWindow {
    private func formatNewsgroupHeader(header: String, groups: AnyObject?) -> String? {
        guard let list = groups as? [String] else {
            return nil
        }

        let content = list.joinWithSeparator(", ")
        return "\(header): \(content)"
    }

    @IBAction func send(sender: AnyObject?) {
        var article : [String] = []

        self.window?.close()

        article.append("From: \(self.account.userName) <\(self.account.userEmail)>")
        guard let newsgroups = self.formatNewsgroupHeader("Newsgroups", groups: self.toField.objectValue) else {
            print("no destination")
            return
        }
        article.append(newsgroups)

        if let followup = self.formatNewsgroupHeader("Followup-To", groups: self.followupToField.objectValue) {
            article.append(followup)
        }

        let subject = self.subjectField.stringValue
        guard !subject.isEmpty else {
            print("subject is empty")
            return
        }
        article.append("Subject: \(subject)")
        article.append("Content-Type: text/plain; charset=utf-8")
        article.append("Content-Transfer-Encoding: 8bit")
        article.append("")

        if let body = self.bodyField.string {
            article.appendContentsOf(body.characters.split("\n").map(String.init))
        }

        print("posting message: \(article)")
        self.account.client?.post(article.joinWithSeparator("\r\n")).then({
            print("posting success: \($0)")
        }, otherwise: {
            print("posting error: \($0)")
        })
    }
}