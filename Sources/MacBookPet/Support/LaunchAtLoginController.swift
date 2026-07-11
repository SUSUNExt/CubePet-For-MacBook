import ServiceManagement

final class LaunchAtLoginController {
    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    var requiresApproval: Bool {
        service.status == .requiresApproval
    }

    func toggle() throws {
        if isEnabled || requiresApproval {
            try service.unregister()
        } else {
            try service.register()
        }
    }
}
