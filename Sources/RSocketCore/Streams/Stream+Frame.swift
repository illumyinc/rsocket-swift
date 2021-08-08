/*
 * Copyright 2015-present the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

extension Cancellable where Self: Extendable {
    internal func cancelable_receive(_ frame: Frame) -> Error? {
        switch frame.body {
        case .cancel:
            onCancel()
        case let .ext(body):
            onExtension(
                extendedType: body.extendedType,
                payload: body.payload,
                canBeIgnored: body.canBeIgnored
            )
        default:
            if !frame.body.canBeIgnored {
                return .connectionError(message: "Invalid frame type \(frame.body.type) for an active cancelable")
            }
        }
        return nil
    }
}

extension Cancellable where Self: Subscriber, Self: Extendable {
    internal func promise_receive(_ frame: Frame) -> Error? {
        switch frame.body {
        case .cancel:
            onCancel()
        case let .error(body):
            onError(body.error)
        case let .ext(body):
            onExtension(
                extendedType: body.extendedType,
                payload: body.payload,
                canBeIgnored: body.canBeIgnored
            )
        case let .payload(body):
            onNext(body.payload, isComplete: true)
            onComplete()
        default:
            if !frame.body.canBeIgnored {
                return .connectionError(message: "Invalid frame type \(frame.body.type) for an active response stream")
            }
        }
        return nil
    }
}

extension Subscription where Self: Cancellable, Self: Extendable{
    internal func subscription_receive(_ frame: Frame) -> Error? {
        switch frame.body {
        case let .requestN(body):
            onRequestN(body.requestN)
        case .cancel:
            onCancel()
        case let .ext(body):
            onExtension(
                extendedType: body.extendedType,
                payload: body.payload,
                canBeIgnored: body.canBeIgnored
            )
        default:
            if !frame.body.canBeIgnored {
                return .connectionError(message: "Invalid frame type \(frame.body.type) for an active subscription")
            }
        }
        return nil
    }
}

extension Subscriber where Self: Cancellable, Self: Extendable, Self: Subscription {
    internal func stream_receive(_ frame: Frame) -> Error? {
        switch frame.body {
        case let .requestN(body):
            onRequestN(body.requestN)
        case .cancel:
            onCancel()
        case let .payload(body):
            //assert(!body.isNext && body.payload.metadata == nil && body.payload.data.isEmpty, "isNext is false but payload contains data")
            if body.isNext {
                onNext(body.payload, isComplete: body.isCompletion)
            }
            if body.isCompletion {
                onComplete()
            }
        case let .error(body):
            onError(body.error)

        case let .ext(body):
            onExtension(
                extendedType: body.extendedType,
                payload: body.payload,
                canBeIgnored: body.canBeIgnored
            )
        default:
            if !frame.body.canBeIgnored {
                return .connectionError(message: "Invalid frame type \(frame.body.type) for an active unidirectional stream")
            }
        }
        return nil
    }
}
