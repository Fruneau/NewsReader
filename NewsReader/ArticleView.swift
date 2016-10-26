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
    override func scrollWheel(with theEvent: NSEvent) {
        self.superview?.scrollWheel(with: theEvent)
    }
}

class ArticleViewItem : NSCollectionViewItem {
    fileprivate weak var articlePromise : Promise<NNTPPayload>?
    fileprivate var bodyWatchContext = 0;

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch context {
        case (&self.bodyWatchContext)?:
            guard let article = self.article, let _ = article.body else {
                return
            }

            guard let indexPath = self.collectionView.indexPath(for: self) else {
                return
            }

            self.collectionView.reloadItems(at: [indexPath])
            if !self.view.isHidden {
                article.isRead = true;
            }

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    override dynamic var representedObject : Any? {
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
    fileprivate var articleView : NSCollectionView {
        return self.view as! NSCollectionView
    }

    fileprivate var currentThread : Article? {
        return self.representedObject as? Article
    }

    fileprivate var needToScroll = false
    override var representedObject : Any? {
        didSet {
            self.articleView.reloadData()

            if self.currentThread != nil {
                self.needToScroll = true
            }
        }
    }

    fileprivate func scrollArticleToVisible(_ article: Article) -> Bool {
        guard let indexPath = self.indexPathForArticle(article) else {
            return false
        }
        
        guard let rect = self.articleView.layoutAttributesForItem(at: indexPath)?.frame else {
            return false
        }

        self.articleView.superview?.scrollToVisible(rect)
        return true
    }

    fileprivate func articleForIndexPath(_ indexPath: IndexPath) -> Article? {
        guard (indexPath as NSIndexPath).section == 0 else {
            return nil
        }

        guard let thread = self.currentThread?.thread else {
            return nil
        }

        return thread[(indexPath as NSIndexPath).item]
    }

    fileprivate func indexPathForArticle(_ article: Article) -> IndexPath? {
        guard let idx = self.currentThread?.thread.index(of: article) else {
            return nil
        }

        return IndexPath(item: idx, section: 0)
    }
}

extension ArticleViewController : NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let thread = self.currentThread?.thread else {
            return 0
        }

        return thread.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: "Article", for: indexPath)

        item.representedObject = self.articleForIndexPath(indexPath)
        return item
    }
}

extension ArticleViewController : NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView, didEndDisplaying item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        if self.needToScroll {
            guard let thread = self.currentThread else {
                return
            }

            self.needToScroll = false
            if let unread = thread.threadFirstUnread {
                _ = self.scrollArticleToVisible(unread)
            } else {
                _ = self.scrollArticleToVisible(thread)
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
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
