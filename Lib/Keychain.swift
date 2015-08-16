//
//  Keychain.swift
//  NewsReader
//
//  Created by Florent Bruneau on 16/08/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

public struct KeychainError : ErrorType {
    public let status : OSStatus
    public let textualStatus : String

    init(status: OSStatus) {
        self.status = status

        let str = SecCopyErrorMessageString(status, nil)
        self.textualStatus = String(str)
    }
}

public enum PasswordError : ErrorType {
    case BadEncoding
}

public struct KeychainItem {
    private let item : SecKeychainItem

    public func changePassword(password: String) throws {
        var status : OSStatus = 0

        password.withCString {
            (cPassword) in

            status = SecKeychainItemModifyAttributesAndData(self.item, nil, UInt32(strlen(cPassword)), cPassword)
        }

        switch status {
        case 0:
            return

        default:
            throw KeychainError(status: status)
        }
    }
}

public struct Keychain {
    static public func addGenericPassword(serviceName: String, accountName: String, password: String) throws -> KeychainItem {
        var status : OSStatus = 0
        var item : SecKeychainItem? = nil

        serviceName.withCString {
            (cService) in

            accountName.withCString {
                (cAccount) in

                password.withCString {
                    (cPassword) in

                    status = SecKeychainAddGenericPassword(nil, UInt32(strlen(cService)), cService, UInt32(strlen(cAccount)), cAccount, UInt32(strlen(cPassword)), cPassword, &item)
                }
            }
        }

        switch status {
        case 0:
            return KeychainItem(item: item!)

        default:
            throw KeychainError(status: status)
        }
    }

    static public func findGenericPassowrd(serviceName: String, accountName: String) throws -> (String, KeychainItem) {
        var status : OSStatus = 0
        var item : SecKeychainItem? = nil
        var passwordLength : UInt32 = 0
        var passwordData : UnsafeMutablePointer<Void> = nil

        serviceName.withCString {
            (cService) in

            accountName.withCString {
                (cAccount) in

                status = SecKeychainFindGenericPassword(nil, UInt32(strlen(cService)), cService, UInt32(strlen(cAccount)), cAccount, &passwordLength, &passwordData, &item)
            }
        }

        switch status {
        case 0:
            let password = NSString(bytes: passwordData, length: Int(passwordLength), encoding: NSUTF8StringEncoding)

            SecKeychainItemFreeContent(nil, passwordData)
            if password == nil {
                throw PasswordError.BadEncoding
            }


            return (password! as String, KeychainItem(item: item!))

        default:
            throw KeychainError(status: status)
        }
    }
}