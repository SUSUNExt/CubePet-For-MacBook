import Foundation

enum PetVisualState: String, CaseIterable, Codable {
    case normal
    case happy
    case scared
    case sleeping
    case eating

    init(expression: PetExpression) {
        switch expression {
        case .happy:
            self = .happy
        case .scared:
            self = .scared
        case .sleeping:
            self = .sleeping
        default:
            self = .normal
        }
    }
}

enum PetBaseVisualSource: Equatable, Codable {
    case officialSkin
    case importedAsset(id: String)
}

enum PetEyeModuleKind: String, CaseIterable, Codable {
    case expressionDriven
    case tracking
    case happy
    case scared
    case sleeping
    case eating
}

enum PetEyeColorMode: String, CaseIterable, Codable {
    case automatic
    case black
    case white
}

struct NormalizedVisualPoint: Equatable, Codable {
    var x: Double
    var y: Double

    static let center = NormalizedVisualPoint(x: 0.5, y: 0.5)
}

struct NormalizedVisualOffset: Equatable, Codable {
    var x: Double
    var y: Double

    static let zero = NormalizedVisualOffset(x: 0, y: 0)
}

struct PetEyeModuleConfiguration: Equatable, Codable {
    var kind: PetEyeModuleKind
    var center: NormalizedVisualPoint
    var scale: Double
    var spacing: Double
    var rightEyeOffsetY: Double?
    var leftEyeOffset: NormalizedVisualOffset?
    var rightEyeOffset: NormalizedVisualOffset?
    var colorMode: PetEyeColorMode?
    var outerEyeScale: Double?
    var pupilScale: Double?

    init(
        kind: PetEyeModuleKind,
        center: NormalizedVisualPoint = .center,
        scale: Double = 1,
        spacing: Double = 11,
        rightEyeOffsetY: Double? = nil,
        leftEyeOffset: NormalizedVisualOffset? = nil,
        rightEyeOffset: NormalizedVisualOffset? = nil,
        colorMode: PetEyeColorMode? = nil,
        outerEyeScale: Double? = nil,
        pupilScale: Double? = nil
    ) {
        self.kind = kind
        self.center = center
        self.scale = scale
        self.spacing = spacing
        self.rightEyeOffsetY = rightEyeOffsetY
        self.leftEyeOffset = leftEyeOffset
        self.rightEyeOffset = rightEyeOffset
        self.colorMode = colorMode
        self.outerEyeScale = outerEyeScale
        self.pupilScale = pupilScale
    }

    var resolvedColorMode: PetEyeColorMode {
        colorMode ?? .automatic
    }

    var resolvedOuterEyeScale: Double {
        outerEyeScale ?? 1
    }

    var resolvedPupilScale: Double {
        pupilScale ?? 1
    }

    var areEyesAligned: Bool {
        leftEyeOffset == nil && rightEyeOffset == nil
    }

    mutating func setEyesAligned(_ isAligned: Bool) {
        if isAligned {
            leftEyeOffset = nil
            rightEyeOffset = nil
        } else {
            leftEyeOffset = leftEyeOffset ?? .zero
            rightEyeOffset = rightEyeOffset ?? .zero
        }
    }

    func eyeStyles(for expression: PetExpression) -> (left: EyeStyle, right: EyeStyle) {
        switch kind {
        case .expressionDriven:
            return (expression.leftEye, expression.rightEye)
        case .tracking:
            return (.round, .round)
        case .happy:
            return (.smile, .smile)
        case .scared:
            return (.chevronRight, .chevronLeft)
        case .sleeping:
            return (.invertedSmile, .invertedSmile)
        case .eating:
            return (.sleepy, .sleepy)
        }
    }

    func followsMouse(for expression: PetExpression) -> Bool {
        switch kind {
        case .expressionDriven:
            return expression.allowsMouseGaze
        case .tracking:
            return true
        case .happy, .scared, .sleeping, .eating:
            return false
        }
    }

    var allowsBlinking: Bool {
        switch kind {
        case .expressionDriven, .tracking:
            return true
        case .happy, .scared, .sleeping, .eating:
            return false
        }
    }
}

struct PetStateVisualConfiguration: Equatable, Codable {
    var base: PetBaseVisualSource
    var eyes: PetEyeModuleConfiguration?
    var baseOffset: NormalizedVisualOffset? = nil
}

struct PetVisualConfiguration: Equatable, Codable {
    private var states: [PetVisualState: PetStateVisualConfiguration]

    init(states: [PetVisualState: PetStateVisualConfiguration]) {
        self.states = states
    }

    func configuration(for state: PetVisualState) -> PetStateVisualConfiguration {
        states[state] ?? states[.normal] ?? Self.fallbackState
    }

    var referencedAssetIDs: Set<String> {
        Set(
            states.values.compactMap { state in
                guard case let .importedAsset(id) = state.base else { return nil }
                return id
            }
        )
    }

    mutating func setConfiguration(
        _ configuration: PetStateVisualConfiguration,
        for state: PetVisualState
    ) {
        states[state] = configuration
    }

    mutating func removeConfiguration(for state: PetVisualState) {
        guard state != .normal else { return }
        states.removeValue(forKey: state)
    }

    func fillingMissingStates(from defaults: PetVisualConfiguration) -> PetVisualConfiguration {
        var result = self
        for state in PetVisualState.allCases where result.states[state] == nil {
            result.states[state] = defaults.configuration(for: state)
        }
        return result
    }

    private static let fallbackState = PetStateVisualConfiguration(
        base: .officialSkin,
        eyes: nil
    )
}

enum PetVisualDefaults {
    static func configuration(petID: String, skinID: String) -> PetVisualConfiguration {
        switch petID {
        case PetCatalog.frog.id:
            return frog
        case PetCatalog.cat.id:
            return cat(skinID: skinID)
        default:
            return cube
        }
    }

    static let cube = PetVisualConfiguration(
        states: [
            .normal: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(kind: .expressionDriven)
            ),
            .happy: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(kind: .happy)
            ),
            .scared: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(kind: .scared)
            ),
            .sleeping: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(kind: .sleeping)
            ),
            .eating: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(kind: .eating)
            )
        ]
    )

    static let frog = configuration(
        eyeLayout: PetEyeModuleConfiguration(
            kind: .expressionDriven,
            center: NormalizedVisualPoint(x: 33.5 / 66, y: 19.3 / 66),
            spacing: 4.2,
            rightEyeOffsetY: 0.5
        )
    )

    static func cat(skinID: String) -> PetVisualConfiguration {
        switch skinID {
        case "cat.classic":
            return orangeTabby
        case "cat.siamese":
            return siamese
        default:
            return configuration(eyeLayout: catEyeLayout(skinID: skinID))
        }
    }

    // Promoted from the visual editor so first-time users see the approved
    // orange tabby layout for every state without needing a local override.
    private static let orangeTabby = PetVisualConfiguration(
        states: [
            .normal: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .expressionDriven,
                    center: NormalizedVisualPoint(
                        x: 0.49242424242424243,
                        y: 0.3181818181818182
                    ),
                    scale: 1,
                    spacing: -1.2937959558823522,
                    outerEyeScale: 1.2254566865808822,
                    pupilScale: 0.8321030560661764
                )
            ),
            .happy: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .happy,
                    center: NormalizedVisualPoint(
                        x: 0.4916942866161616,
                        y: 0.32733585858585856
                    ),
                    scale: 1,
                    spacing: -0.8687040441176457
                )
            ),
            .scared: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .scared,
                    center: NormalizedVisualPoint(
                        x: 0.49242424242424243,
                        y: 0.3181818181818182
                    ),
                    scale: 0.841021369485294,
                    spacing: -0.8755974264705877,
                    colorMode: .black
                )
            ),
            .sleeping: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .sleeping,
                    center: NormalizedVisualPoint(
                        x: 0.49242424242424243,
                        y: 0.3181818181818182
                    ),
                    scale: 1,
                    spacing: -2.8
                )
            ),
            .eating: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .eating,
                    center: NormalizedVisualPoint(
                        x: 0.49242424242424243,
                        y: 0.3181818181818182
                    ),
                    scale: 1,
                    spacing: -2.8
                )
            )
        ]
    )

    // Promoted from the visual editor so first-time users see the approved
    // eye placement for every Siamese state without needing a local override.
    private static let siamese = PetVisualConfiguration(
        states: [
            .normal: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .expressionDriven,
                    center: NormalizedVisualPoint(
                        x: 0.43367266414141414,
                        y: 0.3266256313131313
                    ),
                    spacing: -2.8
                )
            ),
            .happy: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .happy,
                    center: NormalizedVisualPoint(
                        x: 0.43211410984848486,
                        y: 0.35108901515151514
                    ),
                    spacing: -2.8
                )
            ),
            .scared: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .scared,
                    center: NormalizedVisualPoint(
                        x: 0.4321338383838384,
                        y: 0.3512863005050505
                    ),
                    scale: 0.743798828125,
                    spacing: -0.1447265625000007
                )
            ),
            .sleeping: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .sleeping,
                    center: NormalizedVisualPoint(
                        x: 0.43406723484848486,
                        y: 0.3385022095959596
                    ),
                    spacing: -2.8
                )
            ),
            .eating: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .eating,
                    center: NormalizedVisualPoint(
                        x: 0.43367266414141414,
                        y: 0.3266256313131313
                    ),
                    spacing: -2.8
                )
            )
        ]
    )

    private static func configuration(
        eyeLayout: PetEyeModuleConfiguration
    ) -> PetVisualConfiguration {
        var happyEyes = eyeLayout
        happyEyes.kind = .happy

        var scaredEyes = eyeLayout
        scaredEyes.kind = .scared

        var sleepingEyes = eyeLayout
        sleepingEyes.kind = .sleeping

        var eatingEyes = eyeLayout
        eatingEyes.kind = .eating

        return PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: eyeLayout
                ),
                .happy: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: happyEyes
                ),
                .scared: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: scaredEyes
                ),
                .sleeping: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: sleepingEyes
                ),
                .eating: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: eatingEyes
                )
            ]
        )
    }

    private static func catEyeLayout(skinID: String) -> PetEyeModuleConfiguration {
        let offsets: (x: Double, y: Double) = switch skinID {
        case "cat.grayTabby": (-1.3, -17.2)
        case "cat.calico": (-3.8, -14.0)
        case "cat.black": (-1.5, -13.5)
        default: (0, -12.0)
        }

        return PetEyeModuleConfiguration(
            kind: .expressionDriven,
            center: NormalizedVisualPoint(
                x: (32.5 + offsets.x) / 66,
                y: (33 + offsets.y) / 66
            ),
            spacing: -2.8
        )
    }
}
