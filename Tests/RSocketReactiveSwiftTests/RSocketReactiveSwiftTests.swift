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

import XCTest
import NIOCore
import ReactiveSwift
import RSocketCore
import RSocketTestUtilities
import NIOEmbedded
@testable import RSocketReactiveSwift
extension ByteBuffer: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(string: value)
    }
}

func setup(
    server: RSocketReactiveSwift.ResponderRSocket? = nil,
    client: RSocketReactiveSwift.ResponderRSocket? = nil
) -> (server: ReactiveSwiftClient, client: ReactiveSwiftClient) {
    let (server, client) = TestDemultiplexer.pipe(
        serverResponder: server.map { ResponderAdapter(responder:$0, encoding: .default) },
        clientResponder: client.map { ResponderAdapter(responder:$0, encoding: .default) }
    )
    /**
     EmbeddedChannel() is a mock channel class using for unit testing .
     calling connect will active the channel
        */
    let serverChannel = EmbeddedChannel()
    XCTAssertNoThrow(try serverChannel.connect(to: SocketAddress.init(ipAddress: "127.0.0.1", port: 0)).wait())
    let clientChannel = EmbeddedChannel()
    XCTAssertNoThrow(try clientChannel.connect(to: SocketAddress.init(ipAddress: "127.0.0.1", port: 0)).wait())
    return (
        ReactiveSwiftClient(CoreClient(requester: server.requester, channel: serverChannel)),
        ReactiveSwiftClient(CoreClient(requester: client.requester, channel: clientChannel))
    )
}

final class RSocketReactiveSwiftTests: XCTestCase {
    func testMetadataPush() throws {
        let metadata = ByteBuffer(string: "Hello World")
        let didReceiveRequest = expectation(description: "did receive request")
        let serverResponder = TestRSocket(metadataPush: { data in
            didReceiveRequest.fulfill()
            XCTAssertEqual(data, metadata)
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel before core client get deinitialize
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        try client.requester.execute(MetadataPush(), metadata: metadata)
        self.wait(for: [didReceiveRequest], timeout: 0.1)
    }
    func testFireAndForget() throws {
        let didReceiveRequest = expectation(description: "did receive request")
        let serverResponder = TestRSocket(fireAndForget: { payload in
            didReceiveRequest.fulfill()
            XCTAssertEqual(payload, "Hello World")
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        try client.requester.execute(FireAndForget(), request: "Hello World")
        self.wait(for: [didReceiveRequest], timeout: 0.1)
    }
    func testRequestResponse() {
        let didReceiveRequest = expectation(description: "did receive request")
        let didReceiveResponse = expectation(description: "did receive response")
        
        let serverResponder = TestRSocket(requestResponse: { payload -> SignalProducer<Payload, Swift.Error> in
            didReceiveRequest.fulfill()
            XCTAssertEqual(payload, "Hello World")
            return SignalProducer { observer, lifetime in
                observer.send(value: "Hello World!")
                observer.send(value: "Hello World!")
                observer.send(value: "Hello World!")
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let disposable = client.requester.build(
            RequestResponse(),
            request: "Hello World"
        ).startWithSignal { signal, _ in
            signal.flatMapError({ error in
                XCTFail("\(error)")
                return .empty
            }).collect().observeValues { values in
                didReceiveResponse.fulfill()
                XCTAssertEqual(values, ["Hello World!"])
            }
        }
        self.wait(for: [didReceiveRequest, didReceiveResponse], timeout: 0.1)
        disposable?.dispose()
    }
    func testRequestResponseWithMisbehavingResponderSignalProducerWhichSendsTwoValuesInsteadOfOne() {
        let didReceiveRequest = expectation(description: "did receive request")
        let didReceiveResponse = expectation(description: "did receive response")
        
        let serverResponder = TestRSocket(requestResponse: { payload -> SignalProducer<Payload, Swift.Error> in
            didReceiveRequest.fulfill()
            XCTAssertEqual(payload, "Hello World")
            return SignalProducer { observer, lifetime in
                observer.send(value: "Hello World!")
                observer.send(value: "one value two much")
                observer.sendCompleted()
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let disposable = client.requester.build(
            RequestResponse(),
            request: "Hello World"
        ).startWithSignal { signal, _ in
            signal.flatMapError({ error in
                XCTFail("\(error)")
                return .empty
            }).collect().observeValues { values in
                didReceiveResponse.fulfill()
                XCTAssertEqual(values, ["Hello World!"])
            }
        }
        self.wait(for: [didReceiveRequest, didReceiveResponse], timeout: 0.1)
        disposable?.dispose()
    }
    func testRequestStream() {
        let didReceiveRequest = expectation(description: "did receive request")
        let didReceiveResponse = expectation(description: "did receive response")
        let serverResponder = TestRSocket(requestStream: { payload in
            didReceiveRequest.fulfill()
            XCTAssertEqual(payload, "Hello World")
            return SignalProducer { observer, lifetime in
                observer.send(value: "Hello")
                observer.send(value: " ")
                observer.send(value: "W")
                observer.send(value: "o")
                observer.send(value: "r")
                observer.send(value: "l")
                observer.send(value: "d")
                observer.send(value: "!")
                observer.sendCompleted()
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let disposable = client.requester.build(RequestStream(), request: "Hello World").startWithSignal { signal, _ in
            signal.flatMapError({ error in
                XCTFail("\(error)")
                return .empty
            }).collect().observeValues { values in
                didReceiveResponse.fulfill()
                XCTAssertEqual(values, ["Hello", " ", "W", "o", "r", "l", "d", "!"])
            }
        }
        self.wait(for: [didReceiveRequest, didReceiveResponse], timeout: 0.1)
        disposable?.dispose()
    }
    func testRequestChannel() {
        let didReceiveRequestChannel = expectation(description: "did receive request channel")
        let requesterDidSendChannelMessages = expectation(description: "requester did send channel messages")
        let responderDidSendChannelMessages = expectation(description: "responder did send channel messages")
        let responderDidReceiveChannelMessages = expectation(description: "responder did receive channel messages")
        let responderDidStartListeningChannelMessages = expectation(description: "responder did start listening to channel messages")
        let requesterDidReceiveChannelMessages = expectation(description: "requester did receive channel messages")
        let serverResponder = TestRSocket(requestChannel: { payload, producer in
            didReceiveRequestChannel.fulfill()
            XCTAssertEqual(payload, "Hello Responder")
            
            producer?.startWithSignal { signal, disposable in
                responderDidStartListeningChannelMessages.fulfill()
                signal.flatMapError({ error in
                    XCTFail("\(error)")
                    return .empty
                }).collect().observeValues { values in
                    responderDidReceiveChannelMessages.fulfill()
                    XCTAssertEqual(values, ["Hello", "from", "Requester", "on", "Channel"])
                    
                }
            }

            return SignalProducer { observer, lifetime in
                responderDidSendChannelMessages.fulfill()
                observer.send(value: "Hello")
                observer.send(value: "from")
                observer.send(value: "Responder")
                observer.send(value: "on")
                observer.send(value: "Channel")
                observer.sendCompleted()
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let disposable = client.requester.build(RequestChannel(), initialRequest: "Hello Responder", producer: .init({ observer, _ in
            requesterDidSendChannelMessages.fulfill()
            observer.send(value: "Hello")
            observer.send(value: "from")
            observer.send(value: "Requester")
            observer.send(value: "on")
            observer.send(value: "Channel")
            observer.sendCompleted()
        })).startWithSignal { signal, _ in
            signal.flatMapError({ error in
                XCTFail("\(error)")
                return .empty
            }).collect().observeValues { values in
                requesterDidReceiveChannelMessages.fulfill()
                XCTAssertEqual(values, ["Hello", "from", "Responder", "on", "Channel"])
            }
        }
        self.wait(for: [
            didReceiveRequestChannel,
            requesterDidSendChannelMessages,
            responderDidSendChannelMessages,
            responderDidStartListeningChannelMessages,
            responderDidReceiveChannelMessages,
            requesterDidReceiveChannelMessages,
        ], timeout: 0.1)
        disposable?.dispose()
    }
    // MARK: - Cancellation
    func testRequestResponseCancellation() {
        let didStartRequestSignal = expectation(description: "did start request signal")
        let didReceiveRequest = expectation(description: "did receive request")
        let didEndLifetimeOnResponder = expectation(description: "did end lifetime on responder")
        
        let serverResponder = TestRSocket(requestResponse: { payload -> SignalProducer<Payload, Swift.Error> in
            didReceiveRequest.fulfill()
            XCTAssertEqual(payload, "Hello World")
            return SignalProducer { observer, lifetime in
                lifetime.observeEnded {
                    _ = observer /// we need a strong reference to `observer`, otherwise the signal will be interrupted immediately
                    didEndLifetimeOnResponder.fulfill()
                }
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let disposable = client.requester.build(RequestResponse(), request: "Hello World").startWithSignal { signal, _ -> Disposable? in
            didStartRequestSignal.fulfill()
            return signal.flatMapError({ error -> Signal<ByteBuffer, Never> in
                XCTFail("\(error)")
                return .empty
            }).materialize().collect().observeValues { values in
                XCTFail("should not produce any event")
            }
        }
        self.wait(for: [didStartRequestSignal], timeout: 0.1)
        disposable?.dispose()
        self.wait(for: [didReceiveRequest, didEndLifetimeOnResponder], timeout: 0.1)
    }
    func testStreamCancellation() {
        let didStartRequestSignal = expectation(description: "did start request signal")
        let didReceiveRequest = expectation(description: "did receive request")
        let didEndLifetimeOnResponder = expectation(description: "did end lifetime on responder")
        
        let serverResponder = TestRSocket(requestStream: { payload -> SignalProducer<Payload, Swift.Error> in
            didReceiveRequest.fulfill()
            XCTAssertEqual(payload, "Hello World")
            return SignalProducer { observer, lifetime in
                lifetime.observeEnded {
                    _ = observer /// we need a strong reference to `observer`, otherwise the signal will be interrupted immediately
                    didEndLifetimeOnResponder.fulfill()
                }
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let disposable = client.requester.build(RequestStream(), request: "Hello World").startWithSignal { signal, _ -> Disposable? in
            didStartRequestSignal.fulfill()
            return signal.flatMapError({ error -> Signal<ByteBuffer, Never> in
                XCTFail("\(error)")
                return .empty
            }).materialize().collect().observeValues { values in
                XCTFail("should not produce any event")
            }
        }
        self.wait(for: [didStartRequestSignal], timeout: 0.1)
        disposable?.dispose()
        self.wait(for: [didReceiveRequest, didEndLifetimeOnResponder], timeout: 0.1)
    }
    func testRequestChannelCancellation() {
        let didReceiveRequestChannel = expectation(description: "did receive request channel")
        let responderDidStartSenderProducer = expectation(description: "responder did start sender producer")
        let responderDidStartListeningChannelMessages = expectation(description: "responder did start listening to channel messages")
        let responderProducerLifetimeEnded = expectation(description: "responder producer lifetime ended")
        
        let serverResponder = TestRSocket(requestChannel: { payload, producer in
            didReceiveRequestChannel.fulfill()
            XCTAssertEqual(payload, "Hello")

            producer?.startWithSignal { signal, disposable in
                responderDidStartListeningChannelMessages.fulfill()
                signal.flatMapError({ error -> Signal<Payload, Never> in
                    XCTFail("\(error)")
                    return .empty
                }).materialize().collect().observeValues { values in
                    XCTFail("should not produce any event")
                }
            }

            return SignalProducer { observer, lifetime in
                responderDidStartSenderProducer.fulfill()
                lifetime.observeEnded {
                    _ = observer
                    responderProducerLifetimeEnded.fulfill()
                }
            }
        })
        let (server, client) = setup(server: serverResponder)
        defer {
            // closing channel connection
            XCTAssertNoThrow(try client.shutdown().first()?.get())
            XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        let requesterDidStartListeningChannelMessages = expectation(description: "responder did start listening to channel messages")
        let payloadProducerLifetimeEnded = expectation(description: "payload producer lifetime ended")
        let requesterDidStartPayloadProducer = expectation(description: "requester did start payload producer")
        let disposable = client.requester.build(RequestChannel(), initialRequest: "Hello", producer: .init({ observer, lifetime in
            requesterDidStartPayloadProducer.fulfill()
            lifetime.observeEnded {
                _ = observer
                payloadProducerLifetimeEnded.fulfill()
            }
        })).startWithSignal { signal, _ -> Disposable? in
            requesterDidStartListeningChannelMessages.fulfill()
            return signal.flatMapError({ error -> Signal<ByteBuffer, Never> in
                XCTFail("\(error)")
                return .empty
            }).materialize().collect().observeValues { values in
                XCTFail("should not produce any event")
            }
        }
        self.wait(for: [
            didReceiveRequestChannel,
            requesterDidStartPayloadProducer,
            responderDidStartListeningChannelMessages,
            responderDidStartSenderProducer,
            requesterDidStartListeningChannelMessages,
        ], timeout: 0.1)
        disposable?.dispose()
        self.wait(for: [
            responderProducerLifetimeEnded,
            payloadProducerLifetimeEnded,
        ], timeout: 0.1)
    }
    /// test case for closing Rsocket connection using reactiveSwiftClient instance
    /// reactiveSwiftClient.dispose() closes the Rsocket connection
    func testConnectionDisposeSuccess() {
        let serverResponder = TestRSocket()
        let clientResponder = TestRSocket()
        let (server, client) = setup(server: serverResponder,client: clientResponder)
        defer {
            // closing channel connection
           XCTAssertNoThrow(try server.shutdown().first()?.get())
        }
        XCTAssertNotNil(server)
        XCTAssertNotNil(client)
        // checking if connection is active
        XCTAssertFalse(client.isDisposed)
        // closing connection using dispose method
        XCTAssertNoThrow(try client.shutdown().first()?.get())
        // checking if connection is inactive
        XCTAssertTrue(client.isDisposed)
    }
    func testConnectionDisposeListener() {
        // Creating expectation
        let didReceiveConnectionclosedEvent = expectation(description: "did receive Connection closed  event ")
        let serverResponder: RSocketReactiveSwift.ResponderRSocket? = TestRSocket()
        let clientResponder: RSocketReactiveSwift.ResponderRSocket? = TestRSocket()
        let (serverMultiplexer, clientMultiplexer) = TestDemultiplexer.pipe(
            serverResponder: serverResponder.map { ResponderAdapter(responder: $0, encoding: .default) },
            clientResponder: clientResponder.map { ResponderAdapter(responder: $0, encoding: .default) }
        )
        // Channel creation
        let serverChannel = EmbeddedChannel()
        // Making channel Active
        XCTAssertNoThrow(try serverChannel.connect(to: SocketAddress.init(ipAddress: "127.0.0.1", port: 0)).wait())
        let clientChannel = EmbeddedChannel()
        XCTAssertNoThrow(try clientChannel.connect(to: SocketAddress.init(ipAddress: "127.0.0.1", port: 0)).wait())
        // Creating Reactive swift client
        let server =  ReactiveSwiftClient(CoreClient(requester: serverMultiplexer.requester, channel: serverChannel))
        let client =  ReactiveSwiftClient(CoreClient(requester: clientMultiplexer.requester, channel: clientChannel))
        defer {
            // closing channel connection
            XCTAssertNoThrow(try serverChannel.finish())
        }
        XCTAssertNotNil(server)
        XCTAssertNotNil(client)
        // client connection closed event signal producer
        client.shutdownProducer.startWithSignal({ signal, interruptHandle in
            signal.flatMapError({ error -> Signal<Void, Error> in
                XCTFail("\(error)")
                return .empty
            }).materialize().collect().observeValues { values in
                didReceiveConnectionclosedEvent.fulfill()
            }
        })
        // checking if connection is active
        XCTAssertFalse(client.isDisposed)
        // closing connection using dispose method
        XCTAssertNoThrow(try clientChannel.finish())
        // checking if connection is inactive
        XCTAssertTrue(client.isDisposed)
        self.wait(for: [didReceiveConnectionclosedEvent], timeout: 0.1)
    }
}

