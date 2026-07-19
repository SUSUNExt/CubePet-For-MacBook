import SwiftUI

private struct ActiveActionPlayback: Equatable {
    let assetID: String
    let state: PetVisualState
}

struct PetView: View {
    @ObservedObject var state: PetState
    @ObservedObject var motionState: PetMotionState
    @ObservedObject var hungerStore: PetHungerStore
    @ObservedObject var appearanceSettings: PetAppearanceSettings
    @ObservedObject var customizationStore: PetCustomizationStore
    @ObservedObject var languageSettings: LanguageSettings

    @State private var isPressed = false
    @State private var activeActionPlayback: ActiveActionPlayback?
    @State private var actionPlaybackTask: Task<Void, Never>?

    var body: some View {
        Group {
            if needsTimelineUpdates {
                TimelineView(.animation) { timeline in
                    petContent(at: timeline.date)
                }
            } else {
                petContent(at: .now)
            }
        }
        .contentShape(Rectangle())
        .onChange(of: state.expression) { _, expression in
            if expression == .happy {
                pulse()
            }
        }
        .onAppear(perform: restartActionPlaybackLoop)
        .onDisappear {
            actionPlaybackTask?.cancel()
            actionPlaybackTask = nil
        }
        .onChange(of: activeVisualConfiguration) { _, _ in
            restartActionPlaybackLoop()
        }
        .frame(width: PetMetrics.canvasWidth, height: PetMetrics.canvasHeight)
    }

    private var needsTimelineUpdates: Bool {
        switch visualExpression {
        case .sleeping, .listening:
            return true
        default:
            return false
        }
    }

    private func petContent(at date: Date) -> some View {
        let expression = visualExpression
        let isSleeping = expression == .sleeping
        let isListening = expression == .listening
        let sleepingConfiguration = activeVisualConfiguration.configuration(for: .sleeping)
        let sleepingBreathEnabled = sleepingConfiguration.resolvedSleepingBreathEnabled
            && supportsSleepingBreath(for: sleepingConfiguration)
        let breathScale = sleepingBreathScale(
            at: date,
            isSleeping: isSleeping && sleepingBreathEnabled
        )
        let listeningMotion = listeningMotion(at: date, isListening: isListening)

        return ZStack(alignment: .bottomLeading) {
            Color.clear

            petBody(breathScale: breathScale, listeningRotation: listeningMotion.rotation)
                .offset(
                    x: PetMetrics.bodyInsetX + listeningMotion.x,
                    y: -PetMetrics.bodyInsetY + listeningMotion.y + groundAlignmentOffset
                )

            if isSleeping {
                sleepEffectView(
                    sleepingConfiguration.resolvedSleepingEffect,
                    date: date
                )
                    .allowsHitTesting(false)
            }

            if isListening {
                MusicNotesView(date: date)
                    .allowsHitTesting(false)
            }

            if let effect = motionState.experienceGainEffect {
                ExperienceGainView(
                    text: languageSettings.experienceGainText(effect.amount)
                )
                .id(effect.id)
                .position(
                    x: PetMetrics.bodyInsetX + PetMetrics.bodySize / 2,
                    y: PetMetrics.canvasHeight - PetMetrics.bodyInsetY - PetMetrics.bodySize - 8
                )
                .allowsHitTesting(false)
            }

            if let effect = motionState.satietyGainEffect {
                ExperienceGainView(
                    text: languageSettings.satietyGainText(effect.amount)
                )
                .id(effect.id)
                .position(
                    x: PetMetrics.bodyInsetX + PetMetrics.bodySize / 2,
                    y: PetMetrics.canvasHeight - PetMetrics.bodyInsetY - PetMetrics.bodySize - 26
                )
                .allowsHitTesting(false)
            }
        }
    }

    private func petBody(breathScale: CGFloat, listeningRotation: CGFloat) -> some View {
        let mouthOpen = motionState.feedMouthOpen
        let expression = visualExpression
        let configuration = activeVisualConfiguration
        let visualState: PetVisualState = mouthOpen > 0.02
            ? .eating
            : PetVisualState(expression: expression)
        let stateConfiguration = configuration.configuration(
            for: visualState
        )
        let appliesVerticalBaseOffsetInView = true
        let customEyeAsset = stateConfiguration.eyes?.customAssetID.flatMap {
            customizationStore.importedVisualAsset(for: $0)
        }

        return ZStack {
            if let action = activeActionPlayback, action.state == visualState {
                ImportedPetVisualView(
                    asset: customizationStore.importedVisualAsset(for: action.assetID),
                    baseOffset: stateConfiguration.baseOffset,
                    animationPlaybackRate: stateConfiguration.actionAnimationPlaybackRate,
                    configuration: stateConfiguration.eyes,
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
            } else if case let .importedAsset(assetID) = stateConfiguration.base {
                ImportedPetVisualView(
                    asset: customizationStore.importedVisualAsset(for: assetID),
                    baseOffset: stateConfiguration.baseOffset,
                    animationPlaybackRate: stateConfiguration.animationPlaybackRate,
                    configuration: stateConfiguration.eyes,
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
            } else if appearanceSettings.isCustomPetSelected {
                ImportedPetVisualView(
                    asset: nil,
                    baseOffset: stateConfiguration.baseOffset,
                    animationPlaybackRate: stateConfiguration.animationPlaybackRate,
                    configuration: stateConfiguration.eyes,
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
            } else {
                switch appearanceSettings.selectedPet.visualKind {
            case .cube:
                CubePetView(
                    color: Color(nsColor: appearanceSettings.selectedSkin.color),
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    mouthOpen: mouthOpen,
                    visualConfiguration: configuration,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
            case .frog:
                FrogPetView(
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    mouthOpen: mouthOpen,
                    visualConfiguration: configuration,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
            case .cat:
                CatPetView(
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    mouthOpen: mouthOpen,
                    skinID: appearanceSettings.selectedSkinID,
                    visualConfiguration: configuration,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
            case .shiba:
                ShibaPetView(
                    expression: expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    mouthOpen: mouthOpen,
                    visualConfiguration: configuration,
                    customEyeAsset: customEyeAsset,
                    appliesVerticalBaseOffsetInView: appliesVerticalBaseOffsetInView
                )
                }
            }
        }
        .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
        .padding(PetMetrics.bodyPadding)
        .scaleEffect(CGFloat(stateConfiguration.resolvedBaseScale), anchor: .bottom)
        .scaleEffect(isPressed ? 0.96 : 1)
        .scaleEffect(x: motionState.stretchX, y: motionState.stretchY)
        .scaleEffect(x: 1, y: breathScale, anchor: .bottom)
        .rotationEffect(.degrees(motionState.rotationDegrees + listeningRotation))
        .animation(.easeInOut(duration: 0.25), value: appearanceSettings.selectedSkinID)
        .animation(.easeInOut(duration: 0.25), value: appearanceSettings.selectedPetID)
    }

    @ViewBuilder
    private func sleepEffectView(_ effect: PetSleepingEffect, date: Date) -> some View {
        switch effect {
        case .bubbles:
            SleepBubblesView(date: date)
        case .zzz:
            SleepZzzView(date: date)
        }
    }

    private var activeVisualConfiguration: PetVisualConfiguration {
        if let customPet = customizationStore.customPet(id: appearanceSettings.selectedPetID) {
            return customPet.visualConfiguration
        }

        let official = PetVisualDefaults.configuration(
            petID: appearanceSettings.selectedPetID,
            skinID: appearanceSettings.selectedSkinID
        )
        return customizationStore.visualConfiguration(
            petID: appearanceSettings.selectedPetID,
            skinID: appearanceSettings.selectedSkinID,
            official: official
        )
    }

    private var visualExpression: PetExpression {
        Self.visualExpression(
            base: state.expression,
            isHungry: hungerStore.isHungry,
            isEating: motionState.feedMouthOpen > 0.02
        )
    }

    private func restartActionPlaybackLoop() {
        actionPlaybackTask?.cancel()
        actionPlaybackTask = nil
        activeActionPlayback = nil

        actionPlaybackTask = Task {
            while !Task.isCancelled {
                let expression = visualExpression
                let visualState: PetVisualState = motionState.feedMouthOpen > 0.02
                    ? .eating
                    : PetVisualState(expression: expression)
                let configuration = activeVisualConfiguration.configuration(for: visualState)
                let actionAssetIDs = configuration.resolvedActionAssetIDs
                guard !actionAssetIDs.isEmpty else { return }

                let delay = randomActionDelay(for: configuration.resolvedActionFrequency)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled,
                      let actionAssetID = actionAssetIDs.randomElement(),
                      let asset = customizationStore.importedVisualAsset(for: actionAssetID)
                else { continue }

                activeActionPlayback = ActiveActionPlayback(
                    assetID: actionAssetID,
                    state: visualState
                )
                try? await Task.sleep(
                    nanoseconds: UInt64(asset.playbackDuration * 1_000_000_000)
                )
                if !Task.isCancelled {
                    activeActionPlayback = nil
                }
            }
        }
    }

    private func randomActionDelay(for frequency: PetActionFrequency) -> TimeInterval {
        switch frequency {
        case .low: Double.random(in: 18...30)
        case .medium: Double.random(in: 10...18)
        case .high: Double.random(in: 4...8)
        }
    }

    static func visualExpression(
        base expression: PetExpression,
        isHungry: Bool,
        isEating: Bool
    ) -> PetExpression {
        // Hunger is the persistent idle appearance. It should remain visible
        // even if the underlying interaction state is sleeping, listening, or
        // temporarily reacting to a grab; only active eating takes precedence.
        guard !isEating, isHungry else {
            return expression
        }
        return .hungry
    }

    private var groundAlignmentOffset: CGFloat {
        if appearanceSettings.isCustomPetSelected {
            return 5
        }
        // Align each pet's visible bottom, including PNG transparency, with the physics floor.
        switch appearanceSettings.selectedPet.visualKind {
        case .cube:
            return 5
        case .frog:
            return 17.8
        case .cat:
            return switch appearanceSettings.selectedSkinID {
            case "cat.grayTabby": 15.4
            case "cat.calico": 11.4
            case "cat.yellow": 12.6
            default: 10.8
            }
        case .shiba:
            return 10.8
        }
    }

    private func sleepingBreathScale(at date: Date, isSleeping: Bool) -> CGFloat {
        guard isSleeping else { return 1 }

        let wave = (sin(date.timeIntervalSinceReferenceDate * 1.55) + 1) / 2
        return 0.94 + CGFloat(wave) * 0.08
    }

    private func supportsSleepingBreath(for configuration: PetStateVisualConfiguration) -> Bool {
        guard case let .importedAsset(assetID) = configuration.base else { return true }
        return customizationStore.importedVisualAsset(for: assetID)?.supportsSleepingBreath == true
    }

    private func listeningMotion(at date: Date, isListening: Bool) -> (x: CGFloat, y: CGFloat, rotation: CGFloat) {
        guard isListening else { return (0, 0, 0) }

        let phase = date.timeIntervalSinceReferenceDate * 4.4
        return (
            x: CGFloat(sin(phase)) * 2.4,
            y: -abs(CGFloat(sin(phase))) * 2.0,
            rotation: CGFloat(sin(phase)) * 1.8
        )
    }

    private func pulse() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
                isPressed = false
            }
        }
    }
}

private struct ExperienceGainView: View {
    let text: String

    @State private var opacity = 0.0
    @State private var verticalOffset: CGFloat = 8

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            .opacity(opacity)
            .offset(y: verticalOffset)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    opacity = 1
                    verticalOffset = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                    withAnimation(.easeInOut(duration: 0.58)) {
                        opacity = 0
                        verticalOffset = -26
                    }
                }
            }
    }
}
