import SwiftUI

@Observable
class ConfigSheetPresentation {
    var launchConfigurationTarget: LaunchTarget? = nil

    var addServerSheetIsPresented = false

    func presentLaunchConfigurationSheet(for target: LaunchTarget) {
        self.launchConfigurationTarget = target
    }

    func presentAddServerSheet() {
        self.addServerSheetIsPresented = true
    }

    func onDismiss() {
        self.launchConfigurationTarget = nil
        self.addServerSheetIsPresented = false
    }
}

extension EnvironmentValues {
    @Entry var configSheetPresentation = ConfigSheetPresentation()
}
