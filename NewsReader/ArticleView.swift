//
//  ArticleView.swift
//  NewsReader
//
//  Created by Florent Bruneau on 04/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa
import Lib
import News

class UnscrollableScrollView : NSScrollView {
    override func scrollWheel(theEvent: NSEvent) {
        self.superview?.scrollWheel(theEvent)
    }
}

class ArticleViewItem : NSCollectionViewItem {
    private weak var articlePromise : Promise<NNTPPayload>?
    private var bodyWatchContext = 0;

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.bodyWatchContext:
            guard let article = self.article, let _ = article.body else {
                return
            }

            guard let indexPath = self.collectionView.indexPathForItem(self) else {
                return
            }

            self.collectionView.reloadItemsAtIndexPaths([indexPath])
            if !self.view.hidden {
                article.isRead = true;
            }

        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    override dynamic var representedObject : AnyObject? {
        willSet {
            self.article?.removeObserver(self, forKeyPath: "body", context: &self.bodyWatchContext)
            self.articlePromise?.cancel()
            self.articlePromise = nil
        }

        didSet {
            self.article?.addObserver(self, forKeyPath: "body", options: [], context: &self.bodyWatchContext)
            self.articlePromise = self.article?.load()
        }
    }
    var article : Article? {
        return self.representedObject as? Article
    }

    override func viewDidAppear() {
        if self.article?.body != nil {
            self.article?.isRead = true
        }
    }
}

class ArticleViewController : NSViewController {
    private var articleView : NSCollectionView {
        return self.view as! NSCollectionView
    }

    private var currentThread : Article? {
        return self.representedObject as? Article
    }

    private var needToScroll = false
    override var representedObject : AnyObject? {
        didSet {
            self.articleView.reloadData()

            if self.currentThread != nil {
                self.needToScroll = true
            }
        }
    }

    private func scrollArticleToVisible(article: Article) -> Bool {
        guard let indexPath = self.indexPathForArticle(article) else {
            return false
        }
        
        guard let rect = self.articleView.layoutAttributesForItemAtIndexPath(indexPath)?.frame else {
            return false
        }

        self.articleView.superview?.scrollRectToVisible(rect)
        return true
    }

    private func articleForIndexPath(indexPath: NSIndexPath) -> Article? {
        guard indexPath.section == 0 else {
            return nil
        }

        guard let thread = self.currentThread?.thread else {
            return nil
        }

        return thread[indexPath.item]
    }

    private func indexPathForArticle(article: Article) -> NSIndexPath? {
        guard let idx = self.currentThread?.thread.indexOf(article) else {
            return nil
        }

        return NSIndexPath(forItem: idx, inSection: 0)
    }
}

extension ArticleViewController : NSCollectionViewDataSource {
    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let thread = self.currentThread?.thread else {
            return 0
        }

        return thread.count
    }

    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItemWithIdentifier("Article", forIndexPath: indexPath)

        item.representedObject = self.articleForIndexPath(indexPath)
        return item
    }
}

extension ArticleViewController : NSCollectionViewDelegateFlowLayout {
    func collectionView(collectionView: NSCollectionView, didEndDisplayingItem item: NSCollectionViewItem, forRepresentedObjectAtIndexPath indexPath: NSIndexPath) {
        if self.needToScroll {
            guard let thread = self.currentThread else {
                return
            }

            self.needToScroll = false
            if let unread = thread.threadFirstUnread {
                self.scrollArticleToVisible(unread)
            } else {
                self.scrollArticleToVisible(thread)
            }
        }
    }

    func collectionView(collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> NSSize {
        let size = collectionView.superview!.superview!.frame.size

        guard let article = self.articleForIndexPath(indexPath) else {
            return NSSize(width: 0, height: 0)
        }

        let height = 140 + article.lines * 14

        if article.inReplyTo != nil || article.replies.count != 0 {
            return NSSize(width: size.width - 30, height: CGFloat(height))
        } else {
            return NSSize(width: size.width, height: max(size.height, CGFloat(height)))
        }
    }
}