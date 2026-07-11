import SwiftUI

private enum EditedEye {
    case left
    case right
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
    @State private var draggedEye: EditedEye?
    @State private var dragStartLeftOffset = NormalizedVisualOffset.zero
    @State private var dragStartRightOffset = NormalizedVisualOffset.zero

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

                Form {
                    LabeledContent {
                        HStack {
                            Button(label(.importPNG), action: importPNG)
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
                            Text(label(.normal)).tag(PetEyeModuleKind.tracking)
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
            .padding(24)

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

    private var previewColumn: some View {
        VStack(spacing: 14) {
            preview

            HStack(spacing: 8) {
                skinNudgeButton(
                    systemName: "arrow.left",
                    label: .moveSkinLeft,
                    x: -1,
                    y: 0
                )
                skinNudgeButton(
                    systemName: "arrow.right",
                    label: .moveSkinRight,
                    x: 1,
                    y: 0
                )
                skinNudgeButton(
                    systemName: "arrow.up",
                    label: .moveSkinUp,
                    x: 0,
                    y: -1
                )
                skinNudgeButton(
                    systemName: "arrow.down",
                    label: .moveSkinDown,
                    x: 0,
                    y: 1
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if currentStateConfiguration.eyes != nil {
                GroupBox {
                    VStack(spacing: 10) {
                        sliderRow(
                            label: .size,
                            value: eyeScaleBinding,
                            range: 0.5...2
                        )
                        sliderRow(
                            label: .whiteSize,
                            value: outerEyeScaleBinding,
                            range: 0.5...2
                        )
                        sliderRow(
                            label: .pupilSize,
                            value: pupilScaleBinding,
                            range: 0.5...2
                        )
                        sliderRow(
                            label: .spacing,
                            value: eyeSpacingBinding,
                            range: -10...30
                        )
                    }
                    .padding(4)
                }
                .font(.callout)
                .frame(width: 250)
            }
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
            Slider(value: value, in: range)
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary.opacity(0.45))

            petPreview
                .frame(width: PetMetrics.bodyContentSize, height: PetMetrics.bodyContentSize)
                .scaleEffect(3)

            previewGuideGrid
        }
        .frame(width: 230, height: 230)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    moveEyes(
                        to: value.location,
                        translation: value.translation,
                        canvasSize: 230
                    )
                }
                .onEnded { _ in resetEyeDrag() }
        )
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

    private func skinNudgeButton(
        systemName: String,
        label key: PetCustomizationText,
        x: Double,
        y: Double
    ) -> some View {
        Button {
            nudgeSkin(x: x, y: y)
        } label: {
            Image(systemName: systemName)
                .frame(width: 22)
        }
        .accessibilityLabel(label(key))
        .help(label(key))
    }

    @ViewBuilder
    private var petPreview: some View {
        let expression = previewExpression
        let state = currentStateConfiguration

        if case let .importedAsset(assetID) = state.base {
            ImportedPetVisualView(
                imageURL: customizationStore.assetURL(for: assetID),
                baseOffset: state.baseOffset,
                configuration: state.eyes,
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero
            )
        } else if isOfficialTarget {
            builtInPreview(expression: expression)
        } else {
            ImportedPetVisualView(
                imageURL: nil,
                baseOffset: state.baseOffset,
                configuration: state.eyes,
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero
            )
        }
    }

    @ViewBuilder
    private func builtInPreview(expression: PetExpression) -> some View {
        switch editingPet?.visualKind ?? .cube {
        case .cube:
            CubePetView(
                color: Color(nsColor: editingSkin?.color ?? .black),
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                visualConfiguration: draft
            )
        case .frog:
            FrogPetView(
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                visualConfiguration: draft
            )
        case .cat:
            CatPetView(
                expression: expression,
                isBlinking: false,
                gazeOffset: .zero,
                mouthOpen: previewMouthOpen,
                skinID: editingSkin?.id ?? PetCatalog.cat.skins[0].id,
                visualConfiguration: draft
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

    private var eyesEnabledBinding: Binding<Bool> {
        Binding(
            get: { currentStateConfiguration.eyes != nil },
            set: { isEnabled in
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

    private var eyeAlignmentBinding: Binding<Bool> {
        Binding(
            get: { currentStateConfiguration.eyes?.areEyesAligned ?? true },
            set: { isAligned in
                updateCurrentEyes { $0.setEyesAligned(isAligned) }
                resetEyeDrag()
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
        case .normal: .tracking
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
        var state = currentStateConfiguration
        update(&state)
        draft.setConfiguration(state, for: selectedState)
        statusMessage = nil
    }

    private func updateCurrentEyes(_ update: (inout PetEyeModuleConfiguration) -> Void) {
        updateCurrentState { state in
            guard var eyes = state.eyes else { return }
            update(&eyes)
            state.eyes = eyes
        }
    }

    private func nudgeSkin(x: Double, y: Double) {
        let step = 0.5 / Double(PetMetrics.bodyContentSize)
        updateCurrentState { state in
            let offset = state.baseOffset ?? .zero
            state.baseOffset = NormalizedVisualOffset(
                x: min(max(offset.x + x * step, -1), 1),
                y: min(max(offset.y + y * step, -1), 1)
            )
        }
    }

    private func moveEyes(
        to location: CGPoint,
        translation: CGSize,
        canvasSize: CGFloat
    ) {
        guard let eyes = currentStateConfiguration.eyes else { return }
        let petSize = PetMetrics.bodyContentSize * 3
        let petOrigin = (canvasSize - petSize) / 2

        guard !eyes.areEyesAligned else {
            let x = min(max((location.x - petOrigin) / petSize, 0), 1)
            let y = min(max((location.y - petOrigin) / petSize, 0), 1)
            updateCurrentEyes {
                $0.center = NormalizedVisualPoint(x: Double(x), y: Double(y))
            }
            return
        }

        if draggedEye == nil {
            let pairCenterX = petOrigin + CGFloat(eyes.center.x) * petSize
            draggedEye = location.x < pairCenterX ? .left : .right
            dragStartLeftOffset = eyes.leftEyeOffset ?? .zero
            dragStartRightOffset = eyes.rightEyeOffset ?? .zero
        }

        let deltaX = Double(translation.width / petSize)
        let deltaY = Double(translation.height / petSize)
        updateCurrentEyes { configuration in
            switch draggedEye {
            case .left:
                configuration.leftEyeOffset = clampedOffset(
                    from: dragStartLeftOffset,
                    deltaX: deltaX,
                    deltaY: deltaY
                )
            case .right:
                configuration.rightEyeOffset = clampedOffset(
                    from: dragStartRightOffset,
                    deltaX: deltaX,
                    deltaY: deltaY
                )
            case nil:
                break
            }
        }
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

    private func resetEyeDrag() {
        draggedEye = nil
        dragStartLeftOffset = .zero
        dragStartRightOffset = .zero
    }

    private func importPNG() {
        guard let url = PetImagePicker.choosePNG(
            title: label(.importPNG),
            prompt: languageSettings.text(.choose)
        ) else { return }

        do {
            let assetID = try customizationStore.importPNG(from: url)
            updateCurrentState { $0.base = .importedAsset(id: assetID) }
        } catch {
            statusMessage = error.localizedDescription
        }
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
                    eyes: PetEyeModuleConfiguration(kind: .tracking)
                )
            ]
        )
        statusMessage = nil
    }

    private func load(_ target: PetEditorTarget) {
        selectedState = .normal
        statusMessage = nil
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
