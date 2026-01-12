import Foundation

enum Feature: String, CaseIterable, Identifiable {
    case aiAssistant
    case accounts
    case email
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiAssistant: return "AI Assistant"
        case .accounts: return "Accounts"
        case .email: return "Email"
        case .calendar: return "Calendar"
        }
    }

    var systemImage: String {
        switch self {
        case .aiAssistant: return "gearshape"
        case .accounts: return "person.crop.circle.badge.checkmark"
        case .email: return "envelope"
        case .calendar: return "calendar"
        }
    }
}
