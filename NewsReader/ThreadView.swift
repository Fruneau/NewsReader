//
//  ThreadView.swift
//  NewsReader
//
//  Created by Florent Bruneau on 05/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class ThreadViewItem : NSCollectionViewItem {
    dynamic var threadHasReplies = false
    private func updateThreadCountViewVisibility() {
        guard let article = self.representedObject as? Article else {
            return
        }

        self.threadHasReplies = article.threadCount > 1
    }

    var threadCountChangeCtx = 0;
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        switch context {
        case &self.threadCountChangeCtx:
            self.updateThreadCountViewVisibility()

        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    override var representedObject : AnyObject? {
        willSet {
            guard let article = self.representedObject as? Article else {
                return
            }

            article.removeObserver(self, forKeyPath: "threadCount")
        }

        didSet {
            guard let article = self.representedObject as? Article else {
                return
            }

            article.addObserver(self, forKeyPath: "threadCount", options: [], context: &self.threadCountChangeCtx)
            self.updateThreadCountViewVisibility()
        }
    }

    dynamic var textColor : NSColor?
    dynamic var backgroundColor : NSColor?
    dynamic var unreadImage = NSImage(named: "unread")

    override var selected : Bool {
        didSet {
            if oldValue == self.selected {
                return
            }

            if self.selected {
                self.textColor = NSColor.alternateSelectedControlTextColor()
                self.backgroundColor = NSColor.alternateSelectedControlColor()
                self.unreadImage = NSImage(named: "unread-selected")
            } else {
                self.textColor = nil
                self.backgroundColor = nil
                self.unreadImage = NSImage(named: "unread")
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.view.bind("backgroundColor", toObject: self, withKeyPath: "backgroundColor", options: nil)
    }
}

class ThreadViewController : NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    @IBOutlet weak var threadView: NSCollectionView!
    @IBOutlet weak var articleViewController: ArticleViewController!

    var currentGroup : Group? {
        willSet {
            self.currentGroup?.delegate = nil
        }

        didSet {
            self.currentGroup?.delegate = self
            self.currentGroup?.load()
            self.threadView.reloadData()
        }
    }

    private func threadForIndexPath(indexPath: NSIndexPath) -> Article? {
        guard indexPath.section == 0 else {
            return nil
        }

        guard let roots = self.currentGroup?.roots else {
            return nil
        }

        return roots[indexPath.item]
    }

    private func indexPathForThread(article: Article) -> NSIndexPath? {
        guard let idx = self.currentGroup?.getIndexOfThread(article) else {
            return nil
        }

        return NSIndexPath(forItem: idx, inSection: 0)
    }

    private func indexPathsForThreads(articles: [Article]) -> Set<NSIndexPath> {
        var set = Set<NSIndexPath>()
        for article in articles {
            if let indexPath = self.indexPathForThread(article) {
                set.insert(indexPath)
            }
        }
        return set
    }

    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let roots = self.currentGroup?.roots else {
            return 0
        }

        return roots.count
    }

    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItemWithIdentifier("Thread", forIndexPath: indexPath)

        item.representedObject = self.threadForIndexPath(indexPath)
        return item
    }

    func collectionView(collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> NSSize {
        let size = collectionView.frame.size

        return NSSize(width: size.width, height: 74)
    }

    private func updateCurrentThread() {
        let selected = self.threadView.selectionIndexPaths

        if selected.count == 0 {
            self.articleViewController.currentThread = nil
        } else {
            self.articleViewController.currentThread = self.threadForIndexPath(selected.first!)
        }
    }

    func collectionView(collectionView: NSCollectionView, didSelectItemsAtIndexPaths indexPaths: Set<NSIndexPath>) {
        self.updateCurrentThread()
    }

    func collectionView(collectionView: NSCollectionView, didDeselectItemsAtIndexPaths indexPaths: Set<NSIndexPath>) {
        self.updateCurrentThread()
    }
}

extension ThreadViewController : GroupDelegate {
    func group(group: Group, willLoseThreads articles: [Article]) {
        let set = self.indexPathsForThreads(articles)

        if set.count > 0 {
            self.threadView.deleteItemsAtIndexPaths(set)
        }
    }

    func group(group: Group, hasNewThreads articles: [Article]) {
        let set = self.indexPathsForThreads(articles)

        if set.count > 0 {
            self.threadView.insertItemsAtIndexPaths(set)
        }
    }
}