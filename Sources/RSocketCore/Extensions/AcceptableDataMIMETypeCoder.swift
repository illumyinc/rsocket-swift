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
import NIO

public struct AcceptableDataMIMETypeEncoder: MetadataEncoder {
    public typealias Metadata = [MIMEType]
    public static let defaultWellKnownMimeTypes = Dictionary(
        uniqueKeysWithValues: MIMEType.wellKnownMIMETypes.lazy.map { ($0.1, $0.0) }
    )

    @usableFromInline
    internal let wellKnownMimeTypes: [MIMEType: WellKnownMIMETypeCode]

    @inlinable
    public var mimeType: MIMEType { .messageXRSocketMimeTypeV0 }

    @usableFromInline
    internal let mimeTypeEncoder: MIMETypeEncoder

    @inlinable
    public init(
        wellKnownMimeTypes: [MIMEType: WellKnownMIMETypeCode] = defaultWellKnownMimeTypes,
        mimeTypeEncoder: MIMETypeEncoder = MIMETypeEncoder()
    ) {
        self.mimeTypeEncoder = mimeTypeEncoder
        self.wellKnownMimeTypes = wellKnownMimeTypes
    }

    @inlinable
    public func encode(_ metadata: Metadata, into buffer: inout ByteBuffer) throws {
        for mimeType in metadata {
            guard let wellKnownMimeTypeCode = wellKnownMimeTypes[mimeType] else { continue }
            buffer.writeInteger(wellKnownMimeTypeCode.rawValue)
        }
    }
}

public extension MetadataEncoder where Self == AcceptableDataMIMETypeEncoder {
    static var acceptableDataMIMEType: Self { .init() }
}

public struct AcceptableDataMIMETypeDecoder: MetadataDecoder {
    public typealias Metadata = [MIMEType]

    @inlinable
    public var mimeType: MIMEType { .messageXRSocketMimeTypeV0 }

    @usableFromInline
    internal let mimeTypeDecoder: MIMETypeEncoder

    @inlinable
    public init(mimeTypeDecoder: MIMETypeEncoder = MIMETypeEncoder()) {
        self.mimeTypeDecoder = mimeTypeDecoder
    }

    @inlinable
    public func decode(from buffer: inout ByteBuffer) throws -> Metadata {
        fatalError("not implemented")
    }
}

public extension MetadataDecoder where Self == AcceptableDataMIMETypeDecoder {
    static var acceptableDataMIMEType: Self { .init() }
}
