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

/**
 Payload on a stream

 For example, response to a request, or message on a channel.
 */
public struct Payload: Hashable {
    /// Optional metadata of this payload
    public var metadata: Data?

    /// Payload for Reactive Streams `onNext`
    public var data: Data

    public init(
        metadata: Data? = nil,
        data: Data
    ) {
        self.metadata = metadata
        self.data = data
    }
}

// Payload implements `CustomStringConvertible` instead of `CustomDebugStringConvertible` to allow `RSocketTestUtilities` to customize the debug output.
extension Payload: CustomStringConvertible {
    public var description: String {
        if metadata == nil && data.isEmpty {
            return ".empty"
        }
        return "Payload(metadata: \(metadata?.debugDescription ?? "nil"), data: \(data.debugDescription))"
    }
}
