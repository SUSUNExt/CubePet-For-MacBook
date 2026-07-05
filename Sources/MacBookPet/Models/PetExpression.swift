import Foundation

enum PetExpression: CaseIterable {
    case calm
    case happy
    case curious
    case annoyed
    case scared
    case sleeping
    case listening

    var leftEye: EyeStyle {
        switch self {
        case .calm:
            return .round
        case .happy, .listening:
            return .smile
        case .curious:
            return .largeRound
        case .annoyed:
            return .annoyedLeft
        case .scared:
            return .chevronRight
        case .sleeping:
            return .invertedSmile
        }
    }

    var rightEye: EyeStyle {
        switch self {
        case .calm:
            return .round
        case .happy, .listening:
            return .smile
        case .curious:
            return .smallRound
        case .annoyed:
            return .annoyedRight
        case .scared:
            return .chevronLeft
        case .sleeping:
            return .invertedSmile
        }
    }

    var eyeSpacing: CGFloat {
        switch self {
        case .curious:
            return 8
        case .scared:
            return 9
        case .sleeping:
            return 11
        default:
            return 11
        }
    }

    var verticalOffset: CGFloat {
        switch self {
        case .happy, .listening:
            return 1
        case .annoyed:
            return -1
        case .scared:
            return -1
        case .sleeping:
            return 2
        default:
            return 0
        }
    }

    var allowsMouseGaze: Bool {
        switch self {
        case .calm, .curious, .annoyed:
            return true
        case .happy, .scared, .sleeping, .listening:
            return false
        }
    }
}

enum EyeStyle {
    case round
    case largeRound
    case smallRound
    case smile
    case sleepy
    case annoyedLeft
    case annoyedRight
    case chevronLeft
    case chevronRight
    case invertedSmile
}
