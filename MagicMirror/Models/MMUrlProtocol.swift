import Foundation
import OSLog

class MMImageURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        // Only handle URLs with the scheme "mm"
        guard let url = request.url else { return false }
        return url.scheme == "mm"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.hostPort else {
            sendError(.unsupportedURL)
            return
        }

        let pathComponents = url.pathComponents
        guard pathComponents.count == 5, pathComponents[1] == "applications",
            pathComponents[3] == "images", pathComponents[4] == "header.png"
        else {
            sendError(.fileDoesNotExist)
            return
        }

        let appID = pathComponents[2]
        Task {
            do {
                let imageData = try await ServerManager.shared.client(for: .hostPort(host))
                    .fetchApplicationImage(
                        id: appID)
                sendImageData(imageData)
            } catch {
                Logger.client.error(
                    "failed to load image for app \(appID, privacy: .public): \(error.localizedDescription)"
                )
                sendError(.cannotLoadFromNetwork)
            }
        }
    }

    override func stopLoading() {
    }

    private func sendImageData(_ data: Data) {
        guard let url = request.url else { return }
        let response = URLResponse(
            url: url, mimeType: "image/png", expectedContentLength: data.count,
            textEncodingName: nil)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    // Helper method to send an error response.
    private func sendError(_ errorCode: URLError.Code) {
        let error = URLError(errorCode)
        client?.urlProtocol(self, didFailWithError: error)
    }
}

extension URL {
    var hostPort: String? {
        let host = self.host()
        if let host = host, let port = self.port {
            return "\(host):\(port)"
        } else {
            return host
        }
    }
}
