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

public protocol DecoderProtocol {
    associatedtype Metadata
    associatedtype Data
    mutating func decode(
        _ payload: Payload,
        encoding: ConnectionEncoding
    ) throws -> (Metadata, Data)
}

public struct Decoder: DecoderProtocol {
    @inlinable
    public init() {}
    
    @inlinable
    public func decode(
        _ payload: Payload, 
        encoding: ConnectionEncoding
    ) throws -> (Data?, Data) {
        (payload.metadata, payload.data)
    }
}

extension DecoderProtocol where Metadata == Void {
    @inlinable
    public mutating func decode(
        _ payload: Payload,
        encoding: ConnectionEncoding
    ) throws -> Data {
        try decode(payload, encoding: encoding).1
    }
}

/// Namespace for types conforming to the ``DecoderProtocol`` protocol
public enum Decoders {}
