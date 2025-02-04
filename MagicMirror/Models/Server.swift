import Collections
import Foundation
import MMClientCommon
import Network
import SwiftUI
import os

enum LastStatus: CustomStringConvertible {
    case disconnected
    case error(Error)
    case connecting(Task<Client, Error>, Error?)
    case connected(Client)

    var description: String {
        switch self {
        case .connected(_):
            "connected"
        case .connecting(_, _):
            "connecting"
        case .disconnected:
            "disconnected"
        case .error(let error):
            "error: \(error)"
        }
    }
}

enum ServerError: Error {
    case disconnected
}

enum ServerAddr: Hashable, CustomStringConvertible {
    case hostPort(String)
    case mdns(NWEndpoint)

    var description: String {
        switch self {
        case .hostPort(let hostPort):
            return hostPort
        case .mdns(let endpoint):
            return endpoint.debugDescription
        }
    }

    var displayName: String {
        switch self {
        case .hostPort(let hostPort):
            return hostPort
        case .mdns(let endpoint):
            if case .service(let name, _, _, _) = endpoint {
                return name
            } else {
                return endpoint.debugDescription
            }
        }
    }
}

@Observable
@MainActor
class Server: Identifiable {
    let addr: ServerAddr

    var apps: OrderedDictionary<String, Application>
    var rootFolder: AppFolder

    var sessions: OrderedDictionary<uint64, Session>

    private var reloadOperationsInProgress = 0
    var isReloading: Bool {
        self.reloadOperationsInProgress > 0
    }

    private(set) var connectionStatus: LastStatus = .disconnected
    var isConnecting: Bool {
        if case .connecting(_, _) = self.connectionStatus {
            true
        } else {
            false
        }
    }

    var errorStatus: Error? {
        switch self.connectionStatus {
        case .error(let error), .connecting(_, .some(let error)):
            error
        default:
            nil
        }
    }

    convenience init(addr: String) {
        self.init(addr: .hostPort(addr))
    }

    convenience init(endpoint: NWEndpoint) {
        self.init(addr: .mdns(endpoint))
    }

    init(addr: ServerAddr) {
        self.addr = addr
        self.apps = OrderedDictionary()
        self.rootFolder = AppFolder(parent: nil, fullPath: [])
        self.sessions = OrderedDictionary()

        Task {
            await self.reloadSessionsAndApps()
        }
    }

    var sessionsWithMatchingApp: some RandomAccessCollection<(Session, Application)> {
        self.sessions.values.compactMap { session in
            if let app = self.apps[session.applicationId] {
                return (session, app)
            } else {
                return nil
            }
        }
    }

    func headerImageURL(for app: Application) -> URL? {
        guard app.headerImageAvailable else {
            return nil
        }

        return URL(
            string: "mm://\(addr)/applications/\(app.id)/images/header.png"
        )
    }

    func connect() async throws -> Client {
        switch self.connectionStatus {
        case .connected(let client):
            return client
        case .connecting(let task, _):
            return try await task.value
        default:
            break
        }

        let task = Task {
            () throws -> Client in
            let hostPort =
                switch self.addr {
                case .hostPort(let hostPort):
                    hostPort
                case .mdns(let endpoint):
                    try await endpoint.resolveUDPHostPort()
                }

            Logger.client.info("connecting to \(hostPort, privacy: .public)")

            return try await Client(
                addr: hostPort, clientName: "MagicMirrorApp")
        }

        self.connectionStatus = .connecting(task, self.errorStatus)
        do {
            let client = try await task.value
            self.connectionStatus = .connected(client)
            return client
        } catch {
            self.connectionStatus = .error(error)
            throw error
        }
    }

    func reloadSessions() async {
        guard let client = try? await self.connect() else {
            return
        }

        self.reloadOperationsInProgress += 1
        defer {
            self.reloadOperationsInProgress -= 1
        }

        do {
            let sessions = try await client.listSessions(timeout: 5.0)
            self.sessions = OrderedDictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        } catch {
            Logger.client.error(
                "failed to load session information for \(self.addr): \(error.localizedDescription)"
            )
            self.connectionStatus = .error(error)
            self.sessions = OrderedDictionary()
            self.apps = OrderedDictionary()
        }
    }

    func reloadSessionsAndApps(resetError: Bool = false) async {
        if errorStatus != nil && resetError {
            Logger.client.debug("resetting error")
            self.connectionStatus = .disconnected
        }

        guard let client = try? await self.connect() else {
            return
        }

        self.reloadOperationsInProgress += 1
        defer {
            self.reloadOperationsInProgress -= 1
        }

        do {
            let sessions = try await client.listSessions(timeout: 5.0)
            let apps = try await client.listApplications(timeout: 5.0)

            self.sessions = OrderedDictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            self.apps = OrderedDictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
            self.rootFolder = AppFolder(parent: nil, fullPath: [])
            for (_, app) in self.apps {
                self.rootFolder.insertApp(app, at: app.folder)
            }
        } catch {
            // If we can't load sessions and apps, we may as well consider the
            // connection broken.
            Logger.client.error(
                "failed to load app/session information for \(self.addr, privacy: .public)")
            self.connectionStatus = .error(error)
            self.sessions = OrderedDictionary()
            self.apps = OrderedDictionary()
        }
    }

    func launchSession(
        applicationID: String, displayParams: DisplayParams, permanentGamepads: [Gamepad]
    ) async throws -> Session {
        let client = try await self.connect()
        let session = try await client.launchSession(
            applicationId: applicationID,
            displayParams: displayParams,
            permanentGamepads: permanentGamepads,
            timeout: 30.0)

        // Add the new session to the view.
        self.sessions[session.id] = session

        return session
    }

    func fetchApplicationImage(id: String) async throws -> Data {
        return try await self.connect().fetchApplicationImage(
            applicationId: id, format: .header, timeout: 5.0)
    }

    func attachSession(
        sessionID: UInt64, config: AttachmentConfig, delegate: some AttachmentDelegate
    ) async throws -> MMClientCommon.Attachment {
        return try await self.connect().attachSession(
            sessionId: sessionID, config: config, delegate: delegate, timeout: 30.0)
    }

    func endSession(sessionID: UInt64) async throws {
        try await self.connect().endSession(id: sessionID, timeout: 10.0)
        self.sessions.removeValue(forKey: sessionID)
    }

    nonisolated var id: ServerAddr { addr }
}

struct FocusedServerKey: FocusedValueKey {
    typealias Value = Server
}

extension FocusedValues {
    var server: FocusedServerKey.Value? {
        get { self[FocusedServerKey.self] }
        set { self[FocusedServerKey.self] = newValue }
    }
}

enum NWEndpointResolutionError: Error {
    case resolutionFailed(NWError?)
}

extension NWEndpoint {
    func resolveUDPHostPort() async throws -> String {
        let connection = NWConnection(to: self, using: .udp)
        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .preparing, .cancelled:
                    return
                case .ready:
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                        case .hostPort(let host, let port) = innerEndpoint
                    {
                        continuation.resume(returning: "[\(host)]:\(port)")
                    } else {
                        continuation.resume(
                            throwing: NWEndpointResolutionError.resolutionFailed(nil))
                    }

                    connection.cancel()
                case .failed(let err):
                    continuation.resume(throwing: NWEndpointResolutionError.resolutionFailed(err))
                default:
                    Logger.general.error("unexpected state: \(String(describing: state))")
                    continuation.resume(throwing: NWEndpointResolutionError.resolutionFailed(nil))
                }
            }

            connection.start(queue: DispatchQueue.main)
        }
    }
}
