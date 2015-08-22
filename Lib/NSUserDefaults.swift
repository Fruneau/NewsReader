//
//  NSUserDefaults.swift
//  NewsReader
//
//  Created by Florent Bruneau on 22/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Cocoa

extension NSUserDefaults {
    private static func parsePath(path: String) -> [AnyObject]? {
        var res : [AnyObject] = []

        for objectField in path.characters.split(".") {
            let arrayFields = objectField.split("[")

            if arrayFields[0].count == 0 {
                return nil
            }

            res.append(String(arrayFields[0]))

            for field in arrayFields[1..<arrayFields.count] {
                if field.count < 2 {
                    return nil
                }

                var pos : Int = 0
                let scanner = NSScanner(string: String(field))
                if !scanner.scanInteger(&pos)
                || !scanner.skipString("]")
                || !scanner.atEnd
                {
                    return nil
                }

                if pos < 0 {
                    return nil
                }

                res.append(pos)
            }
        }

        return res
    }

    public func objectAtPath(path: String) -> AnyObject? {
        guard let elements = NSUserDefaults.parsePath(path) else {
            return nil
        }

        if elements.count == 0 {
            return self.dictionaryRepresentation()
        }

        var node = self.objectForKey(elements[0] as! String)

        for i in 1..<elements.count {
            switch (node, elements[i]) {
            case (nil, _):
                return nil

            case (let obj as NSDictionary, let objKey as String):
                node = obj[objKey]

            case (let array as NSArray, let arrayPos as Int):
                if arrayPos >= array.count {
                    return nil
                }
                node = array[arrayPos]

            default:
                return nil
            }
        }
        return node
    }

    public func setObject(obj: AnyObject, atPath path: String) {
        guard let elements = NSUserDefaults.parsePath(path) else {
            return
        }

        if elements.count == 0 {
            return
        }

        var root : AnyObject?
        var node = self.objectForKey(elements[0] as! String)?.mutableCopy()
        var prev : AnyObject?

        func setValue(value : AnyObject, at pos: AnyObject) {
            switch (prev, pos) {
            case (let obj as NSMutableDictionary, let objKey as String):
                obj[objKey] = value

            case (let array as NSMutableArray, let arrayPos as Int):
                while array.count < arrayPos - 1 {
                    array.addObject("")
                }
                array[arrayPos] = value

            default:
                assert (false)
            }
        }

        for i in 1..<elements.count {
            var next : AnyObject?

            switch (node, elements[i]) {
            case (nil, is String):
                node = NSMutableDictionary()
                break

            case (nil, is Int):
                node = NSMutableArray()
                break

            case (let obj as NSDictionary, let objKey as String):
                node = obj.mutableCopy()
                next = obj[objKey]

            case (let array as NSArray, let arrayPos as Int):
                node = array.mutableCopy()
                if arrayPos < array.count {
                    next = array[arrayPos]
                }

            default:
                assert (false)
            }

            if prev == nil {
                root = node
            } else {
                setValue(node!, at: elements[i - 1])
            }
            prev = node
            node = next
        }

        setValue(obj, at: elements.last!)
        self.setObject(root, forKey: elements.first! as! String)
    }
}