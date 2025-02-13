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

import ReactiveSwift
import RSocketCore

public protocol RequesterRSocket {
    func callAsFunction<Metadata>(_ metadataPush: MetadataPush<Metadata>, metadata: Metadata) throws

    func callAsFunction<Request>(_ fireAndForget: FireAndForget<Request>, request: Request) throws

    func callAsFunction<Request, Response>(
        _ requestResponse: RequestResponse<Request, Response>,
        request: Request
    ) -> SignalProducer<Response, Swift.Error>

    func callAsFunction<Request, Response>(
        _ requestStream: RequestStream<Request, Response>,
        request: Request
    ) -> SignalProducer<Response, Swift.Error>

    func callAsFunction<Request, Response>(
        _ requestChannel: RequestChannel<Request, Response>,
        initialRequest: Request,
        producer: SignalProducer<Request, Swift.Error>?
    ) -> SignalProducer<Response, Swift.Error>
}
