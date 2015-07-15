//
//  FifoQueue.swift
//  NewsReader
//
//  Created by Florent Bruneau on 15/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

private class FifoNode<T> {
    let object : T
    var next : FifoNode<T>?

    init(object: T) {
        self.object = object
    }
}

public class FifoQueue<T> {
    private var headNode : FifoNode<T>?
    private var tailNode : FifoNode<T>?

    public init() {
    }

    public var isEmpty : Bool {
        return self.headNode == nil
    }

    public func push(object: T) {
        let node = FifoNode(object: object)

        if self.headNode == nil {
            self.headNode = node
            self.tailNode = node
        } else {
            self.tailNode!.next = node
            self.tailNode = node
        }
    }

    public func pop() -> T? {
        if let node = self.headNode {
            self.headNode = node.next

            if self.headNode == nil {
                self.tailNode = nil
            }
            return node.object
        }
        return nil
    }

    public func clear() {
        self.headNode = nil
        self.tailNode = nil
    }

    public var head : T? {
        return self.headNode?.object
    }

    public var tail : T? {
        return self.tailNode?.object
    }
}