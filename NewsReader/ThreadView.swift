//
//  ThreadView.swift
//  NewsReader
//
//  Created by Florent Bruneau on 05/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

class ThreadViewItem : NSCollectionViewItem {
    @IBOutlet weak var threadView: BackgroundView!
    @IBOutlet weak var fromView: NSTextField!
    @IBOutlet weak var fromCell: NSTextFieldCell!
    @IBOutlet weak var dateView: NSTextField!
    @IBOutlet weak var dateCell: NSTextFieldCell!
    @IBOutlet weak var subjectView: NSTextField!
    @IBOutlet weak var subjectCell: NSTextFieldCell!
    @IBOutlet weak var threadCountView: NSTextField!
    @IBOutlet weak var threadCountCell: NSTextFieldCell!
    @IBOutlet weak var arrowView: NSTextField!
    @IBOutlet weak var arrowCell: NSTextFieldCell!
    @IBOutlet weak var unreadMark: NSImageView!

    override var representedObject : AnyObject? {
        didSet {
            let article = self.representedObject as? Article

            self.fromView.objectValue = article?.from
            self.dateView.objectValue = article?.date
            self.subjectView.objectValue = article?.subject
            self.threadCountView.objectValue = article?.threadCount

            if article?.threadCount == 1 {
                self.threadCountView.hidden = true
                self.arrowView.hidden = true
            } else {
                self.threadCountView.hidden = false
                self.arrowView.hidden = false
            }
        }
    }

    private var threadCountColor : NSColor?
    override func awakeFromNib() {
        self.threadCountColor = self.threadCountCell.textColor
    }

    override var selected : Bool {
        didSet {
            if oldValue == self.selected {
                return
            }

            if self.selected {
                self.threadView.backgroundColor = NSColor.alternateSelectedControlColor()
                self.fromCell.textColor = NSColor.alternateSelectedControlTextColor()
                self.dateCell.textColor = NSColor.alternateSelectedControlTextColor()
                self.subjectCell.textColor = NSColor.alternateSelectedControlTextColor()
                self.threadCountCell.textColor = NSColor.alternateSelectedControlTextColor()
                self.arrowCell.textColor = NSColor.alternateSelectedControlTextColor()

                self.unreadMark.image = NSImage(named: "unread-selected")
            } else {
                self.threadView.backgroundColor = NSColor.whiteColor()
                self.fromCell.textColor = NSColor.labelColor()
                self.dateCell.textColor = NSColor.secondaryLabelColor()
                self.subjectCell.textColor = NSColor.labelColor()
                self.threadCountCell.textColor = self.threadCountColor
                self.arrowCell.textColor = self.threadCountColor

                self.unreadMark.image = NSImage(named: "unread")
            }
        }
    }
}

class ThreadViewController : NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    @IBOutlet weak var threadView: NSCollectionView!
    @IBOutlet weak var articleViewController: ArticleViewController!

    var currentGroup : Group? {
        willSet {
            if newValue === self.currentGroup {
                return
            }

            self.currentGroup?.delegate = nil
            if let roots = self.currentGroup?.roots {
                var paths = Set<NSIndexPath>()

                for i in 0..<roots.count {
                    paths.insert(NSIndexPath(forItem: i, inSection: 0))
                }

                if paths.count > 0 {
                    self.threadView.deleteItemsAtIndexPaths(paths)
                }
            }
        }

        didSet {
            if oldValue === self.currentGroup {
                return
            }

            print("set to \(self.currentGroup) from \(oldValue)")
            self.currentGroup?.delegate = self
            self.currentGroup?.load()
            //self.threadView.reloadData()

            if let roots = self.currentGroup?.roots {
                var paths = Set<NSIndexPath>()

                for i in 0..<roots.count {
                    paths.insert(NSIndexPath(forItem: i, inSection: 0))
                }

                if paths.count > 0 {
                    self.threadView.insertItemsAtIndexPaths(paths)
                }
            }
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

        return NSSize(width: size.width, height: 64)
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
    func groupTree(groupTree: Group, hasNewThreads articles: [Article]) {
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