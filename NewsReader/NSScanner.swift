//
//  NSScanner.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

extension NSScanner {
    var remainder : String {
        return (self.string as NSString).substringToIndex(self.scanLocation)
    }
}