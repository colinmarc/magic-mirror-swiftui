import Collections
import Foundation
import MMClientCommon
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

@Observable
@MainActor
class Server: Identifiable {
    let addr: String

    var apps: OrderedDictionary<String, Application>
    var rootFolder: AppFolder

    var sessions: OrderedDictionary<uint64, Session>

    init(addr: String) {
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

    private(set) var connectionStatus: LastStatus = .disconnected

    var errorStatus: Error? {
        switch self.connectionStatus {
        case .error(let error), .connecting(_, .some(let error)):
            error
        default:
            nil
        }
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
            Logger.client.info("connecting to \(self.addr, privacy: .public)")
            return try await Client(
                addr: self.addr, clientName: "MagicMirrorApp")
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
        await self.reloadSessions()
    }

    nonisolated var id: String { addr }
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
