//
//  Promise.swift
//  NewsReader
//
//  Created by Florent Bruneau on 18/07/2015.
//  Copyright © 2015 Florent Bruneau. All rights reserved.
//

import Foundation

private enum State<T> {
    case Success(T)
    case Error(ErrorType)
    case Cancelled
    case Running
}

public enum PromiseError : ErrorType {
    case UncaughtError(ErrorType, Int)
    case Cancelled
}

private struct PromiseHandler<T> {
    private typealias SuccessHandler = (T) throws -> Void
    private typealias ErrorHandler = (ErrorType) throws -> Void

    private let successHandler : SuccessHandler?
    private let errorHandler : ErrorHandler?
    private let onSuccess : (Void) -> Void
    private let onError : (ErrorType) -> Void

    private func succeed(arg: T) {
        do {
            try self.successHandler?(arg)
            self.onSuccess()
        } catch let e {
            self.onError(e)
        }
    }

    private func fail(res: ErrorType) {
        if let errorHandler = self.errorHandler {
            do {
                try errorHandler(res)
                self.onSuccess()
            } catch let e {
                self.onError(e)
            }
        } else {
            switch (res) {
            case PromiseError.UncaughtError(let sub, let depth):
                self.onError(PromiseError.UncaughtError(sub, depth + 1))

            default:
                self.onError(PromiseError.UncaughtError(res, 1))
            }
        }
    }
}

public class Promise<T> {
    public typealias SuccessHandler = (T) throws -> Void
    public typealias ErrorHandler = (ErrorType) throws -> Void

    public typealias Constructor = ((T) -> Void, (ErrorType) -> Void) throws -> Void
    public typealias Cancellor = (Void) -> Void

    private var handlers : [PromiseHandler<T>] = []
    private var state = State<T>.Running
    private let onCancel : Cancellor?

    private init(action: Constructor, onOptCancel: Cancellor?) {
        self.onCancel = onOptCancel
        do {
            try action(self.onSuccess, self.onError)
        } catch let e {
            self.onError(e)
        }
    }

    public convenience init(action: Constructor) {
        self.init(action: action, onOptCancel: nil)
    }

    public convenience init(action: Constructor, onCancel: Cancellor) {
        self.init(action: action, onOptCancel: onCancel)
    }

    public convenience init(success: T) {
        self.init(action: {
            (onSuccess, onError) in

            onSuccess(success)
        })
    }

    public convenience init(failed failure: ErrorType) {
        self.init(action: {
            (onSuccess, onError) in

            onError(failure)
        })
    }

    private func onSuccess(res: T) {
        switch (self.state) {
        case .Running:
            self.state = .Success(res)
            for handler in self.handlers {
                handler.succeed(res)
            }
            self.handlers.removeAll()

        case .Cancelled:
            break

        default:
            assert (false)
        }
    }

    private func onError(res: ErrorType) {
        switch (self.state) {
        case .Running:
            self.state = .Error(res)
            for handler in self.handlers {
                handler.fail(res)
            }
            self.handlers.removeAll()

        case .Cancelled:
            break

        default:
            assert (false)
        }
    }

    public func cancel() {
        switch (self.state) {
        case .Running:
            self.state = .Cancelled
            self.onCancel?()
            for handler in self.handlers {
                handler.fail(PromiseError.Cancelled)
            }
            self.handlers.removeAll()

        default:
            break
        }
    }

    private func registerHandler(success: SuccessHandler?, error: ErrorHandler?) -> Promise<Void> {
        var ph : PromiseHandler<T>?
        let promise = Promise<Void>() {
            (onSuccess, onError) in

            ph = PromiseHandler(successHandler: success, errorHandler: error, onSuccess: onSuccess, onError: onError)
        }

        assert (ph != nil)

        switch (self.state) {
        case .Success(let result):
            ph?.succeed(result)

        case .Error(let result):
            ph?.fail(result)

        case .Cancelled:
            ph?.fail(PromiseError.Cancelled)

        case .Running:
            self.handlers.append(ph!)
        }
        return promise
    }

    public func then(handler: SuccessHandler) -> Promise<Void> {
        return self.registerHandler(handler, error: nil)
    }

    public func then(handler: SuccessHandler, otherwise: ErrorHandler) -> Promise<Void> {
        return self.registerHandler(handler, error: otherwise)
    }

    public func otherwise(handler: ErrorHandler) -> Promise<Void> {
        return self.registerHandler(nil, error: handler)
    }

    public func thenChain<OnSubSuccess>(handler: (T) throws -> Promise<OnSubSuccess>) -> Promise<OnSubSuccess> {
        return Promise<OnSubSuccess>() {
            (onSubSuccess, onSubError) in
            self.then() {
                (result) in

                do {
                    let promise = try handler(result)
                    promise.then(onSubSuccess, otherwise: onSubError)
                } catch let e {
                    onSubError(e)
                }
            }
        }
    }

    public func otherwiseChain<OnSubSuccess>(handler: (ErrorType) throws -> Promise<OnSubSuccess>) -> Promise<OnSubSuccess> {
        return Promise<OnSubSuccess>() {
            (onSubSuccess, onSubError) in
            self.otherwise() {
                (result) in

                do {
                    let promise = try handler(result)
                    promise.then(onSubSuccess, otherwise: onSubError)
                } catch let e {
                    onSubError(e)
                }
            }
        }
    }
}