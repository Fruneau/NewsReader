//
//  NSData.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

extension NSData {
    public var utf8String : String? {
        return NSString(bytes: self.bytes, length: self.length, encoding: NSUTF8StringEncoding) as String?
    }
}