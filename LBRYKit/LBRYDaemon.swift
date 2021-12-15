//
//  LBRYDaemon.swift
//  LBRYKit
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

import Foundation
import Combine

public class LBRYDaemon {
    /// Shared instance.
    public static let shared: LBRYDaemon = LBRYDaemon()
    
    /// Current connection state to deamon.
    ///
    /// You may subscribe this to reflect any connection state change.
    @Published
    public private(set) var daemonConnectionState: LBRYDaemonConnectionState = .Disconnected
    
    /// Port for localhost LBRY daemon API call.
    ///
    /// Normally you should not change this to avoid multiple daemon instance.
    public let lbryAPIPort = 5279
    
    /// Period of checking daemon status.
    public var heartbeatPeriod: TimeInterval = 20.0
    
    /// Should restart daemon automatically when connection is broken.
    ///
    /// See `launch` for more information.
    public var shouldAutomaticRestartDaemon: Bool = true
    
    /// Subscriber for daemon launch process.
    private var daemonLaunchObserver: AnyCancellable?
    
    /// Subscriber for daemon heartbeat.
    private var daemonHeartbeatOberserver: AnyCancellable?
    
    /// Daemon executable location.
    private var lbryDeamonLocations: [URL?] = [
        // Location for LBRY desktop app provided deamon.
        URL(fileURLWithPath: "/Applications/LBRY.app/Contents/Resources/static/daemon/lbrynet"),
        // Framework bundle provided daemon.
        Bundle(for: LBRYDaemon.self).url(forResource: "lbrynet", withExtension: nil)
    ]
    
    /// Launched daemon subprocess if no existing daemon.
    private var lbryDaemonProcess: Process? = nil
    
    /// Initialize deamon.
    private init() {
        // Start heartbeating.
        // First heartbeat will try to launch daemon automatically.
        self.heartbeat()
    }
    
    deinit {
        // This actually never call since this class is singleton.
        // Please stop daemon by calling `terminate` explicitly.
        // self.terminate()
    }
}

/// Basic method calls.
extension LBRYDaemon {
    /// Daemon request wrapper.
    ///
    /// A method call to daemon though URL POST request.
    ///
    /// - Parameters:
    ///     - method: Method name of daemon.
    ///     - params: Method parameters.
    public func request(
        method: String,
        params: [String:Any] = [:]
    ) -> AnyPublisher<[String:Any], Error> {
        let url = URL(string: "http://localhost:\(lbryAPIPort)")!
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.httpBody = self.encode(object: [
            "method": method,
            "params": params
        ])
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap() { data, response -> [String:Any] in
                if let response = response as? HTTPURLResponse {
                    if (200..<300).contains(response.statusCode) == false {
                        self.daemonConnectionState = .Disconnected
                        throw LBRYDaemonError.DaemonNotLaunch
                    }
                }
                
                if let jsonObject = self.decode(data: data),
                   let result = jsonObject["result"] as? [String:Any] {
                    return result
                } else {
                    throw LBRYDaemonError.DaemonResponseMismatch("result")
                }
            } .eraseToAnyPublisher()
    }
    
    // Encode json object to `Data`.
    private func encode(object: [String:Any]) -> Data? {
        if let jsonData = try? JSONSerialization.data(
            withJSONObject: object,
            options: []
        ) {
            return jsonData
        }
        return nil
    }
    
    // Decode json object from `Data`.
    private func decode(data: Data) -> [String:Any]? {
        if let object = try? JSONSerialization.jsonObject(
            with: data,
            options: []
        ) as? [String:Any] {
            return object
        }
        return nil
    }
}

/// Deamon startup process.
extension LBRYDaemon {
    /// Launch or connect existing deamon.
    ///
    /// If `shouldAutomaticRestartDaemon` set to `true`, you should no need to call this method.
    /// Heartbeat will auto detect and decide whether we need to launch daemon in this case.
    /// Otherwise, you need to restart daemon manually by calling this method.
    ///
    /// This method provide no additional information about launch process or callback.
    /// You should subscribe `daemonConnectionState` to reflect any change of connection state.
    public func launch() {
        // Relaunch needed only when daemon disconnected.
        if (
            self.daemonConnectionState != .Disconnected &&
            self.daemonConnectionState != .Terminated
        ) {
            return
        }
        
        // Lock daemon with connecting state.
        self.daemonConnectionState = .Connecting
        
        // Create subscriber to launch daemon.
        self.daemonLaunchObserver = self.status().sink() { completion in
            switch completion {
            case .finished:
                self.daemonConnectionState = .Connected
            case .failure:
                do {
                    try self.launchDeamon()
                } catch {
                    self.daemonConnectionState = .Disconnected
                }
            }
        } receiveValue: { _ in
            
        }
    }
    
    public func terminate() {
        // Stop only when daemon still running.
        if self.daemonConnectionState == .Terminated {
            return
        }
        // Mark daemon state as terminated, prevent auto restart.
        self.daemonConnectionState = .Terminated
        
        // Terminate subprocess.
        self.lbryDaemonProcess?.terminate()
        self.lbryDaemonProcess = nil
    }
    
    /// Launch deamon as subprocess if needed.
    private func launchDeamon() throws {
        if self.lbryDaemonProcess != nil {
            throw LBRYDaemonError.DaemonSubprocessStateInconsistent
        }
        
        guard let url: URL = {
            for url in self.lbryDeamonLocations {
                if let url = url, FileManager.default.isExecutableFile(
                    atPath: url.path
                ) {
                    return url
                }
            }
            return nil
        } () else {
            throw LBRYDaemonError.DaemonExecutableNotFind
        }
        
        let process = Process()
        process.executableURL = url
        process.arguments = ["start"]
        
        let outputPipe = Pipe()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count <= 0 {
                try? handle.close()
            }
            
            if let output = String(data: data, encoding: .utf8) {
                print("[LBRYNet]", output, terminator: "")
            }
        }
        
        let errorPipe = Pipe()
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            
            if data.count <= 0 {
                try? handle.close()
            }
            
            if let output = String(data: data, encoding: .utf8) {
                print("[LBRYNet]", output, terminator: "")
            }
        }

        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { process in
            self.daemonConnectionState = .Disconnected
            self.lbryDaemonProcess = nil
        }
        
        do {
            try process.run()
            self.lbryDaemonProcess = process
        } catch {
            self.lbryDaemonProcess = nil
            self.daemonConnectionState = .Disconnected
            
            throw LBRYDaemonError.DaemonLaunchFailed
        }
    }
    
    /// Regular check for LBRY daemon status.
    private func heartbeat() {
        switch self.daemonConnectionState {
        case .Connected:
            self.daemonHeartbeatOberserver = self.status()
                .sink() { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        // Detect connection is broken.
                        self.daemonConnectionState = .Disconnected
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.heartbeatPeriod) {
                        self.heartbeat()
                    }
                } receiveValue: { _ in
                    
                }
        case .Connecting:
            self.daemonHeartbeatOberserver = self.status()
                .sink() { completion in
                    switch completion {
                    case .finished:
                        // Detect connection is established.
                        self.daemonConnectionState = .Connected
                    case .failure:
                        break
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.heartbeatPeriod) {
                        self.heartbeat()
                    }
                } receiveValue: { _ in
                    
                }
        case .Disconnected:
            if self.shouldAutomaticRestartDaemon {
                // Try to launch daemon.
                self.launch()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + self.heartbeatPeriod) {
                self.heartbeat()
            }
        case .Terminated:
            // Do nothing. Just schedule next heartbeat.
            DispatchQueue.main.asyncAfter(deadline: .now() + self.heartbeatPeriod) {
                self.heartbeat()
            }
        }
    }
}
