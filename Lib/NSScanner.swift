//
//  NSScanner.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

extension NSScanner {
    public var remainder : String {
        return (self.string as NSString).substringToIndex(self.scanLocation)
    }

    public func skipCharactersFromSet(set: NSCharacterSet) -> Bool {
        var padding : NSString?

        return self.scanCharactersFromSet(set, intoString: &padding)
    }

    public func skipString(string: String) -> Bool {
        var padding : NSString?

        return self.scanString(string, intoString: &padding)
    }
}