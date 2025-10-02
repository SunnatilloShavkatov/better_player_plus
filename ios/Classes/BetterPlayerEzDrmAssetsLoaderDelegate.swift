import Foundation
import AVFoundation

@objc public class BetterPlayerEzDrmAssetsLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    @objc public let certificateURL: URL
    @objc public let licenseURL: URL?

    private var assetId: String?
    private let defaultLicenseServerURL = URL(string: "https://fps.ezdrm.com/api/licenses/")!

    @objc public init(certificateURL: URL, withLicenseURL licenseURL: URL?) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        super.init()
    }

    private func getContentKeyAndLeaseExpiryFromKeyServerModule(request requestBytes: Data, assetId: String, customParams: String) -> Data? {
        let finalLicenseBaseURL = self.licenseURL ?? defaultLicenseServerURL
        guard let ksmURL = URL(string: "\(finalLicenseBaseURL.absoluteString)\(assetId)\(customParams)") else {
            return nil
        }
        var req = URLRequest(url: ksmURL)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-type")
        req.httpBody = requestBytes

        let semaphore = DispatchSemaphore(value: 1)
        var responseData: Data?
        let task = URLSession.shared.dataTask(with: req) { data, _, _ in
            responseData = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 30)
        return responseData
    }

    private func getAppCertificate(_ assetId: String) throws -> Data {
        return try Data(contentsOf: certificateURL)
    }

    @objc public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let assetURI = loadingRequest.request.url else { return false }
        let str = assetURI.absoluteString
        // Use last 36 chars as asset id, following original implementation
        let startIndex = str.index(str.endIndex, offsetBy: -min(36, str.count))
        let mySubstring = String(str[startIndex...])
        self.assetId = mySubstring
        let scheme = assetURI.scheme

        guard scheme == "skd" else { return false }

        let requestBytes: Data
        let certificate: Data
        do {
            certificate = try getAppCertificate(mySubstring)
        } catch {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: URLError.clientCertificateRejected.rawValue, userInfo: nil))
            return true
        }

        do {
            requestBytes = try loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: str.data(using: .utf8)!, options: nil)
        } catch {
            loadingRequest.finishLoading(with: error)
            return true
        }

        let passthruParams = "?customdata=\(mySubstring)"
        let responseData = getContentKeyAndLeaseExpiryFromKeyServerModule(request: requestBytes, assetId: mySubstring, customParams: passthruParams)

        if let responseData {
            loadingRequest.dataRequest?.respond(with: responseData)
            loadingRequest.finishLoading()
        } else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: URLError.badServerResponse.rawValue, userInfo: nil))
        }
        return true
    }

    @objc public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return self.resourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: renewalRequest)
    }
}
