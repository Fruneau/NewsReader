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
    private var head : FifoNode<T>?
    private var tail : FifoNode<T>?

    public init() {
    }

    public var isEmpty : Bool {
        return self.head == nil
    }

    public func push(object: T) {
        let node = FifoNode(object: object)

        if self.head == nil {
            self.head = node
            self.tail = node
        } else {
            self.tail!.next = node
            self.tail = node
        }
    }

    public func pop() -> T? {
        if let node = self.head {
            self.head = node.next

            if self.head == nil {
                self.tail = nil
            }
            return node.object
        }
        return nil
    }

    public func clear() {
        self.head = nil
        self.tail = nil
    }
}