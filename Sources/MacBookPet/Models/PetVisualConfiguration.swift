import Foundation

enum PetVisualState: String, CaseIterable, Codable {
    case normal
    case happy
    case scared
    case sleeping
    case eating
    case hungry

    init(expression: PetExpression) {
        switch expression {
        case .happy:
            self = .happy
        case .scared:
            self = .scared
        case .sleeping:
            self = .sleeping
        case .hungry:
            self = .hungry
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
    case hungry
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
        case .hungry:
            return (.annoyedRight, .annoyedLeft)
        }
    }

    func followsMouse(for expression: PetExpression) -> Bool {
        switch kind {
        case .expressionDriven:
            return expression.allowsMouseGaze
        case .tracking:
            return true
        case .happy, .scared, .sleeping, .eating, .hungry:
            return false
        }
    }

    var allowsBlinking: Bool {
        switch kind {
        case .expressionDriven, .tracking:
            return true
        case .happy, .scared, .sleeping, .eating, .hungry:
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
            ),
            .hungry: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(kind: .hungry)
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
        case "cat.grayTabby":
            return grayTabby
        case "cat.calico":
            return calico
        case "cat.black":
            return black
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
                ),
                baseOffset: NormalizedVisualOffset(x: 0, y: 0.14393939393939387)
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
            ),
            .hungry: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .hungry,
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

    // Promoted from the approved in-app layout so new users receive the
    // complete greedy-cat expression set without a saved local override.
    private static let grayTabby = PetVisualConfiguration(
        states: [
            .normal: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .expressionDriven,
                    center: NormalizedVisualPoint(
                        x: 0.46894728535353536,
                        y: 0.19986979166666666
                    ),
                    scale: 1,
                    spacing: -1.972794117647057,
                    pupilScale: 0.677734375
                )
            ),
            .happy: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .happy,
                    center: NormalizedVisualPoint(
                        x: 0.4727272727272727,
                        y: 0.2393939393939394
                    ),
                    scale: 1,
                    spacing: -2.8
                )
            ),
            .scared: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .scared,
                    center: NormalizedVisualPoint(
                        x: 0.46888809974747475,
                        y: 0.22492503156565657
                    ),
                    scale: 0.7711827895220588,
                    spacing: 0.3169577205882348
                )
            ),
            .sleeping: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .sleeping,
                    center: NormalizedVisualPoint(
                        x: 0.4727272727272727,
                        y: 0.2393939393939394
                    ),
                    scale: 1,
                    spacing: -2.8
                ),
                baseOffset: NormalizedVisualOffset(x: 0, y: 0.06060606060606061)
            ),
            .eating: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .eating,
                    center: NormalizedVisualPoint(
                        x: 0.4727272727272727,
                        y: 0.2393939393939394
                    ),
                    scale: 1,
                    spacing: -2.8
                )
            ),
            .hungry: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .hungry,
                    center: NormalizedVisualPoint(
                        x: 0.4727272727272727,
                        y: 0.2393939393939394
                    ),
                    scale: 1,
                    spacing: -2.8
                )
            )
        ]
    )

    // Promoted from the current approved editor layout so new users receive
    // the complete calico expression set without a saved local override.
    private static let calico = PetVisualConfiguration(
        states: [
            .normal: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .expressionDriven,
                    center: NormalizedVisualPoint(x: 0.4424715909090909, y: 0.27434501262626265),
                    spacing: -2.8,
                    pupilScale: 0.6925551470588235
                )
            ),
            .happy: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .happy,
                    center: NormalizedVisualPoint(x: 0.44566761363636365, y: 0.28963462752525254),
                    spacing: -2.8
                )
            ),
            .scared: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .scared,
                    center: NormalizedVisualPoint(x: 0.4424715909090909, y: 0.2913510101010101),
                    scale: 0.7367589613970588,
                    spacing: 1.388878676470588
                )
            ),
            .sleeping: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .sleeping,
                    center: NormalizedVisualPoint(x: 0.5726996527777778, y: 0.6857244318181818),
                    spacing: -2.8
                ),
                baseOffset: NormalizedVisualOffset(x: 0, y: 0.14393939393939387)
            ),
            .eating: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .eating,
                    center: NormalizedVisualPoint(x: 0.4514875315656566, y: 0.3271977588383838),
                    spacing: -2.8,
                    outerEyeScale: 0.917580997242647,
                    pupilScale: 0.641802619485294
                )
            ),
            .hungry: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .hungry,
                    center: NormalizedVisualPoint(x: 0.4348484848484848, y: 0.2878787878787879),
                    spacing: -2.8
                )
            )
        ]
    )

    // Promoted from the current approved editor layout so new users receive
    // the complete black-cat expression set without a saved local override.
    private static let black = PetVisualConfiguration(
        states: [
            .normal: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .expressionDriven,
                    center: NormalizedVisualPoint(x: 0.46705334595959597, y: 0.2916074810606061),
                    spacing: -2.8
                )
            ),
            .happy: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .happy,
                    center: NormalizedVisualPoint(x: 0.4644689078282828, y: 0.30567392676767674),
                    scale: 0.8814338235294117,
                    spacing: -1.2708180147058812
                )
            ),
            .scared: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .scared,
                    center: NormalizedVisualPoint(x: 0.46519886363636365, y: 0.3057528409090909),
                    scale: 0.6742446001838235,
                    spacing: 0.5226102941176496
                )
            ),
            .sleeping: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .sleeping,
                    center: NormalizedVisualPoint(x: 0.47149226641414144, y: 0.29987373737373735),
                    scale: 0.7970329733455882,
                    spacing: 0.09866727941176556
                ),
                baseOffset: NormalizedVisualOffset(x: 0, y: 0.20454545454545442)
            ),
            .eating: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .eating,
                    center: NormalizedVisualPoint(x: 0.4696969696969697, y: 0.29545454545454547),
                    spacing: -2.8
                )
            ),
            .hungry: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .hungry,
                    center: NormalizedVisualPoint(x: 0.4696969696969697, y: 0.29545454545454547),
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
                ),
                baseOffset: NormalizedVisualOffset(x: 0, y: 0.16666666666666657)
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
            ),
            .hungry: PetStateVisualConfiguration(
                base: .officialSkin,
                eyes: PetEyeModuleConfiguration(
                    kind: .hungry,
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

        var hungryEyes = eyeLayout
        hungryEyes.kind = .hungry

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
                ),
                .hungry: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: hungryEyes
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
