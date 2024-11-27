import Collections
import SwiftUI

enum TaskState {
    case none
    case running(String)
    case errored(Error)

    var isNone: Bool {
        switch self {
        case .none:
            true
        default:
            false
        }
    }
}

@MainActor @Observable
class TaskQueue: ObservableObject {
    private var queuedTasks: Deque<(Task<(), Error>, String)> = []
    var tasksInProgress: Bool = false
    var currentState: TaskState = .none

    func dispatch(tasks: [(Task<(), Error>, String)]) async throws {
        if self.queuedTasks.count > 0 {
            // A dispatch is already in progress.
            queuedTasks.append(contentsOf: tasks)
            return
        }

        self.queuedTasks = Deque(tasks)

        var err: Error
        while true {
            guard let (task, desc) = self.queuedTasks.popFirst() else {
                // Done.
                self.tasksInProgress = false
                self.currentState = .none
                return
            }

            self.tasksInProgress = true
            self.currentState = .running(desc)
            do {
                let _ = try await task.value
            } catch {
                err = error
                break
            }
        }

        self.queuedTasks = []
        self.currentState = .errored(err)

        // Let the error linger for a bit, by default. After the await, we have
        // to check that another dispatch didn't start.
        try? await Task.sleep(for: .seconds(3))
        if self.queuedTasks.isEmpty {
            self.tasksInProgress = false
            self.currentState = .none
        }

        throw err
    }
}
