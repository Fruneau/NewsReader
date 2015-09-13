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

    private init(newMessageForAccount account: Account, inReplyTo article: Article?) {
        self.account = account
        self.inReplyTo = article
        super.init(window: nil)

        NSBundle.mainBundle().loadNibNamed("EditionWindow", owner: self, topLevelObjects: nil)
    }

    convenience init(newMessageForAccount account: Account) {
        self.init(newMessageForAccount: account, inReplyTo: nil)
    }

    convenience init(replyToArticle article: Article) {
        self.init(newMessageForAccount: article.account, inReplyTo: article)
    }

    convenience init(newMessageInGroup group: Group) {
        self.init(newMessageForAccount: group.account)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        print("window did load \(self.window != nil)")
        super.windowDidLoad()
        self.window?.titleVisibility = .Hidden
    }
}

extension EditionWindow {
    @IBAction func send(sender: AnyObject?) {
        self.window?.close()
    }
}
