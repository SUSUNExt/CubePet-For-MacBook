import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum PreviewEditablePart: Equatable {
    case body
    case alignedEyes
    case left
    case right
}

private enum ImportedAssetDestination {
    case defaultVisual
    case action
}

private struct EditorButtonHoverFeedback: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                isHovering ? Color.accentColor.opacity(0.14) : .clear,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

private extension View {
    func editorButtonHoverFeedback(cornerRadius: CGFloat = 6) -> some View {
        modifier(EditorButtonHoverFeedback(cornerRadius: cornerRadius))
    }
}

private struct FrameReorderDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var draggedFrameIndex: Int?
    @Binding var dropTargetIndex: Int?
    let moveFrame: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard draggedFrameIndex != nil else { return }
        dropTargetIndex = destinationIndex
    }

    func dropExited(info: DropInfo) {
        guard dropTargetIndex == destinationIndex else { return }
        dropTargetIndex = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedFrameIndex = nil
            dropTargetIndex = nil
        }
        guard let sourceIndex = draggedFrameIndex, sourceIndex != destinationIndex else {
            return false
        }
        moveFrame(sourceIndex, destinationIndex)
        return true
    }
}

struct PetCustomizationEditorView: View {
    @ObservedObject var customizationStore: PetCustomizationStore
    @ObservedObject var appearanceSettings: PetAppearanceSettings
    @ObservedObject var progressStore: PetProgressStore
    @ObservedObject var languageSettings: LanguageSettings

    @State private var target: PetEditorTarget? = .currentAppearance
    @State private var selectedState = PetVisualState.normal
    @State private var draft: PetVisualConfiguration
    @State private var petName = ""
    @State private var statusMessage: String?
    @State private var isShowingDeleteConfirmation = false
    @State private var selectedPreviewPart: PreviewEditablePart = .body
    @State private var draggedPreviewPart: PreviewEditablePart?
    @State private var dragStartBodyOffset = NormalizedVisualOffset.zero
    @State private var dragStartEyeCenter = NormalizedVisualPoint.center
    @State private var dragStartLeftOffset = NormalizedVisualOffset.zero
    @State private var dragStartRightOffset = NormalizedVisualOffset.zero
    @State private var isDropTarget = false
    @State private var isActionDropTarget = false
    @State private var isShowingActionPicker = false
    @State private var isShowingSleepingBreathHint = false
    @State private var isShowingStaticEditor = false
    @State private var isShowingEyeEditor = false
    @State private var isShowingEyePresetRename = false
    @State private var eyePresetName = ""
    @State private var isShowingAnimationEditor = false
    @State private var draggedFrameIndex: Int?
    @State private var hoveredFrameIndex: Int?
    @State private var frameDropTargetIndex: Int?
    @State private var frameOrderRevision = UUID()
    @State private var undoHistory: [PetVisualConfiguration] = []
    @State private var redoHistory: [PetVisualConfiguration] = []
    @State private var historyTransactionBaseline: PetVisualConfiguration?

    private let previewScaleStep = 0.05

    init(
        customizationStore: PetCustomizationStore,
        appearanceSettings: PetAppearanceSettings,
        progressStore: PetProgressStore,
        languageSettings: LanguageSettings
    ) {
        self.customizationStore = customizationStore
        self.appearanceSettings = appearanceSettings
        self.progressStore = progressStore
        self.languageSettings = languageSettings

        if
            appearanceSettings.isCustomPetSelected,
            let customPet = customizationStore.customPet(id: appearanceSettings.selectedPetID)
        {
            _draft = State(initialValue: customPet.visualConfiguration)
            _petName = State(initialValue: customPet.name)
        } else {
            let official = PetVisualDefaults.configuration(
                petID: appearanceSettings.selectedPetID,
                skinID: appearanceSettings.selectedSkinID
            )
            _draft = State(initialValue: customizationStore.visualConfiguration(
                petID: appearanceSettings.selectedPetID,
                skinID: appearanceSettings.selectedSkinID,
                official: official
            ))
        }
    }

    var body: some View {
        HSplitView {
            PetCustomizationSidebarView(
                selection: $target,
                progressStore: progressStore,
                customizationStore: customizationStore,
                languageSettings: languageSettings
            )

            editorDetail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: target) { _, newTarget in
            guard let newTarget else { return }
            load(newTarget)
        }
        .confirmationDialog(
            label(.deletePetConfirmation),
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(label(.deletePet), role: .destructive, action: deletePet)
            Button(label(.cancel), role: .cancel) {}
        } message: {
            Text(label(.deletePetWarning))
        }
        .frame(minWidth: 820, minHeight: 600)
    }

    private var editorDetail: some View {
        VStack(spacing: 0) {
            if isCustomTarget {
                TextField(label(.petName), text: $petName)
                    .textFieldStyle(.roundedBorder)
                    .padding([.top, .horizontal])
            }

            Picker("", selection: $selectedState) {
                Text(label(.normal)).tag(PetVisualState.normal)
                Text(label(.happy)).tag(PetVisualState.happy)
                Text(label(.scared)).tag(PetVisualState.scared)
                Text(label(.sleeping)).tag(PetVisualState.sleeping)
                Text(label(.eating)).tag(PetVisualState.eating)
                Text(label(.hungry)).tag(PetVisualState.hungry)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            Divider()

            HStack(alignment: .top, spacing: 24) {
                previewColumn
                if isDeferredEditorControlsVisible {
                    deferredEditorControls
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, 24)

            Spacer(minLength: 0)
            Divider()

            HStack {
                Text(statusMessage ?? dragHintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if editingCustomPetID != nil {
                    Button(label(.deletePet), role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                }
                if isOfficialTarget {
                    Button(label(.restoreOfficial), action: restoreOfficial)
                }
                Button(label(.save), action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    // Keep the original inspector intact for a future editor layout.
    private var isDeferredEditorControlsVisible: Bool { false }

    private var deferredEditorControls: some View {
        Form {
            LabeledContent {
                HStack {
                    Button(label(.importImages), action: importImages)
                    if isOfficialTarget {
                        Button(label(.useOfficial), action: useOfficialSkin)
                    }
                }
            } label: {
                Image(systemName: "photo")
            }

            Toggle(label(.showEyes), isOn: eyesEnabledBinding)

            if currentStateConfiguration.eyes != nil {
                Toggle(label(.alignEyes), isOn: eyeAlignmentBinding)

                Picker(label(.eyeStyle), selection: eyeKindBinding) {
                    Text(label(.bigEyes)).tag(PetEyeModuleKind.catDefault)
                    Text(label(.smallBlackBlockEyes)).tag(PetEyeModuleKind.tracking)
                    Text(label(.shibaWatercolorEyes)).tag(PetEyeModuleKind.shibaWatercolor)
                    Text(label(.happy)).tag(PetEyeModuleKind.happy)
                    Text(label(.scared)).tag(PetEyeModuleKind.scared)
                    Text(label(.sleeping)).tag(PetEyeModuleKind.sleeping)
                    Text(label(.eating)).tag(PetEyeModuleKind.eating)
                    Text(label(.hungry)).tag(PetEyeModuleKind.hungry)
                }

                Picker(label(.eyeColor), selection: eyeColorBinding) {
                    Text(label(.automatic)).tag(PetEyeColorMode.automatic)
                    Text(label(.black)).tag(PetEyeColorMode.black)
                    Text(label(.white)).tag(PetEyeColorMode.white)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 330)
    }

    private var previewColumn: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label(.normal))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    defaultPreview
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(label(.smallActions))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    actionPreviewList
                }

                Divider()
                    .frame(height: 258)

                actionSettings
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Divider()
                .padding(.top, 22)

            eyeControls
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sliderRow(
        label key: PetCustomizationText,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(label(key))
                .frame(width: 68, alignment: .leading)
            Slider(value: value, in: range, onEditingChanged: updateHistoryTransaction)
        }
    }

    private var eyeControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(label(.eyes))
                Toggle("", isOn: eyesEnabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(usesFixedEyeArtwork)
            }

            if !usesFixedEyeArtwork, currentStateConfiguration.eyes != nil {
                HStack(spacing: 6) {
                    sliderRow(label: .size, value: eyeScaleBinding, range: 0.5...2)
                        .frame(width: 225)

                    Button {
                        isShowingEyeEditor = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 5))
                    .editorButtonHoverFeedback(cornerRadius: 5)
                    .popover(isPresented: $isShowingEyeEditor, arrowEdge: .bottom) {
                        eyeDetailEditor
                    }
                }

                eyeTypeControl
            }
        }
        .font(.callout)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .padding(.leading, 20)
        .frame(width: 300, alignment: .leading)
    }

    private var eyeTypeControl: some View {
        HStack(spacing: 6) {
            Text(label(.eyeStyle))
                .frame(width: 68, alignment: .leading)

            Menu {
                ForEach(
                    [
                        PetEyeModuleKind.catDefault,
                        .tracking,
                        .shibaWatercolor,
                        .happy,
                        .scared,
                        .sleeping
                    ],
                    id: \.self
                ) { kind in
                    Button(eyeTypeName(for: kind)) {
                        selectOfficialEyeType(kind)
                    }
                }

                if !customizationStore.eyePresets.isEmpty {
                    Section(label(.myEyePresets)) {
                        ForEach(customizationStore.eyePresets) { preset in
                            Button(preset.name) {
                                selectEyePreset(preset)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentEyeTypeName)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .frame(width: 112, alignment: .leading)
            }
            .menuStyle(.borderedButton)
            .controlSize(.small)

            Button(label(.importEyes), action: importEyePreset)
                .controlSize(.small)

            if currentEyePreset != nil {
                Button {
                    eyePresetName = currentEyePreset?.name ?? ""
                    isShowingEyePresetRename = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .editorButtonHoverFeedback()
                .help(label(.renameEyePreset))
                .popover(isPresented: $isShowingEyePresetRename, arrowEdge: .bottom) {
                    eyePresetRenameEditor
                }

                Button(role: .destructive, action: deleteCurrentEyePreset) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .editorButtonHoverFeedback()
                .help(label(.deleteEyePreset))
            }
        }
    }

    private var eyePresetRenameEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label(.renameEyePreset))
                .font(.headline)
            TextField(label(.presetName), text: $eyePresetName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(label(.cancel)) {
                    isShowingEyePresetRename = false
                }
                Button(label(.save), action: renameCurrentEyePreset)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private var defaultPreview: some View {
        defaultPreviewSurface
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        moveSelectedPart(
                            startingAt: value.startLocation,
                            translation: value.translation,
                            canvasSize: 230
                        )
                    }
                    .onEnded { _ in resetPreviewDrag() }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in selectPreviewPart(at: value.location, canvasSize: 230) }
            )
            .onDrop(
                of: [UTType.fileURL.identifier],
                isTargeted: $isDropTarget,
                perform: importDefaultDroppedItems
            )
    }

    private var defaultPreviewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDropTarget ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))

            petPreview(playsAnimation: true)
                .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
                .scaleEffect(3 * currentStateConfiguration.resolvedBaseScale)
                .id(frameOrderRevision)

            previewGuideGrid
            if hasPreviewImage {
                previewSelectionIndicator
            }
            previewNudgeControls

            if !hasPreviewImage {
                Text(label(.dropImagesHint))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }

            if currentImportedAsset != nil {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: clearCurrentPreviewImage) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 5))
                        .editorButtonHoverFeedback(cornerRadius: 5)
                        .help(label(.clearPreview))
                    }
                    Spacer()
                }
                .padding(8)
            }

            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 4) {
                        previewHistoryButton(
                            symbol: "arrow.uturn.backward",
                            label: .undo,
                            isEnabled: !undoHistory.isEmpty,
                            action: undo
                        )
                        previewHistoryButton(
                            symbol: "arrow.uturn.forward",
                            label: .redo,
                            isEnabled: !redoHistory.isEmpty,
                            action: redo
                        )
                    }

                    Spacer()
                    previewScaleControls
                    if currentImportedAsset?.isAnimated == true {
                        Button {
                            isShowingStaticEditor = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 5))
                        .editorButtonHoverFeedback(cornerRadius: 5)
                        .help(label(.animationSettings))
                        .popover(isPresented: $isShowingStaticEditor, arrowEdge: .bottom) {
                            defaultPreviewEditor
                        }
                    }
                }
            }
            .padding(8)

            if isDropTarget {
                Text(label(.dropImagesHint))
                    .font(.callout.weight(.semibold))
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .frame(width: 230, height: 230)
    }

    private var previewNudgeControls: some View {
        VStack {
            HStack {
                Spacer()
                previewNudgeButton(
                    symbol: "chevron.up",
                    label: .moveSkinUp,
                    action: { nudgeBody(deltaX: 0, deltaY: -previewNudgeStep) }
                )
                Spacer()
            }

            Spacer()

            HStack {
                previewNudgeButton(
                    symbol: "chevron.left",
                    label: .moveSkinLeft,
                    action: { nudgeBody(deltaX: -previewNudgeStep, deltaY: 0) }
                )
                Spacer()
                previewNudgeButton(
                    symbol: "chevron.right",
                    label: .moveSkinRight,
                    action: { nudgeBody(deltaX: previewNudgeStep, deltaY: 0) }
                )
            }

            Spacer()

            HStack {
                Spacer()
                previewNudgeButton(
                    symbol: "chevron.down",
                    label: .moveSkinDown,
                    action: { nudgeBody(deltaX: 0, deltaY: previewNudgeStep) }
                )
                Spacer()
            }
        }
        .padding(7)
    }

    private var previewScaleControls: some View {
        HStack(spacing: 4) {
            previewScaleButton(
                symbol: "minus",
                label: .decreaseSize,
                isEnabled: currentStateConfiguration.resolvedBaseScale > 0.5,
                action: { adjustBaseScale(by: -previewScaleStep) }
            )
            previewScaleButton(
                symbol: "plus",
                label: .increaseSize,
                isEnabled: currentStateConfiguration.resolvedBaseScale < 2,
                action: { adjustBaseScale(by: previewScaleStep) }
            )
        }
    }

    private func previewScaleButton(
        symbol: String,
        label key: PetCustomizationText,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 5))
        .editorButtonHoverFeedback(cornerRadius: 5)
        .disabled(!isEnabled)
        .help(label(key))
    }

    private func previewNudgeButton(
        symbol: String,
        label key: PetCustomizationText,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(0.72)
        .editorButtonHoverFeedback(cornerRadius: 9)
        .help(label(key))
    }

    private func previewHistoryButton(
        symbol: String,
        label key: PetCustomizationText,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 5))
        .editorButtonHoverFeedback(cornerRadius: 5)
        .disabled(!isEnabled)
        .help(label(key))
    }

    private var actionPreviewList: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.fixed(54), spacing: 4),
                    GridItem(.fixed(54), spacing: 4)
                ],
                spacing: 4
            ) {
                ForEach(currentStateConfiguration.resolvedActionAssetIDs, id: \.self) { assetID in
                    actionPreview(assetID: assetID)
                }
                actionAddPreview
            }
            .padding(.vertical, 1)
        }
        .frame(width: 112, height: 230)
    }

    private func actionPreview(assetID: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            ImportedPetVisualView(
                asset: customizationStore.importedVisualAsset(for: assetID),
                baseOffset: nil,
                animationPlaybackRate: currentStateConfiguration.actionAnimationPlaybackRate,
                playsAnimation: true,
                configuration: nil,
                expression: previewExpression,
                isBlinking: false,
                gazeOffset: .zero
            )
            .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
            .scaleEffect(0.68)
        }
        .frame(width: 54, height: 54)
    }

    private var actionAddPreview: some View {
        Button {
            guard canAddAction else { return }
            isShowingActionPicker = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActionDropTarget ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isActionDropTarget ? Color.accentColor : Color.secondary.opacity(0.45),
                                lineWidth: 1
                            )
                    }
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isActionDropTarget ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(.regularMaterial, in: Circle())
            }
            .frame(width: 54, height: 54)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .editorButtonHoverFeedback(cornerRadius: 10)
        .disabled(!canAddAction)
        .popover(isPresented: $isShowingActionPicker, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Button(label(.addGIF), action: addActionGIF)
                Button(label(.addFrames), action: addActionFrames)
            }
            .padding()
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $isActionDropTarget,
            perform: importActionDroppedItems
        )
    }

    private var actionSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label(.actionFrequency))
                .font(.callout)
            Picker(label(.actionFrequency), selection: actionFrequencyBinding) {
                Text(label(.low)).tag(PetActionFrequency.low)
                Text(label(.medium)).tag(PetActionFrequency.medium)
                Text(label(.high)).tag(PetActionFrequency.high)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Toggle(label(.bottomPet), isOn: bottomPetBinding)
                .disabled(isBottomPetLocked)

            if selectedState == .sleeping {
                HStack(spacing: 6) {
                    Toggle(label(.sleepingBreath), isOn: sleepingBreathBinding)
                        .disabled(!currentStateSupportsSleepingBreath)

                    Button {
                        isShowingSleepingBreathHint.toggle()
                    } label: {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .editorButtonHoverFeedback(cornerRadius: 9)
                    .popover(isPresented: $isShowingSleepingBreathHint, arrowEdge: .trailing) {
                        Text(label(.sleepingBreathHint))
                            .font(.caption)
                            .padding(10)
                    }
                }

                Text(label(.sleepingEffect))
                    .font(.callout)
                Picker(label(.sleepingEffect), selection: sleepingEffectBinding) {
                    Text(label(.sleepingBubbles)).tag(PetSleepingEffect.bubbles)
                    Text(label(.sleepingZzz)).tag(PetSleepingEffect.zzz)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
        .frame(width: 170, alignment: .topLeading)
    }

    private var previewGuideGrid: some View {
        GeometryReader { geometry in
            Path { path in
                for fraction: CGFloat in [1.0 / 3.0, 2.0 / 3.0] {
                    let x = geometry.size.width * fraction
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))

                    let y = geometry.size.height * fraction
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(
                Color.primary.opacity(0.24),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var previewSelectionIndicator: some View {
        GeometryReader { geometry in
            let canvasSize = min(geometry.size.width, geometry.size.height)
            let petSize = previewPetSize
            let selectionColor = Color.accentColor.opacity(0.42)

            switch selectedPreviewPart {
            case .body:
                let offset = currentStateConfiguration.baseOffset ?? .zero
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selectionColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: petSize, height: petSize)
                    .position(
                        x: canvasSize / 2 + CGFloat(offset.x) * petSize,
                        y: canvasSize / 2 + CGFloat(offset.y) * petSize
                    )
            case .alignedEyes, .left, .right:
                if let eyes = currentStateConfiguration.eyes {
                    let leftEye = eyeCenter(.left, configuration: eyes, canvasSize: canvasSize)
                    let rightEye = eyeCenter(.right, configuration: eyes, canvasSize: canvasSize)
                    let radius = max(18, 16 * CGFloat(eyes.scale) * previewBaseScale)
                    if selectedPreviewPart == .alignedEyes || selectedPreviewPart == .left {
                        Circle()
                            .stroke(selectionColor, lineWidth: 1.5)
                            .frame(width: radius * 2, height: radius * 2)
                            .position(leftEye)
                    }
                    if selectedPreviewPart == .alignedEyes || selectedPreviewPart == .right {
                        Circle()
                            .stroke(selectionColor, lineWidth: 1.5)
                            .frame(width: radius * 2, height: radius * 2)
                            .position(rightEye)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func petPreview(playsAnimation: Bool) -> some View {
        let expression = previewExpression
        let state = currentStateConfiguration
        let animationPlaybackRate = state.animationPlaybackRate.map(clampedAnimationPlaybackRate)
        let customEyeAsset = state.eyes?.customAssetID.flatMap {
            customizationStore.importedVisualAsset(for: $0)
        }

        if case let .importedAsset(assetID) = state.base {
            ImportedPetVisualView(
                asset: customizationStore.importedVisualAsset(for: assetID),
                baseOffset: state.baseOffset,
                animationPlaybackRate: animationPlaybackRate,
                playsAnimation: playsAnimation,
                configuration: state.eyes,
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                customEyeAsset: customEyeAsset
            )
        } else if isOfficialTarget {
            builtInPreview(expression: expression, customEyeAsset: customEyeAsset)
        } else {
            ImportedPetVisualView(
                asset: nil,
                baseOffset: state.baseOffset,
                animationPlaybackRate: animationPlaybackRate,
                playsAnimation: playsAnimation,
                configuration: state.eyes,
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                customEyeAsset: customEyeAsset,
                showsMissingAssetIcon: false
            )
        }
    }

    @ViewBuilder
    private func builtInPreview(
        expression: PetExpression,
        customEyeAsset: PetImportedVisualAsset?
    ) -> some View {
        switch editingPet?.visualKind ?? .cube {
        case .cube:
            CubePetView(
                color: Color(nsColor: editingSkin?.color ?? .black),
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                visualConfiguration: draft,
                customEyeAsset: customEyeAsset
            )
        case .frog:
            FrogPetView(
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                visualConfiguration: draft,
                customEyeAsset: customEyeAsset
            )
        case .cat:
            CatPetView(
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                skinID: editingSkin?.id ?? PetCatalog.cat.skins[0].id,
                visualConfiguration: draft,
                customEyeAsset: customEyeAsset
            )
        case .shiba:
            ShibaPetView(
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                visualConfiguration: draft,
                customEyeAsset: customEyeAsset
            )
        }
    }

    private var selectedTarget: PetEditorTarget { target ?? .currentAppearance }

    private var editingOfficialIDs: (petID: String, skinID: String)? {
        switch selectedTarget {
        case .currentAppearance where !appearanceSettings.isCustomPetSelected:
            return (appearanceSettings.selectedPetID, appearanceSettings.selectedSkinID)
        case let .official(petID, skinID):
            return (petID, skinID)
        default:
            return nil
        }
    }

    private var editingCustomPetID: String? {
        switch selectedTarget {
        case .currentAppearance where appearanceSettings.isCustomPetSelected:
            return appearanceSettings.selectedPetID
        case let .custom(id):
            return id
        default:
            return nil
        }
    }

    private var editingPet: PetDefinition? {
        guard let ids = editingOfficialIDs else { return nil }
        return PetCatalog.pet(id: ids.petID)
    }

    private var editingSkin: PetSkinDefinition? {
        guard let ids = editingOfficialIDs else { return nil }
        return PetCatalog.pet(id: ids.petID)?.skin(id: ids.skinID)
    }

    private var officialConfiguration: PetVisualConfiguration {
        guard let ids = editingOfficialIDs else { return PetVisualDefaults.cube }
        return PetVisualDefaults.configuration(petID: ids.petID, skinID: ids.skinID)
    }

    private var isOfficialTarget: Bool { editingOfficialIDs != nil }
    private var isCustomTarget: Bool { editingCustomPetID != nil || selectedTarget == .new }

    private var previewExpression: PetExpression {
        switch selectedState {
        case .normal: .calm
        case .happy: .happy
        case .scared: .scared
        case .sleeping: .sleeping
        case .eating: .calm
        case .hungry: .hungry
        }
    }

    private var previewMouthOpen: CGFloat {
        selectedState == .eating ? 0.6 : 0
    }

    private var currentStateConfiguration: PetStateVisualConfiguration {
        draft.configuration(for: selectedState)
    }

    private var usesFixedEyeArtwork: Bool {
        guard
            isOfficialTarget,
            editingPet?.visualKind == .cat
        else { return false }

        switch selectedState {
        case .sleeping, .hungry:
            return true
        case .eating:
            return editingSkin?.id != "cat.calico"
        case .normal, .happy, .scared:
            return false
        }
    }

    private var currentEyePreset: PetEyePreset? {
        guard let assetID = currentStateConfiguration.eyes?.customAssetID else { return nil }
        return customizationStore.eyePresets.first { $0.assetID == assetID }
    }

    private var currentEyeTypeName: String {
        currentEyePreset?.name
            ?? (currentStateConfiguration.eyes?.customAssetID == nil
                ? eyeTypeName(for: currentStateConfiguration.eyes?.kind ?? suggestedEyeKind)
                : label(.importedEye))
    }

    private var currentImportedAsset: PetImportedVisualAsset? {
        guard case let .importedAsset(assetID) = currentStateConfiguration.base else {
            return nil
        }
        return customizationStore.importedVisualAsset(for: assetID)
    }

    private var hasPreviewImage: Bool {
        isOfficialTarget || currentImportedAsset != nil
    }

    private var currentStateSupportsSleepingBreath: Bool {
        guard case let .importedAsset(assetID) = currentStateConfiguration.base else {
            return true
        }
        return customizationStore.importedVisualAsset(for: assetID)?.supportsSleepingBreath == true
    }

    private var eyesEnabledBinding: Binding<Bool> {
        Binding(
            get: { !usesFixedEyeArtwork && currentStateConfiguration.eyes != nil },
            set: { isEnabled in
                guard !usesFixedEyeArtwork else { return }
                updateCurrentState { state in
                    if isEnabled {
                        state.eyes = defaultEyeConfiguration
                    } else {
                        state.eyes = nil
                    }
                }
            }
        )
    }

    private var defaultEyeConfiguration: PetEyeModuleConfiguration {
        if isOfficialTarget,
           let eyes = officialConfiguration.configuration(for: selectedState).eyes {
            return eyes
        }
        return PetEyeModuleConfiguration(kind: suggestedEyeKind)
    }

    private var eyeKindBinding: Binding<PetEyeModuleKind> {
        Binding(
            get: { currentStateConfiguration.eyes?.kind ?? suggestedEyeKind },
            set: { kind in updateCurrentEyes { $0.kind = kind } }
        )
    }

    private func eyeTypeName(for kind: PetEyeModuleKind) -> String {
        switch kind {
        case .expressionDriven: label(.bigEyes)
        case .catDefault: label(.bigEyes)
        case .tracking: label(.smallBlackBlockEyes)
        case .shibaWatercolor: label(.shibaWatercolorEyes)
        case .happy: label(.happy)
        case .scared: label(.scared)
        case .sleeping: label(.sleeping)
        case .eating: label(.eating)
        case .hungry: label(.hungry)
        }
    }

    private var eyeAlignmentBinding: Binding<Bool> {
        Binding(
            get: { currentStateConfiguration.eyes?.areEyesAligned ?? true },
            set: { isAligned in
                updateCurrentEyes { $0.setEyesAligned(isAligned) }
                resetPreviewDrag()
            }
        )
    }

    private var eyeColorBinding: Binding<PetEyeColorMode> {
        Binding(
            get: { currentStateConfiguration.eyes?.resolvedColorMode ?? .automatic },
            set: { colorMode in
                updateCurrentEyes {
                    $0.colorMode = colorMode == .automatic ? nil : colorMode
                }
            }
        )
    }

    private var eyeScaleBinding: Binding<Double> {
        Binding(
            get: { currentStateConfiguration.eyes?.scale ?? 1 },
            set: { value in updateCurrentEyes { $0.scale = value } }
        )
    }

    private var outerEyeScaleBinding: Binding<Double> {
        Binding(
            get: { currentStateConfiguration.eyes?.resolvedOuterEyeScale ?? 1 },
            set: { value in
                updateCurrentEyes { $0.outerEyeScale = value }
            }
        )
    }

    private var pupilScaleBinding: Binding<Double> {
        Binding(
            get: { currentStateConfiguration.eyes?.resolvedPupilScale ?? 1 },
            set: { value in
                updateCurrentEyes { $0.pupilScale = value }
            }
        )
    }

    private var eyeSpacingBinding: Binding<Double> {
        Binding(
            get: { currentStateConfiguration.eyes?.spacing ?? 11 },
            set: { value in updateCurrentEyes { $0.spacing = value } }
        )
    }

    private var suggestedEyeKind: PetEyeModuleKind {
        switch selectedState {
        case .normal: .catDefault
        case .happy: .happy
        case .scared: .scared
        case .sleeping: .sleeping
        case .eating: .eating
        case .hungry: .hungry
        }
    }

    private var dragHintText: String {
        if currentStateConfiguration.eyes?.areEyesAligned == false {
            return label(.independentDragHint)
        }
        return label(.dragHint)
    }

    private func updateCurrentState(_ update: (inout PetStateVisualConfiguration) -> Void) {
        let previousDraft = draft
        var state = previousDraft.configuration(for: selectedState)
        update(&state)
        var updatedDraft = previousDraft
        updatedDraft.setConfiguration(state, for: selectedState)
        guard updatedDraft != previousDraft else { return }

        if historyTransactionBaseline == nil {
            recordUndoCheckpoint(previousDraft)
        }
        draft = updatedDraft
        statusMessage = nil
    }

    private func updateHistoryTransaction(isEditing: Bool) {
        if isEditing {
            beginHistoryTransaction()
        } else {
            endHistoryTransaction()
        }
    }

    private func beginHistoryTransaction() {
        guard historyTransactionBaseline == nil else { return }
        historyTransactionBaseline = draft
    }

    private func endHistoryTransaction() {
        guard let baseline = historyTransactionBaseline else { return }
        historyTransactionBaseline = nil
        guard baseline != draft else { return }
        recordUndoCheckpoint(baseline)
    }

    private func recordUndoCheckpoint(_ previousDraft: PetVisualConfiguration) {
        undoHistory.append(previousDraft)
        if undoHistory.count > 50 {
            undoHistory.removeFirst()
        }
        redoHistory.removeAll()
    }

    private func undo() {
        endHistoryTransaction()
        guard let previousDraft = undoHistory.popLast() else { return }
        redoHistory.append(draft)
        draft = previousDraft
        statusMessage = nil
        resetPreviewDrag()
    }

    private func redo() {
        endHistoryTransaction()
        guard let nextDraft = redoHistory.popLast() else { return }
        undoHistory.append(draft)
        draft = nextDraft
        statusMessage = nil
        resetPreviewDrag()
    }

    private func resetHistory() {
        undoHistory.removeAll()
        redoHistory.removeAll()
        historyTransactionBaseline = nil
    }

    private var previewNudgeStep: Double {
        1 / Double(PetMetrics.bodyContentSize)
    }

    private var previewBaseScale: CGFloat {
        CGFloat(currentStateConfiguration.resolvedBaseScale)
    }

    private var previewPetSize: CGFloat {
        PetMetrics.bodyContentSize * 3 * previewBaseScale
    }

    private func nudgeBody(deltaX: Double, deltaY: Double) {
        updateCurrentState { state in
            let offset = state.baseOffset ?? .zero
            state.baseOffset = NormalizedVisualOffset(
                x: min(max(offset.x + deltaX, -1), 1),
                y: min(max(offset.y + deltaY, -1), 1)
            )
        }
    }

    private func adjustBaseScale(by delta: Double) {
        updateCurrentState { state in
            let adjusted = min(max(state.resolvedBaseScale + delta, 0.5), 2)
            state.baseScale = abs(adjusted - 1) < 0.000_1 ? nil : adjusted
        }
    }

    private func updateCurrentEyes(_ update: (inout PetEyeModuleConfiguration) -> Void) {
        updateCurrentState { state in
            guard var eyes = state.eyes else { return }
            update(&eyes)
            state.eyes = eyes
        }
    }

    private func addEyes() {
        guard currentStateConfiguration.eyes == nil else { return }
        updateCurrentState { $0.eyes = defaultEyeConfiguration }
    }

    private func selectOfficialEyeType(_ kind: PetEyeModuleKind) {
        updateCurrentEyes {
            $0.kind = kind
            $0.customAssetID = nil
        }
    }

    private func selectEyePreset(_ preset: PetEyePreset) {
        updateCurrentEyes {
            $0.kind = .tracking
            $0.customAssetID = preset.assetID
        }
    }

    private func importEyePreset() {
        guard let sourceURL = PetImagePicker.chooseEyeImage(
            title: label(.importEyes),
            prompt: languageSettings.text(.choose)
        ) else { return }

        do {
            let preset = try customizationStore.importEyePreset(from: sourceURL)
            selectEyePreset(preset)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteCurrentEyePreset() {
        guard let preset = currentEyePreset else { return }
        updateCurrentEyes {
            guard $0.customAssetID == preset.assetID else { return }
            $0.customAssetID = nil
            $0.kind = suggestedEyeKind
        }

        do {
            try customizationStore.deleteEyePreset(id: preset.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func renameCurrentEyePreset() {
        guard let preset = currentEyePreset else { return }
        do {
            try customizationStore.renameEyePreset(id: preset.id, name: eyePresetName)
            isShowingEyePresetRename = false
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func selectPreviewPart(at location: CGPoint, canvasSize: CGFloat) {
        selectedPreviewPart = previewPart(at: location, canvasSize: canvasSize)
    }

    private func moveSelectedPart(
        startingAt location: CGPoint,
        translation: CGSize,
        canvasSize: CGFloat
    ) {
        let petSize = previewPetSize
        if draggedPreviewPart == nil {
            beginHistoryTransaction()
            let part = previewPart(at: location, canvasSize: canvasSize)
            selectedPreviewPart = part
            draggedPreviewPart = part
            dragStartBodyOffset = currentStateConfiguration.baseOffset ?? .zero
            dragStartEyeCenter = currentStateConfiguration.eyes?.center ?? .center
            dragStartLeftOffset = currentStateConfiguration.eyes?.leftEyeOffset ?? .zero
            dragStartRightOffset = currentStateConfiguration.eyes?.rightEyeOffset ?? .zero
        }

        let deltaX = Double(translation.width / petSize)
        let deltaY = Double(translation.height / petSize)
        switch draggedPreviewPart {
        case .body:
            updateCurrentState { state in
                state.baseOffset = clampedOffset(
                    from: dragStartBodyOffset,
                    deltaX: deltaX,
                    deltaY: deltaY
                )
            }
        case .alignedEyes:
            updateCurrentEyes { eyes in
                eyes.center = NormalizedVisualPoint(
                    x: min(max(dragStartEyeCenter.x + deltaX, 0), 1),
                    y: min(max(dragStartEyeCenter.y + deltaY, 0), 1)
                )
            }
        case .left:
            updateCurrentEyes { eyes in
                eyes.leftEyeOffset = clampedOffset(
                    from: dragStartLeftOffset,
                    deltaX: deltaX,
                    deltaY: deltaY
                )
            }
        case .right:
            updateCurrentEyes { eyes in
                eyes.rightEyeOffset = clampedOffset(
                    from: dragStartRightOffset,
                    deltaX: deltaX,
                    deltaY: deltaY
                )
            }
        case nil:
            break
        }
    }

    private func previewPart(at location: CGPoint, canvasSize: CGFloat) -> PreviewEditablePart {
        guard let eyes = currentStateConfiguration.eyes else { return .body }
        let radius = max(18, 16 * CGFloat(eyes.scale) * previewBaseScale)
        let leftEye = eyeCenter(.left, configuration: eyes, canvasSize: canvasSize)
        let rightEye = eyeCenter(.right, configuration: eyes, canvasSize: canvasSize)

        if eyes.areEyesAligned {
            return distance(from: location, to: leftEye) <= radius ||
                distance(from: location, to: rightEye) <= radius
                ? .alignedEyes
                : .body
        }
        if distance(from: location, to: leftEye) <= radius { return .left }
        if distance(from: location, to: rightEye) <= radius { return .right }
        return .body
    }

    private func eyeCenter(
        _ eye: PreviewEditablePart,
        configuration: PetEyeModuleConfiguration,
        canvasSize: CGFloat
    ) -> CGPoint {
        let petSize = previewPetSize
        let petOrigin = (canvasSize - petSize) / 2
        let eyeScale = CGFloat(configuration.scale)
        let halfSpacing = CGFloat(configuration.spacing) * eyeScale / 2
        let offset: NormalizedVisualOffset
        let xAdjustment: CGFloat
        let yAdjustment: CGFloat
        switch eye {
        case .left:
            offset = configuration.leftEyeOffset ?? .zero
            xAdjustment = -halfSpacing
            yAdjustment = 0
        case .right:
            offset = configuration.rightEyeOffset ?? .zero
            xAdjustment = halfSpacing
            yAdjustment = CGFloat(configuration.rightEyeOffsetY ?? 0) * eyeScale
        case .body, .alignedEyes:
            offset = .zero
            xAdjustment = 0
            yAdjustment = 0
        }
        return CGPoint(
            x: petOrigin + CGFloat(configuration.center.x) * petSize + xAdjustment + CGFloat(offset.x) * petSize,
            y: petOrigin + CGFloat(configuration.center.y) * petSize + yAdjustment + CGFloat(offset.y) * petSize
        )
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func resetPreviewDrag() {
        draggedPreviewPart = nil
        dragStartBodyOffset = .zero
        dragStartEyeCenter = .center
        dragStartLeftOffset = .zero
        dragStartRightOffset = .zero
        endHistoryTransaction()
    }

    private func clampedOffset(
        from start: NormalizedVisualOffset,
        deltaX: Double,
        deltaY: Double
    ) -> NormalizedVisualOffset {
        NormalizedVisualOffset(
            x: min(max(start.x + deltaX, -1), 1),
            y: min(max(start.y + deltaY, -1), 1)
        )
    }


    private func importImages() {
        guard let urls = PetImagePicker.chooseImages(
            title: label(.importImages),
            prompt: languageSettings.text(.choose)
        ) else { return }

        importImages(from: urls)
    }

    private func importImages(
        from urls: [URL],
        destination: ImportedAssetDestination = .defaultVisual
    ) {
        do {
            let assetID = try customizationStore.importVisualAsset(from: urls)
            updateCurrentState { state in
                switch destination {
                case .defaultVisual:
                    state.base = .importedAsset(id: assetID)
                case .action:
                    state.appendActionAsset(assetID)
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func clearCurrentPreviewImage() {
        updateCurrentState { state in
            state.base = .officialSkin
            state.baseOffset = nil
            state.baseScale = nil
            state.animationPlaybackRate = nil
        }
        isShowingStaticEditor = false
        resetPreviewDrag()
    }

    private func importDefaultDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        importDroppedItems(providers, destination: .defaultVisual)
    }

    private func importActionDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        guard canAddAction else {
            statusMessage = PetCustomizationStoreError.defaultImageRequired.localizedDescription
            return false
        }
        return importDroppedItems(providers, destination: .action)
    }

    private func importDroppedItems(
        _ providers: [NSItemProvider],
        destination: ImportedAssetDestination
    ) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls = Array<URL?>(repeating: nil, count: providers.count)

        for (index, provider) in providers.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let urlItem = item as? URL {
                    url = urlItem
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }
                if let url {
                    lock.lock()
                    urls[index] = url
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            importImages(from: urls.compactMap { $0 }, destination: destination)
        }
        return true
    }

    private var canAddAction: Bool {
        if isOfficialTarget { return true }
        if case .importedAsset = currentStateConfiguration.base { return true }
        return false
    }

    private func addActionGIF() {
        guard canAddAction,
              let urls = PetImagePicker.chooseGIF(
                title: label(.addGIF),
                prompt: languageSettings.text(.choose)
              ) else { return }
        importImages(from: urls, destination: .action)
    }

    private func addActionFrames() {
        guard canAddAction,
              let urls = PetImagePicker.chooseAnimationFrames(
                title: label(.addFrames),
                prompt: languageSettings.text(.choose)
              ) else { return }
        importImages(from: urls, destination: .action)
    }

    private var defaultPreviewEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(label(.animationSpeed))
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2fx", animationPlaybackRateBinding.wrappedValue))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }

            Slider(
                value: animationPlaybackRateBinding,
                in: Self.animationPlaybackRateRange,
                step: 0.05,
                onEditingChanged: updateHistoryTransaction
            )
            .tint(.accentColor)
            .controlSize(.large)

            HStack {
                Text("0.25×")
                Spacer()
                Text("1×")
                Spacer()
                Text("2×")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let asset = currentFrameAnimationAsset {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(label(.framePlaybackOrder))
                        .font(.subheadline.weight(.semibold))

                    Text(label(.dragFramesToReorder))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(asset.frameURLs.enumerated()), id: \.element) { index, frameURL in
                                frameThumbnail(url: frameURL, index: index)
                                    .onDrag {
                                        draggedFrameIndex = index
                                        return NSItemProvider(object: String(index) as NSString)
                                    }
                                    .onDrop(
                                        of: [UTType.plainText],
                                        delegate: FrameReorderDropDelegate(
                                            destinationIndex: index,
                                            draggedFrameIndex: $draggedFrameIndex,
                                            dropTargetIndex: $frameDropTargetIndex,
                                            moveFrame: moveFrame
                                        )
                                    )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 70)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(width: 290)
    }

    private var eyeDetailEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            sliderRow(label: .whiteSize, value: outerEyeScaleBinding, range: 0.5...2)
            sliderRow(label: .pupilSize, value: pupilScaleBinding, range: 0.5...2)
            sliderRow(label: .spacing, value: eyeSpacingBinding, range: -10...30)
        }
        .font(.callout)
        .padding()
        .frame(width: 280)
    }

    private func frameThumbnail(url: URL, index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image = PetImportedImageCache.image(for: url) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("\(index + 1)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(4)
        }
        .frame(width: 56, height: 56)
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    frameDropTargetIndex == index && draggedFrameIndex != index
                        ? Color.accentColor
                        : Color.clear,
                    lineWidth: 2
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .editorButtonHoverFeedback(cornerRadius: 6)
        .overlay(alignment: .topTrailing) {
            if hoveredFrameIndex == index, currentFrameAnimationAsset?.frameCount ?? 0 > 1 {
                Button {
                    removeFrame(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .padding(3)
                .help(label(.deleteFrame))
            }
        }
        .onHover { isHovering in
            hoveredFrameIndex = isHovering ? index : nil
        }
    }

    private var actionPreviewEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let actionAssetID = currentStateConfiguration.actionAssetID,
               let asset = customizationStore.importedVisualAsset(for: actionAssetID) {
                Text(asset.kind == .gif ? label(.gifAnimation) : label(.frameAnimation))
                    .font(.headline)
                Text(String(format: label(.animationFrameCount), asset.frameCount))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(label(.animationSpeed))
                Slider(
                    value: actionAnimationPlaybackRateBinding,
                    in: 0.25...3,
                    step: 0.05,
                    onEditingChanged: updateHistoryTransaction
                )
                Text(String(format: "%.2fx", currentStateConfiguration.actionAnimationPlaybackRate ?? 1))
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .font(.callout)
        .padding()
        .frame(width: 260)
    }

    private static let animationPlaybackRateRange: ClosedRange<Double> = 0.25...2

    private var animationPlaybackRateBinding: Binding<Double> {
        Binding(
            get: { clampedAnimationPlaybackRate(currentStateConfiguration.animationPlaybackRate ?? 1) },
            set: { rate in
                let clampedRate = clampedAnimationPlaybackRate(rate)
                updateCurrentState {
                    $0.animationPlaybackRate = abs(clampedRate - 1) < 0.001 ? nil : clampedRate
                }
            }
        )
    }

    private func clampedAnimationPlaybackRate(_ rate: Double) -> Double {
        min(max(rate, Self.animationPlaybackRateRange.lowerBound), Self.animationPlaybackRateRange.upperBound)
    }

    private var currentFrameAnimationAsset: PetImportedVisualAsset? {
        guard let asset = currentImportedAsset, asset.kind == .frameAnimation else { return nil }
        return asset
    }

    private func moveFrame(from sourceIndex: Int, to destinationIndex: Int) {
        guard case let .importedAsset(assetID) = currentStateConfiguration.base else { return }

        do {
            try customizationStore.reorderFrames(
                assetID: assetID,
                from: sourceIndex,
                to: destinationIndex
            )
            frameOrderRevision = UUID()
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func removeFrame(at index: Int) {
        guard case let .importedAsset(assetID) = currentStateConfiguration.base else { return }

        do {
            try customizationStore.removeFrame(assetID: assetID, at: index)
            frameOrderRevision = UUID()
            hoveredFrameIndex = nil
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private var actionAnimationPlaybackRateBinding: Binding<Double> {
        Binding(
            get: { currentStateConfiguration.actionAnimationPlaybackRate ?? 1 },
            set: { rate in
                updateCurrentState {
                    $0.actionAnimationPlaybackRate = abs(rate - 1) < 0.001 ? nil : rate
                }
            }
        )
    }

    private var actionFrequencyBinding: Binding<PetActionFrequency> {
        Binding(
            get: { currentStateConfiguration.resolvedActionFrequency },
            set: { frequency in
                updateCurrentState { $0.actionFrequency = frequency }
            }
        )
    }

    private var bottomPetBinding: Binding<Bool> {
        Binding(
            get: { isBottomPetLocked || draft.resolvedBottomPetEnabled },
            set: { isEnabled in
                guard !isBottomPetLocked else { return }
                updateBottomPetEnabled(isEnabled)
            }
        )
    }

    private var isBottomPetLocked: Bool {
        guard let ids = editingOfficialIDs else { return false }
        return ids.petID == PetCatalog.cat.id && ids.skinID == "cat.yellow"
    }

    private func updateBottomPetEnabled(_ isEnabled: Bool) {
        let previousDraft = draft
        var updatedDraft = previousDraft
        updatedDraft.setBottomPetEnabled(isEnabled)
        guard updatedDraft != previousDraft else { return }

        if historyTransactionBaseline == nil {
            recordUndoCheckpoint(previousDraft)
        }
        draft = updatedDraft
        statusMessage = nil
    }

    private var sleepingBreathBinding: Binding<Bool> {
        Binding(
            get: { currentStateConfiguration.resolvedSleepingBreathEnabled },
            set: { isEnabled in
                updateCurrentState {
                    $0.sleepingBreathEnabled = isEnabled ? nil : false
                }
            }
        )
    }

    private var sleepingEffectBinding: Binding<PetSleepingEffect> {
        Binding(
            get: { currentStateConfiguration.resolvedSleepingEffect },
            set: { effect in
                updateCurrentState { $0.sleepingEffect = effect }
            }
        )
    }

    private func useOfficialSkin() {
        updateCurrentState { state in
            let officialState = officialConfiguration.configuration(for: selectedState)
            state.base = .officialSkin
            state.baseOffset = officialState.baseOffset
            state.eyes = officialState.eyes
        }
    }

    private func prepareNewPet() {
        petName = label(.newPet)
        selectedState = .normal
        draft = PetVisualConfiguration(
            states: [
                .normal: PetStateVisualConfiguration(
                    base: .officialSkin,
                    eyes: nil
                )
            ]
        )
        statusMessage = nil
        resetHistory()
    }

    private func load(_ target: PetEditorTarget) {
        selectedState = .normal
        statusMessage = nil
        resetHistory()
        switch target {
        case .currentAppearance:
            if
                appearanceSettings.isCustomPetSelected,
                let pet = customizationStore.customPet(id: appearanceSettings.selectedPetID)
            {
                petName = pet.name
                draft = pet.visualConfiguration
            } else {
                loadOfficial(
                    petID: appearanceSettings.selectedPetID,
                    skinID: appearanceSettings.selectedSkinID
                )
            }
        case let .official(petID, skinID):
            loadOfficial(petID: petID, skinID: skinID)
        case let .custom(id):
            guard let pet = customizationStore.customPet(id: id) else { return }
            petName = pet.name
            draft = pet.visualConfiguration
        case .new:
            prepareNewPet()
        }
    }

    private func loadOfficial(petID: String, skinID: String) {
        petName = ""
        let official = PetVisualDefaults.configuration(petID: petID, skinID: skinID)
        draft = customizationStore.visualConfiguration(
            petID: petID,
            skinID: skinID,
            official: official
        )
    }

    private func save() {
        do {
            switch selectedTarget {
            case .currentAppearance:
                if let id = editingCustomPetID {
                    try customizationStore.updateCustomPet(
                        id: id,
                        name: petName,
                        visualConfiguration: draft
                    )
                } else if let ids = editingOfficialIDs {
                    try customizationStore.saveVisualOverride(
                        draft,
                        petID: ids.petID,
                        skinID: ids.skinID
                    )
                }
            case let .official(petID, skinID):
                try customizationStore.saveVisualOverride(
                    draft,
                    petID: petID,
                    skinID: skinID
                )
            case let .custom(id):
                try customizationStore.updateCustomPet(
                    id: id,
                    name: petName,
                    visualConfiguration: draft
                )
            case .new:
                let pet = try customizationStore.createCustomPet(
                    name: petName,
                    visualConfiguration: draft
                )
                target = .custom(pet.id)
            }
            statusMessage = label(.saved)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deletePet() {
        guard let id = editingCustomPetID else { return }
        do {
            try customizationStore.deleteCustomPet(id: id)
            if appearanceSettings.selectedPetID == id {
                appearanceSettings.selectDefaultPet()
            }
            target = .currentAppearance
            load(.currentAppearance)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func restoreOfficial() {
        guard let ids = editingOfficialIDs else { return }
        do {
            var restoredDraft = draft
            restoredDraft.setConfiguration(
                officialConfiguration.configuration(for: selectedState),
                for: selectedState
            )
            try customizationStore.saveVisualOverride(
                restoredDraft,
                petID: ids.petID,
                skinID: ids.skinID
            )
            recordUndoCheckpoint(draft)
            draft = restoredDraft
            statusMessage = label(.saved)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func label(_ key: PetCustomizationText) -> String {
        languageSettings.customizationText(key)
    }
}
