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

import NIO
import Foundation

public protocol MetadataDecoder: CompositeMetadataDecoder {
    associatedtype Metadata
    var mimeType: MIMEType { get }
    func decode(from buffer: inout ByteBuffer) throws -> Metadata
}

extension MetadataDecoder {
    @inlinable
    public func decode(from data: Data) throws -> Metadata {
        var buffer = ByteBuffer(data: data)
        let metadata = try self.decode(from: &buffer)
        guard buffer.readableBytes == 0 else {
            throw Error.invalid(message: "\(Self.self) did not read all bytes")
        }
        return metadata
    }
}

extension MetadataDecoder {
    @inlinable
    public func decode(from compositeMetadata: [CompositeMetadata]) throws -> Metadata {
        try compositeMetadata.decodeFirst(using: self)
    }
}
