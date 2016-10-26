//
//  NSScanner.swift
//  NewsReader
//
//  Created by Florent Bruneau on 14/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

extension Scanner {
    public var remainder : String {
        return (self.string as NSString).substring(to: self.scanLocation)
    }

    public func skipCharactersFromSet(_ set: CharacterSet) -> Bool {
        var padding : NSString?

        return self.scanCharacters(from: set, into: &padding)
    }

    public func skipString(_ string: String) -> Bool {
        var padding : NSString?

        return self.scanString(string, into: &padding)
    }
}
