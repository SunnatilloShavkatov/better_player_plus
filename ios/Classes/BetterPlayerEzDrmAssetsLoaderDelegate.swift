import Foundation
import AVFoundation

@objc class BetterPlayerEzDrmAssetsLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    let certificateURL: URL
    let licenseURL: URL?
    private var assetId: String = ""

    init(certificateURL: URL, withLicenseURL licenseURL: URL?) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        super.init()
    }

    private let defaultLicenseServerURL = URL(string: "https://fps.ezdrm.com/api/licenses/")!

    private func getContentKeyAndLeaseExpiryFromKeyServerModule(request requestBytes: Data, assetId: String, customParams: String, errorOut: NSErrorPointer) -> Data? {
        let finalLicenseURL = licenseURL ?? defaultLicenseServerURL
        let ksmURL = URL(string: "\(finalLicenseURL.absoluteString)\(assetId)\(customParams)")!
        var req = URLRequest(url: ksmURL)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-type")
        req.httpBody = requestBytes
        do {
            let (data, _) = try URLSession.shared.syncRequest(with: req)
            return data
        } catch {
            return nil
        }
    }

    private func getAppCertificate(_ string: String) -> Data? {
        return try? Data(contentsOf: certificateURL)
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let assetURI = loadingRequest.request.url, assetURI.scheme == "skd" else { return false }
        let str = assetURI.absoluteString
        let mySubstring = String(str.suffix(36))
        assetId = mySubstring
        guard let certificate = getAppCertificate(assetId) else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorClientCertificateRejected))
            return true
        }
        let requestBytes: Data
        do {
            requestBytes = try loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: str.data(using: .utf8)!, options: nil)
        } catch {
            loadingRequest.finishLoading(with: nil)
            return true
        }
        let passthruParams = "?customdata=\(assetId)"
        var error: NSError?
        let responseData = getContentKeyAndLeaseExpiryFromKeyServerModule(request: requestBytes, assetId: assetId, customParams: passthruParams, errorOut: &error)
        if let responseData = responseData, !responseData.isEmpty {
            let dataRequest = loadingRequest.dataRequest
            dataRequest?.respond(with: responseData)
            loadingRequest.finishLoading()
        } else {
            loadingRequest.finishLoading(with: error)
        }
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return self.resourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: renewalRequest)
    }
}

private extension URLSession {
    func syncRequest(with request: URLRequest) throws -> (Data, URLResponse) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 1)
        semaphore.wait()
        let task = dataTask(with: request) { d, r, e in
            data = d; response = r; error = e; semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        if let e = error { throw e }
        return (data ?? Data(), response!)
    }
}
