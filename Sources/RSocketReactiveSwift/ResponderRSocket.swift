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


import Foundation
import ReactiveSwift
import RSocketCore

public protocol ResponderRSocket {
    func metadataPush(metadata: Data)
    func fireAndForget(payload: Payload)
    func requestResponse(payload: Payload) -> SignalProducer<Payload, Swift.Error>
    func requestStream(payload: Payload) -> SignalProducer<Payload, Swift.Error>
    func requestChannel(
        payload: Payload,
        payloadProducer: SignalProducer<Payload, Swift.Error>?
    ) -> SignalProducer<Payload, Swift.Error>
}

public typealias Payload = RSocketCore.Payload

public typealias Error = RSocketCore.Error
