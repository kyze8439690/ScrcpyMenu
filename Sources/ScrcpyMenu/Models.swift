import Foundation

enum DeviceState: String {
    case device
    case unauthorized
    case offline
    case unknown

    var isUsable: Bool { self == .device }

    var displayText: String {
        switch self {
        case .device: return ""
        case .unauthorized: return "unauthorized"
        case .offline: return "offline"
        case .unknown: return "unknown"
        }
    }
}

struct AndroidDevice: Equatable {
    let serial: String
    let model: String?
    let state: DeviceState

    var displayName: String {
        if let model, !model.isEmpty {
            return model.replacingOccurrences(of: "_", with: " ")
        }
        return serial
    }
}
