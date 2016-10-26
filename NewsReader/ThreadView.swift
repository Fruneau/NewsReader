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
    fileprivate func updateThreadCountViewVisibility() {
        guard let article = self.representedObject as? Article else {
            return
        }

        self.threadHasReplies = article.threadCount > 1
    }

    var threadCountChangeCtx = 0;
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch context {
        case (&self.threadCountChangeCtx)?:
            self.updateThreadCountViewVisibility()

        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    override var representedObject : Any? {
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

    override var isSelected : Bool {
        didSet {
            if self.isSelected {
                self.textColor = NSColor.alternateSelectedControlTextColor
                self.backgroundColor = NSColor.alternateSelectedControlColor
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
        self.view.bind("backgroundColor", to: self, withKeyPath: "backgroundColor", options: nil)
    }
}

class ThreadViewController : NSViewController {
    override class func initialize() {
        self.exposeBinding("selection")
    }

    fileprivate var threadView : NSCollectionView {
        return self.view as! NSCollectionView
    }

    var currentGroup : Group? {
        return self.representedObject as? Group
    }

    dynamic var selection : Article?

    override dynamic var representedObject : Any? {
        willSet {
            self.currentGroup?.delegate = nil
            self.selection = nil
        }

        didSet {
            self.currentGroup?.delegate = self
            self.currentGroup?.load()
            self.threadView.reloadData()
        }
    }

    fileprivate func updateCurrentThread() {
        let selected = self.threadView.selectionIndexPaths

        if selected.count == 0 {
            self.selection = nil
        } else {
            self.selection = self.threadForIndexPath(selected.first!)
        }
    }

    fileprivate func threadForIndexPath(_ indexPath: IndexPath) -> Article? {
        guard (indexPath as NSIndexPath).section == 0 else {
            return nil
        }

        guard let roots = self.currentGroup?.roots else {
            return nil
        }

        return roots[(indexPath as NSIndexPath).item]
    }

    fileprivate func indexPathForThread(_ article: Article) -> IndexPath? {
        guard let idx = self.currentGroup?.getIndexOfThread(article) else {
            return nil
        }

        return IndexPath(item: idx, section: 0)
    }

    fileprivate func indexPathsForThreads(_ articles: [Article]) -> Set<IndexPath> {
        var set = Set<IndexPath>()
        for article in articles {
            if let indexPath = self.indexPathForThread(article) {
                set.insert(indexPath)
            }
        }
        return set
    }
}

extension ThreadViewController : NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let roots = self.currentGroup?.roots else {
            return 0
        }

        return roots.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: "Thread", for: indexPath)

        item.representedObject = self.threadForIndexPath(indexPath)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> NSSize {
        let size = collectionView.frame.size

        return NSSize(width: size.width, height: 74)
    }
}

extension ThreadViewController : NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        self.updateCurrentThread()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        self.updateCurrentThread()
    }
}

extension ThreadViewController : GroupDelegate {
    func group(_ group: Group, willLoseThreads articles: [Article]) {
        let set = self.indexPathsForThreads(articles)

        if set.count > 0 {
            self.threadView.deleteItems(at: set)
        }
    }

    @objc(group:hasNewThreads:) func group(_ group: Group, hasNewThreads articles: [Article]) {
        let set = self.indexPathsForThreads(articles)

        if set.count > 0 {
            self.threadView.insertItems(at: set)
        }
    }
}
