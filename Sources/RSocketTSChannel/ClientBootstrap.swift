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

#if canImport(Network)

import Network
import NIO
import NIOTransportServices
import RSocketCore

@available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
final public class ClientBootstrap<Transport: TransportChannelHandler> {
    private let group = NIOTSEventLoopGroup()
    private let bootstrap: NIOTSConnectionBootstrap
    public let config: ClientConfiguration
    private let transport: Transport
    private let tlsOptions: NWProtocolTLS.Options?
    public init(
        transport: Transport,
        config: ClientConfiguration,
        timeout: TimeAmount = .seconds(30),
        tlsOptions: NWProtocolTLS.Options? = nil
    ) {
        self.config = config
        bootstrap = NIOTSConnectionBootstrap(group: group)
            .connectTimeout(timeout)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        self.transport = transport
        self.tlsOptions = tlsOptions
    }

    @discardableResult
    public func configure(bootstrap configure: (NIOTSConnectionBootstrap) -> NIOTSConnectionBootstrap) -> Self {
        _ = configure(bootstrap)
        return self
    }
}

@available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
extension ClientBootstrap: RSocketCore.ClientBootstrap {
    static func makeDefaultTLSOptions() -> NWProtocolTLS.Options {
        .init()
    }
    public func connect(
        to endpoint: Transport.Endpoint,
        payload: Payload,
        responder: RSocketCore.RSocket?
    ) -> EventLoopFuture<CoreClient> {
        let requesterPromise = group.next().makePromise(of: RSocketCore.RSocket.self)

        if tlsOptions != nil || endpoint.requiresTLS {
            let options = tlsOptions ?? Self.makeDefaultTLSOptions()
            _ = bootstrap.tlsOptions(options)
        }

        let connectFuture = bootstrap
            .channelInitializer { [config, transport] channel in
                transport.addChannelHandler(
                    channel: channel,
                    maximumIncomingFragmentSize: config.fragmentation.maximumIncomingFragmentSize,
                    endpoint: endpoint,
                    upgradeComplete:{
                    channel.pipeline.addRSocketClientHandlers(
                        config: config,
                        setupPayload: payload,
                        responder: responder,
                        connectedPromise: requesterPromise
                    )
                    },resultHandler: { result in
                        if case .failure(let error) = result {
                            requesterPromise.fail(error)
                            return requesterPromise.futureResult.eventLoop.makeFailedFuture(error)
                        }
                       return channel.pipeline.addRSocketClientHandlers(
                            config: config,
                            setupPayload: payload,
                            responder: responder,
                            connectedPromise: requesterPromise
                        )
                    })
            }
            .connect(host: endpoint.host, port: endpoint.port)

        connectFuture.cascadeFailure(to: requesterPromise)
        return connectFuture.flatMap { channel in
            requesterPromise.futureResult.map { socket in
                // initializing core client using channel object
                return CoreClient.init(requester: socket, channel: channel)
            }
        }
    }
}

#endif
