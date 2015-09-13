//
//  GroupTokenDelegate.swift
//  NewsReader
//
//  Created by Florent Bruneau on 13/09/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

extension Account : NSTokenFieldDelegate {
}

/// Support token display
extension Account {
    func tokenField(tokenField: NSTokenField, displayStringForRepresentedObject representedObject: AnyObject) -> String? {
        switch representedObject {
        case let g as Group:
            return g.fullName

        case let s as String:
            return s

        default:
            return nil
        }
    }
}


/// Support token edition
extension Account {
    func tokenField(tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>) -> [AnyObject]? {
        selectedIndex.memory = -1

        var groups : [String] = []

        for group in self.groups.keys {
            if group.containsString(substring) {
                groups.append(group)
            }
        }
        return groups
    }

    func tokenField(tokenField: NSTokenField, editingStringForRepresentedObject representedObject: AnyObject) -> String? {
        return self.tokenField(tokenField, displayStringForRepresentedObject: representedObject)
    }

//    func tokenField(tokenField: NSTokenField, representedObjectForEditingString editingString: String) -> AnyObject {
//        if let group = self.groups[editingString] {
//            return group.fullName
//        }
//        return editingString
//    }
}