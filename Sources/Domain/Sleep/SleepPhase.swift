import Foundation
import SwiftUI

enum SleepPhase: String, Codable, CaseIterable {
    case awake = "Awake"
    case light = "Light"
    case deep = "Deep"
    case rem = "REM"

    var color: Color {
        switch self {
        case .awake:
            return .red
        case .light:
            return .blue
        case .deep:
            return .indigo
        case .rem:
            return .purple
        }
    }

    var shortName: String {
        switch self {
        case .awake: return "W"
        case .light: return "L"
        case .deep: return "D"
        case .rem: return "R"
        }
    }

    var displayOrder: Int {
        switch self {
        case .awake: return 0
        case .rem: return 1
        case .light: return 2
        case .deep: return 3
        }
    }
}
