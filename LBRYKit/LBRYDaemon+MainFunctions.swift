//
//  LBRYDaemon+MainFunctions.swift
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

/// Main functions of LBRY daemon.
extension LBRYDaemon {
    /// Get LBRY deamon status.
    ///
    /// - Parameters:
    ///   - complete:
    ///     Completion callback.
    public func status() -> AnyPublisher<[String:Any], Error> {
        return self.request(method: "status")
    }
    
    /// Resolve LBRY URLs thought daemon `resolve` request.
    ///
    /// - Parameters:
    ///   - urls:
    ///     You can explicit assign URLs in method call or provide in `params`.
    ///     If both exist, value provide by `params` will be used.
    ///   - params:
    ///     Same as LBRY daemon call.
    ///   - complete:
    ///     Completion callback.
    public func resolve(
        urls: [String] = [],
        params: [String:Any] = [:]
    ) -> AnyPublisher<[String:[String:Any]], Error> {
        /// Merging parameters and ignore `urls` in arguments if needed.
        let params = ["urls": urls].merging(params, uniquingKeysWith: {$1})
        
        return self.request(method: "resolve", params: params)
            .tryMap() { result in
                if let result = result as? [String:[String:Any]] {
                    return result
                } else {
                    throw LBRYDaemonError.DaemonResponseMismatch("result")
                }
            } .eraseToAnyPublisher()
    }
    
    /// Helper method to resolve single URL.
    ///
    /// Different from default multiple URL resolve,
    /// this method will perform error check instead return a dict result with `error` key.
    ///
    /// - Parameters:
    ///   - url:
    ///     URL to be resolve. This will ignore `urls` in params.
    ///   - params:
    ///     Same as LBRY daemon call.
    ///   - complete:
    ///     Completion callback.
    public func resolve(
        url: String,
        params: [String:Any] = [:]
    ) -> AnyPublisher<[String:Any], Error> {
        /// Merging parameters and ignore `urls` of `params`.
        let params = ["urls": url].merging(params, uniquingKeysWith: { old, _ in
            return old
        })
        
        return self.resolve(params: params)
            .tryMap() { result -> [String:Any] in
                if let resolveResult = result[url], resolveResult["error"] == nil {
                    return resolveResult
                } else {
                    throw LBRYDaemonError.LBRYResourceReolveFailed
                }
            } .eraseToAnyPublisher()
    }
    
    /// Download a stream thought daemon `get` request.
    ///
    /// - Parameters:
    ///   - uri:
    ///     You can explicit assign URI in method call or provide in `params`.
    ///     If both exist, value provide by `params` will be used.
    ///   - params:
    ///     Same as LBRY daemon call.
    ///   - complete:
    ///     Completion callback.
    public func get(
        uri: String = "",
        params: [String:Any] = [:]
    ) -> AnyPublisher<[String:Any], Error> {
        let params = ["uri": uri].merging(params, uniquingKeysWith: {$1})
        
        return self.request(method: "get", params: params)
    }
    
    /// Shutdown daemon though `stop` request.
    ///
    /// You should set `shouldAutomaticRestartDaemon` to `false` before calling this method
    /// to prevent daemon auto restart.
    public func stop() -> AnyPublisher<[String:Any], Error> {
        return self.request(method: "stop")
    }
    
    /// Resolve LBRY deamon vserion.
    ///
    /// This method only resolve deamon version.
    /// For full version info including platform, os, python etc.
    /// Use `request` method with `version` call.
    ///
    /// - Parameters:
    ///   - complete:
    ///     Completion callback.
    public func version() -> AnyPublisher<String, Error> {
        return self.request(method: "version")
            .tryMap() { result -> String in
                if let version = result["version"] as? String {
                    return version
                } else {
                    throw LBRYDaemonError.DaemonResponseMismatch("version")
                }
            } .eraseToAnyPublisher()
    }
    
    /// Get DHT routing information thought `routing_table_get` request.
    public func routingTableGet() -> AnyPublisher<[String:Any], Error> {
        return self.request(method: "routing_table_get")
    }
    
    /// Get ffmpeg installation information thought `ffmpeg_find` request.
    public func ffmpegFind() -> AnyPublisher<[String:Any], Error> {
        return self.request(method: "ffmpeg_find")
    }
}

/// Main function of LBRY daemon with version dependent explicit arguments.
extension LBRYDaemon {
    /// Resolve LBRY URLs thought daemon `resolve` request.
    ///
    /// This is `resolve` call with explicit arguments.
    /// If you want to resolve with custom params, use `resolve(urls:_, params:_)`
    ///
    /// Most of arguments are same as LBRY daemon call in current version (v0.87.0).
    /// But still, this is depend on LBRY daemon version
    /// and might invalid when deamon update.
    /// Please check your daemon version and use with causion.
    public func resolve(
        urls: [String],
        walletID: String? = nil,
        includePurchaseReceipt: Bool? = nil,
        includeIsMyOutput: Bool? = nil,
        includeSentSupports: Bool? = nil,
        includeSentTips: Bool? = nil,
        includeReceivedTip: Bool? = nil
    ) -> AnyPublisher<[String:[String:Any]], Error> {
        let params = self.encodeResolveParams(
            urls: urls,
            walletID: walletID,
            includePurchaseReceipt: includePurchaseReceipt,
            includeIsMyOutput: includeIsMyOutput,
            includeSentSupports: includeSentSupports,
            includeSentTips: includeSentTips,
            includeReceivedTip: includeReceivedTip
        )
        
        return self.resolve(params: params)
    }
    
    /// Helper method to resolve single URL.
    ///
    /// This is `resolve` call with explicit arguments.
    /// If you want to resolve with custom params, use `resolve(url:_, params:_)`
    ///
    /// Most of arguments are same as LBRY daemon call in current version (v0.87.0).
    /// But still, this is depend on LBRY daemon version
    /// and might invalid when deamon update.
    ///
    /// Please check your daemon version and use with causion.
    public func resolve(
        url: String,
        walletID: String? = nil,
        includePurchaseReceipt: Bool? = nil,
        includeIsMyOutput: Bool? = nil,
        includeSentSupports: Bool? = nil,
        includeSentTips: Bool? = nil,
        includeReceivedTip: Bool? = nil,
        complete: (([String:Any], Error?)->())? = nil
    ) -> AnyPublisher<[String:Any], Error> {
        let params = self.encodeResolveParams(
            urls: nil,
            walletID: walletID,
            includePurchaseReceipt: includePurchaseReceipt,
            includeIsMyOutput: includeIsMyOutput,
            includeSentSupports: includeSentSupports,
            includeSentTips: includeSentTips,
            includeReceivedTip: includeReceivedTip
        )
        
        return self.resolve(url: url, params: params)
    }
    
    /// Download a stream thought daemon `get` request.
    ///
    /// This is `get` call with explicit arguments.
    /// If you want to resolve with custom params, use `get(uri:_, params:_)`
    ///
    /// Most of arguments are same as LBRY daemon call in current version (v0.87.0).
    /// But still, this is depend on LBRY daemon version
    /// and might invalid when deamon update.
    ///
    /// Please check your daemon version and use with causion.
    public func get(
        uri: String,
        fileName: String? = nil,
        downloadDirectory: String? = nil,
        timeout: Int? = nil,
        saveFile: Bool? = nil,
        walletID: String? = nil
    ) -> AnyPublisher<[String:Any], Error> {
        let params = self.encodeGetParams(
            uri: uri,
            fileName: fileName,
            downloadDirectory: downloadDirectory,
            timeout: timeout,
            saveFile: saveFile,
            walletID: walletID
        )
        
        return self.get(params: params)
    }
}

/// Params helper function.
extension LBRYDaemon {
    /// Map resolve request arguments to LBRY daemon params.
    private func encodeResolveParams(
        urls: [String]? = nil,
        walletID: String? = nil,
        includePurchaseReceipt: Bool? = nil,
        includeIsMyOutput: Bool? = nil,
        includeSentSupports: Bool? = nil,
        includeSentTips: Bool? = nil,
        includeReceivedTip: Bool? = nil
    ) -> [String:Any] {
        return self.encodeParams([
            "urls": urls,
            "wallet_id": walletID,
            "include_purchase_receipt": includePurchaseReceipt,
            "include_is_my_output": includeIsMyOutput,
            "include_sent_supports": includeSentSupports,
            "include_sent_tips": includeSentTips,
            "includeReceivedTip": includeReceivedTip
        ])
    }
    
    /// Map get request arguments to LBRY daemon params.
    private func encodeGetParams(
        uri: String,
        fileName: String? = nil,
        downloadDirectory: String? = nil,
        timeout: Int? = nil,
        saveFile: Bool? = nil,
        walletID: String? = nil
    ) -> [String:Any] {
        return self.encodeParams([
            "uri": uri,
            "file_name": fileName,
            "download_directory": downloadDirectory,
            "timeout": timeout,
            "save_file": saveFile,
            "wallet_id": walletID
        ])
    }
    
    /// Encode params into minimal form.
    ///
    /// This method will remove any unwanted optional parameters
    /// to avoid any unexpected behavior.
    private func encodeParams(_ params: [String:Any?]) -> [String:Any] {
        var result: [String:Any] = [:]
        for (key, value) in params {
            if let value = value {
                result[key] = value
            }
        }
        
        return result
    }
}
