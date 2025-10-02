// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import AVKit
import AVFoundation

class BetterPlayerEzDrmAssetsLoaderDelegate: NSObject {
    let certificateURL: URL
    let licenseURL: URL
    
    private var assetId: String?
    private let defaultLicenseServerURL = "https://fps.ezdrm.com/api/licenses/"
    
    init(certificateURL: URL, licenseURL: URL) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        super.init()
    }
    
    /// Takes the bundled SPC and sends it to the license server defined at licenseUrl or KEY_SERVER_URL (if licenseUrl is null).
    /// It returns CKC.
    private func getContentKeyAndLeaseExpiryFromKeyServerModuleWithRequest(_ requestBytes: Data, assetId: String, customParams: String) -> Data? {
        let finalLicenseURL: URL
        if licenseURL.absoluteString != "" {
            finalLicenseURL = licenseURL
        } else {
            finalLicenseURL = URL(string: defaultLicenseServerURL)!
        }
        
        let ksmURL = URL(string: "\(finalLicenseURL)\(assetId)\(customParams)")!
        
        var request = URLRequest(url: ksmURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-type")
        request.httpBody = requestBytes
        
        do {
            let (data, _) = try URLSession.shared.synchronousDataTask(with: request)
            return data
        } catch {
            print("SDK Error, SDK responded with Error: \(error)")
            return nil
        }
    }
    
    /// Returns the apps certificate for authenticating against your server
    /// the example here uses a local certificate
    /// but you may need to edit this function to point to your certificate
    private func getAppCertificate(_ string: String) -> Data? {
        return try? Data(contentsOf: certificateURL)
    }
}

// MARK: - AVAssetResourceLoaderDelegate
extension BetterPlayerEzDrmAssetsLoaderDelegate: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let assetURI = loadingRequest.request.url else { return false }
        let str = assetURI.absoluteString
        let mySubstring = String(str.suffix(36))
        assetId = mySubstring
        
        guard let scheme = assetURI.scheme, scheme == "skd" else { return false }
        
        guard let certificate = getAppCertificate(assetId!) else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorClientCertificateRejected, userInfo: nil))
            return true
        }
        
        guard let requestBytes = try? loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: str.data(using: .utf8)!, options: nil) else {
            loadingRequest.finishLoading(with: nil)
            return true
        }
        
        let passthruParams = "?customdata=\(assetId!)"
        let responseData = getContentKeyAndLeaseExpiryFromKeyServerModuleWithRequest(requestBytes, assetId: assetId!, customParams: passthruParams)
        
        if let responseData = responseData {
            loadingRequest.dataRequest?.respond(with: responseData)
            loadingRequest.finishLoading()
        } else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil))
        }
        
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return resourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: renewalRequest)
    }
}

// MARK: - URLSession Synchronous Extension
extension URLSession {
    func synchronousDataTask(with request: URLRequest) throws -> (Data, URLResponse) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        dataTask(with: request) { responseData, responseData, responseError in
            data = responseData
            response = responseData
            error = responseError
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        return (data!, response!)
    }
}