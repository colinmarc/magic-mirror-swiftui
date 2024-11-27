import MMClientCommon

struct LaunchTarget: Identifiable {
    let server: Server
    let application: Application
    let session: Session?

    var id: String {
        if let s = session {
            "mmlaunch://\(server.addr)/session/\(s.id)"
        } else {
            "mmlaunch://\(server.addr)/application/\(application.id)"
        }
    }
}
