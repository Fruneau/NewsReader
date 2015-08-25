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
    @IBOutlet weak var fromView: NSTextField!
    @IBOutlet weak var toView: NSTextField!
    @IBOutlet weak var subjectView: NSTextField!
    @IBOutlet weak var dateView: NSTextField!
    @IBOutlet weak var contactPictureView: UserBadgeView!
    @IBOutlet var bodyView: NSTextView!

    private var articlePromise : Promise<NNTPPayload>?

    override dynamic var representedObject : AnyObject? {
        willSet {
            self.articlePromise?.cancel()
            self.articlePromise = nil
        }

        didSet {
            self.articlePromise = self.article?.load()
            self.articlePromise?.then {
                (_) in

                self.articlePromise = nil
                guard let _ = self.collectionView.indexPathForItem(self) else {
                    return
                }

                self.collectionView.reloadData()
                //self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }

            self.fromView.objectValue = self.article?.from
            self.toView.objectValue = self.article?.to
            self.subjectView.objectValue = self.article?.subject
            self.dateView.objectValue = self.article?.date
            self.contactPictureView.objectValue = self.article?.contactPicture

            if let body = self.article?.body {
                self.bodyView.string = body
            } else {
                self.bodyView.string = "\nloading article content..."
            }
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

class ArticleLayout : NSCollectionViewFlowLayout {

}

class ArticleViewController : NSObject, NSCollectionViewDelegateFlowLayout, NSCollectionViewDataSource {

    @IBOutlet weak var articleView: NSCollectionView!

    var currentThread : Article? {
        /*
        willSet {
            if newValue === self.currentThread {
                return
            }

            guard let thread = self.currentThread?.thread else {
                return
            }

            if thread.count == 0 {
                return
            }

            var paths = Set<NSIndexPath>()
            for i in 0..<thread.count {
                paths.insert(NSIndexPath(forItem: i, inSection: 0))
            }

            self.articleView.deleteItemsAtIndexPaths(paths)
        }
        */

        didSet {
            if oldValue === self.currentThread {
                return
            }

            self.articleView.reloadData()

            /*
            guard let thread = self.currentThread?.thread else {
                return
            }

            if thread.count == 0 {
                return
            }

            var paths = Set<NSIndexPath>()
            for i in 0..<thread.count {
                paths.insert(NSIndexPath(forItem: i, inSection: 0))
            }

            self.articleView.insertItemsAtIndexPaths(paths)
            */
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