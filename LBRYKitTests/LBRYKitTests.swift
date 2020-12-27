//
//  LBRYKitTests.swift
//  LBRYKitTests
//
//  Copyright (c) 2020-2020 Ian Wang
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import XCTest
import Combine

@testable import LBRYKit

class LBRYKitTests: XCTestCase {
    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}
    
    public var connectionStateObserver: AnyCancellable?
    public var requestTestObserver: AnyCancellable?

    func testResolveRequest() throws {
        let promise = expectation(description: "Request complete.")
        
        connectionStateObserver = LBRYDaemon.shared.$daemonConnectionState.sink() { state in
            if state == .Connected {
                print("Daemon connected!")
                self.resolve(promise: promise)
            } else {
                print("Daemon currently not connected.")
            }
        }
        
        wait(for: [promise], timeout: 120)
    }
    
    func resolve(promise: XCTestExpectation) {
        let testURL = "@lbry#3f/lbry-in-100-seconds#a"
        let expectClaimID = "a20885a50338e1fec68d1b32335ab425b8540355"
        self.requestTestObserver = LBRYDaemon.shared.resolve(url: testURL).sink() { completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                print(error)
            }
        } receiveValue: { result in
            if let claimID = result["claim_id"] as? String {
                print(claimID)
                if expectClaimID == claimID {
                    promise.fulfill()
                }
            }
        }
    }
    
    func testGetRequest() {
        let promise = expectation(description: "Request complete.")
        
        connectionStateObserver = LBRYDaemon.shared.$daemonConnectionState.sink() { state in
            if state == .Connected {
                print("Daemon connected!")
                self.get(promise: promise)
            } else {
                print("Daemon currently not connected.")
            }
        }
        
        wait(for: [promise], timeout: 120)
    }
    
    func get(promise: XCTestExpectation) {
        let testURL = "lbry://@lbry#3f/lbry-in-100-seconds#a"
        let sdHash = "d5aa0308277df2a577d769a98bd48afc22ac0a553486b3392c7864606da772adec3643c69c518528ed30add3ee6115c8"
        let expectStreamingURL = "http://localhost:5280/stream/" + sdHash
        self.requestTestObserver = LBRYDaemon.shared.get(uri: testURL, saveFile: false).sink() { completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                print(error)
            }
        } receiveValue: { result in
            if let streamingURL = result["streaming_url"] as? String {
                print(streamingURL)
                if streamingURL == expectStreamingURL {
                    promise.fulfill()
                }
            }
        }
    }
}
