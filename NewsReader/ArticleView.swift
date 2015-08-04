//
//  ArticleView.swift
//  NewsReader
//
//  Created by Florent Bruneau on 04/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class UnscrollableScrollView : NSScrollView {
    override func scrollWheel(theEvent: NSEvent) {
        self.superview?.scrollWheel(theEvent)
    }
}

class BackgroundView : NSView {
    override func drawRect(dirtyRect: NSRect) {
        NSColor.whiteColor().set()
        NSRectFill(dirtyRect)
    }
}

class ArticleViewItem : NSCollectionViewItem {
    @IBOutlet weak var fromView: NSTextField!
    @IBOutlet weak var toView: NSTextField!
    @IBOutlet weak var subjectView: NSTextField!
    @IBOutlet weak var dateView: NSTextField!
    @IBOutlet weak var contactPictureView: UserBadgeView!
    @IBOutlet var bodyView: NSTextView!

    override dynamic var representedObject : AnyObject? {
        didSet {
            (oldValue as? Article)?.cancelLoad()

            let article = self.representedObject as? Article

            article?.load()
            self.fromView.objectValue = article?.from
            self.toView.objectValue = article?.to
            self.subjectView.objectValue = article?.subject
            self.dateView.objectValue = article?.date
            self.contactPictureView.objectValue = article?.contactPicture

            if let body = article?.body {
                self.bodyView.string = body
            } else {
                self.bodyView.string = "\nloading article content..."
            }
        }
    }
}

class ArticleViewController : NSObject, NSCollectionViewDelegateFlowLayout, NSCollectionViewDataSource {

    @IBOutlet weak var articleView: NSCollectionView!

    var currentThread : Article? {
        didSet {
            var oldPaths = Set<NSIndexPath>()
            if let thread = oldValue?.thread {
                for i in 0..<thread.count {
                    thread[i].delegate = nil
                    oldPaths.insert(NSIndexPath(forItem: i, inSection: 0))
                }
            }

            var newPaths = Set<NSIndexPath>()
            if let thread = self.currentThread?.thread {
                for i in 0..<thread.count {
                    thread[i].delegate = self
                    newPaths.insert(NSIndexPath(forItem: i, inSection: 0))
                }
            }

            if oldPaths.count == 0 && newPaths.count == 0 {
                return
            }

            self.articleView.performBatchUpdates({
                if oldPaths.count > 0 {
                    self.articleView.deleteItemsAtIndexPaths(oldPaths)
                }
                if newPaths.count > 0 {
                    self.articleView.insertItemsAtIndexPaths(newPaths)
                }
                }, completionHandler: { (_) in () })
        }
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

    func collectionView(collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> NSSize {
        let size = collectionView.frame.size

        guard let article = self.articleForIndexPath(indexPath) else {
            return NSSize(width: 0, height: 0)
        }

        let height = 120 + article.lines * 14
        return NSSize(width: size.width, height: CGFloat(height))
    }
}

extension ArticleViewController : ArticleDelegate {
    func articleUpdated(article: Article) {
        guard let indexPath = self.indexPathForArticle(article) else {
            return
        }
        
        self.articleView.reloadItemsAtIndexPaths([indexPath])
    }
}