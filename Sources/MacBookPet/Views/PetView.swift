import SwiftUI

struct PetView: View {
    @ObservedObject var state: PetState
    @ObservedObject var motionState: PetMotionState
    @ObservedObject var appearanceSettings: PetAppearanceSettings
    @ObservedObject var languageSettings: LanguageSettings

    @State private var isPressed = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let isSleeping = state.expression == .sleeping
            let isListening = state.expression == .listening
            let breathScale = sleepingBreathScale(at: timeline.date, isSleeping: isSleeping)
            let listeningMotion = listeningMotion(at: timeline.date, isListening: isListening)

            ZStack(alignment: .bottomLeading) {
                Color.clear

                petBody(breathScale: breathScale, listeningRotation: listeningMotion.rotation)
                    .offset(
                        x: PetMetrics.bodyInsetX + listeningMotion.x,
                        y: -PetMetrics.bodyInsetY + listeningMotion.y + groundAlignmentOffset
                    )

                if isSleeping {
                    SleepBubblesView(date: timeline.date)
                        .allowsHitTesting(false)
                }

                if isListening {
                    MusicNotesView(date: timeline.date)
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
            }
            .contentShape(Rectangle())
            .onChange(of: state.expression) { _, expression in
                if expression == .happy {
                    pulse()
                }
            }
        }
        .frame(width: PetMetrics.canvasWidth, height: PetMetrics.canvasHeight)
    }

    private func petBody(breathScale: CGFloat, listeningRotation: CGFloat) -> some View {
        let mouthOpen = motionState.feedMouthOpen

        return ZStack {
            switch appearanceSettings.selectedPet.visualKind {
            case .cube:
                cubeBody(mouthOpen: mouthOpen)
            case .frog:
                FrogPetView(
                    expression: state.expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    mouthOpen: mouthOpen
                )
            case .cat:
                CatPetView(
                    expression: state.expression,
                    isBlinking: state.isBlinking,
                    gazeOffset: motionState.gazeOffset,
                    mouthOpen: mouthOpen,
                    skinID: appearanceSettings.selectedSkinID
                )
            }
        }
        .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
        .padding(PetMetrics.bodyPadding)
        .scaleEffect(isPressed ? 0.96 : 1)
        .scaleEffect(x: motionState.stretchX, y: motionState.stretchY)
        .scaleEffect(x: 1, y: breathScale, anchor: .bottom)
        .rotationEffect(.degrees(motionState.rotationDegrees + listeningRotation))
        .animation(.easeInOut(duration: 0.25), value: appearanceSettings.selectedSkinID)
        .animation(.easeInOut(duration: 0.25), value: appearanceSettings.selectedPetID)
    }

    private var groundAlignmentOffset: CGFloat {
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
            default: 10.8
            }
        }
    }

    private func cubeBody(mouthOpen: CGFloat) -> some View {
        ZStack {
            cubeBodyShape(
                mouthOpen: mouthOpen,
                color: Color(nsColor: appearanceSettings.selectedSkin.color)
            )

            HStack(spacing: mouthOpen > 0.02 ? 9 : state.expression.eyeSpacing) {
                EyeView(style: mouthOpen > 0.02 ? .sleepy : state.expression.leftEye, isBlinking: mouthOpen > 0.02 ? false : state.isBlinking)
                EyeView(style: mouthOpen > 0.02 ? .sleepy : state.expression.rightEye, isBlinking: mouthOpen > 0.02 ? false : state.isBlinking)
            }
            .offset(
                x: mouthOpen > 0.02 ? 0 : motionState.gazeOffset.width,
                y: eyeVerticalOffset(mouthOpen: mouthOpen)
            )
            .animation(.easeOut(duration: 0.10), value: motionState.gazeOffset)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: mouthOpen)
        }
    }

    @ViewBuilder
    private func cubeBodyShape(mouthOpen: CGFloat, color: Color) -> some View {
        if mouthOpen > 0.01 {
            let bodySize = PetMetrics.bodyContentSize
            let lowerHeight = bodySize * 0.34
            let upperHeight = bodySize - lowerHeight
            let gap = 3 + mouthOpen * 17

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: PetMetrics.cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(width: bodySize, height: lowerHeight)

                RoundedRectangle(cornerRadius: PetMetrics.cornerRadius, style: .continuous)
                    .fill(color)
                    .frame(width: bodySize, height: upperHeight)
                    .offset(y: -(lowerHeight + gap))
            }
            .frame(width: bodySize, height: bodySize, alignment: .bottom)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: mouthOpen)
        } else {
            RoundedRectangle(cornerRadius: PetMetrics.cornerRadius, style: .continuous)
                .fill(color)
        }
    }

    private func eyeVerticalOffset(mouthOpen: CGFloat) -> CGFloat {
        guard mouthOpen > 0.02 else {
            return state.expression.verticalOffset + motionState.gazeOffset.height
        }

        return -9 - mouthOpen * 13
    }

    private func sleepingBreathScale(at date: Date, isSleeping: Bool) -> CGFloat {
        guard isSleeping else { return 1 }

        let wave = (sin(date.timeIntervalSinceReferenceDate * 1.55) + 1) / 2
        return 0.94 + CGFloat(wave) * 0.08
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
