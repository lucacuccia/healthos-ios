import SwiftUI

extension DayType {
    /// Distinct color used to mark this workout type in the history calendar.
    var color: Color {
        switch self {
        case .push:   return .blue
        case .pull:   return .green
        case .legs:   return .orange
        case .cardio: return .red
        }
    }
}
