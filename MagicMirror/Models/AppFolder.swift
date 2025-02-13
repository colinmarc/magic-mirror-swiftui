import Collections
import MMClientCommon

class AppFolder: Identifiable, Hashable {
    let parent: AppFolder?
    let fullPath: [String]
    let name: String

    var folderChildren = OrderedDictionary<String, AppFolder>()
    var appChildren = OrderedDictionary<String, Application>()

    init(parent: AppFolder?, fullPath: [String], name: String? = nil) {
        self.parent = parent
        self.fullPath = fullPath
        self.name = (name ?? self.fullPath.last ?? "")
    }

    func insertApp(_ app: Application, at path: [String]) {
        if let dir = path.first {
            let folder =
                self.folderChildren[dir] ?? AppFolder(parent: self, fullPath: self.fullPath + [dir])
            folder.insertApp(app, at: Array(path[1...]))
            self.folderChildren[dir] = folder
        } else {
            self.appChildren[app.id] = app
        }
    }

    func listApps(at path: [String]) -> OrderedDictionary<String, Application> {
        if let dir = path.first {
            self.folderChildren[dir]!.listApps(at: Array(path[1...]))
        } else {
            self.appChildren
        }
    }

    var isRoot: Bool {
        self.fullPath.isEmpty
    }

    func hash(into hasher: inout Hasher) {
        for dir in self.fullPath {
            hasher.combine(dir)
        }
    }

    var id: String {
        self.fullPath.joined(separator: "/")
    }

    static func == (lhs: AppFolder, rhs: AppFolder) -> Bool {
        return lhs.fullPath == rhs.fullPath
    }
}
