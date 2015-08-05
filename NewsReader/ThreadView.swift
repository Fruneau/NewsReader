//
//  ThreadView.swift
//  NewsReader
//
//  Created by Florent Bruneau on 05/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class ThreadViewItem : SelectableCollectionViewItem {
    @IBOutlet weak var fromView: NSTextField!
    @IBOutlet weak var dateView: NSTextField!
    @IBOutlet weak var subjectView: NSTextField!
    @IBOutlet weak var threadCountView: NSTextField!

    override var representedObject : AnyObject? {
        didSet {
            let article = self.representedObject as? Article

            self.fromView.objectValue = article?.from
            self.dateView.objectValue = article?.date
            self.subjectView.objectValue = article?.subject
            self.threadCountView.objectValue = article?.threadCount
        }
    }
}

class ThreadViewController : NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    @IBOutlet weak var threadView: NSCollectionView!
    @IBOutlet weak var articleViewController: ArticleViewController!

    var currentGroup : GroupTree? {
        /*
        willSet {
            if newValue === self.currentGroup {
                return
            }

            self.currentGroup?.delegate = nil
            var paths = Set<NSIndexPath>()
            if let roots = self.currentGroup?.roots {
                for i in 0..<roots.count {
                    paths.insert(NSIndexPath(forItem: i, inSection: 0))
                }
            }

            if paths.count > 0 {
                self.threadView.deleteItemsAtIndexPaths(paths)
            }
        }
        */

        didSet {
            if oldValue === self.currentGroup {
                return
            }

            print("set to \(self.currentGroup) from \(oldValue)")
            self.currentGroup?.delegate = self
            self.currentGroup?.load()
            self.threadView.reloadData()

            /*
            var paths = Set<NSIndexPath>()
            if let roots = self.currentGroup?.roots {
                for i in 0..<roots.count {
                    paths.insert(NSIndexPath(forItem: i, inSection: 0))
                }
            }

            if paths.count > 0 {
                self.threadView.insertItemsAtIndexPaths(paths)
            }
            */
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
        guard let idx = self.currentGroup?.roots?.indexOf(article) else {
            return nil
        }

        return NSIndexPath(forItem: idx, inSection: 0)
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

        return NSSize(width: size.width, height: 37)
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

extension ThreadViewController : GroupTreeDelegate {
    func groupTree(groupTree: GroupTree, hasNewThreads articles: [Article]) {
        var indexPaths = Set<NSIndexPath>()
        for article in articles {
            if let indexPath = self.indexPathForThread(article) {
                indexPaths.insert(indexPath)
            }
        }

        if indexPaths.count > 0 {
            self.threadView.reloadData()
            //self.threadView.insertItemsAtIndexPaths(indexPaths)
        }
    }
}