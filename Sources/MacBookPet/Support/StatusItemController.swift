import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let showsSystemInfoKey = "MacBookPet.showsSystemInfo"
    private static let fixedMenuWidth: CGFloat = 260
    private static let fixedMenuRowHeight: CGFloat = 22

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let progressItem = NSMenuItem()
    private let cpuItem = NSMenuItem()
    private let networkItem = NSMenuItem()
    private let progressRowView = FixedMenuStatusRowView(width: fixedMenuWidth, height: fixedMenuRowHeight)
    private let cpuMemoryRowView = FixedMenuStatusRowView(width: fixedMenuWidth, height: fixedMenuRowHeight)
    private let networkRowView = FixedMenuStatusRowView(
        width: fixedMenuWidth,
        height: fixedMenuRowHeight,
        leftWidth: 42
    )
    private let metricsBottomSeparator = NSMenuItem.separator()
    private let activityMonitorItem = NSMenuItem(title: "", action: #selector(openActivityMonitor), keyEquivalent: "")
    private let skinItem = NSMenuItem()
    private let shopItem = NSMenuItem()
    private let shopFoodItem = NSMenuItem()
    private let shopSkinsItem = NSMenuItem()
    private let shopPetsItem = NSMenuItem()
    private let settingItem = NSMenuItem()
    private let petItem = NSMenuItem()
    private let petCustomizationItem = NSMenuItem(
        title: "",
        action: #selector(openPetCustomization),
        keyEquivalent: ""
    )
    private let feedItem = NSMenuItem()
    private let languageItem = NSMenuItem()
    private let showSystemInfoItem = NSMenuItem(title: "", action: #selector(toggleSystemInfo), keyEquivalent: "")
    private let aboutItem = NSMenuItem(title: "", action: #selector(showAbout), keyEquivalent: "")
    private let exitItem = NSMenuItem(title: "", action: #selector(quit), keyEquivalent: "q")
    private let moveToTrashItem = NSMenuItem(title: "", action: #selector(selectMoveToTrash), keyEquivalent: "")
    private let moveToFolderItem = NSMenuItem(title: "", action: #selector(selectMoveToFolder), keyEquivalent: "")
    private let airDropItem = NSMenuItem(title: "", action: #selector(selectAirDrop), keyEquivalent: "")
    private let feedSettings: FeedSettings
    private let languageSettings: LanguageSettings
    private let ageStore: PetAgeStore
    private let progressStore: PetProgressStore
    private let appearanceSettings: PetAppearanceSettings
    private let customizationStore: PetCustomizationStore
    private let featureEntitlementStore: FeatureEntitlementStore
    private let metricsMonitor = SystemMetricsMonitor()
    private let onShowAbout: () -> Void
    private let onShowPetCustomization: () -> Void
    private let onQuit: () -> Void
    private var showsSystemInfo: Bool
    private var languageMenuItems: [AppLanguage: NSMenuItem] = [:]
    private var petMenuItems: [String: NSMenuItem] = [:]
    private var skinMenuItems: [String: NSMenuItem] = [:]
    private var shopFoodMenuItems: [String: NSMenuItem] = [:]
    private var shopSkinMenuItems: [String: NSMenuItem] = [:]
    private var shopPetMenuItems: [String: NSMenuItem] = [:]
    private var latestMetrics = SystemMetricsSnapshot()
    private var cancellables = Set<AnyCancellable>()

    init(
        feedSettings: FeedSettings,
        languageSettings: LanguageSettings,
        ageStore: PetAgeStore,
        progressStore: PetProgressStore,
        appearanceSettings: PetAppearanceSettings,
        customizationStore: PetCustomizationStore,
        featureEntitlementStore: FeatureEntitlementStore,
        onShowAbout: @escaping () -> Void,
        onShowPetCustomization: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.feedSettings = feedSettings
        self.languageSettings = languageSettings
        self.ageStore = ageStore
        self.progressStore = progressStore
        self.appearanceSettings = appearanceSettings
        self.customizationStore = customizationStore
        self.featureEntitlementStore = featureEntitlementStore
        self.onShowAbout = onShowAbout
        self.onShowPetCustomization = onShowPetCustomization
        self.onQuit = onQuit
        self.showsSystemInfo = UserDefaults.standard.object(forKey: Self.showsSystemInfoKey) as? Bool ?? true
        super.init()

        configureButton()
        configureMenu()
        customizationStore.$customPets
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.appearanceSettings.isCustomPetSelected,
                   self.customizationStore.customPet(id: self.appearanceSettings.selectedPetID) == nil {
                    self.appearanceSettings.selectDefaultPet()
                }
                self.petItem.submenu = self.makePetMenu()
                self.skinItem.submenu = self.makeSkinMenu()
                self.shopSkinsItem.submenu = self.makeShopSkinMenu()
                self.updateStatusImage()
            }
            .store(in: &cancellables)
        progressStore.onChange = { [weak self] in
            guard let self else { return }
            self.updateProgressMenuState()
        }
        metricsMonitor.onUpdate = { [weak self] snapshot in
            guard let self else { return }
            self.latestMetrics = snapshot
            self.updateMetricsMenuState()
        }
        if showsSystemInfo {
            metricsMonitor.start()
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        updateStatusImage()
        button.imagePosition = .imageOnly
        button.toolTip = "CubePet"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.minimumWidth = Self.fixedMenuWidth
        configureRootMenuImages()

        progressItem.view = progressRowView
        progressItem.isEnabled = false
        menu.addItem(progressItem)

        menu.addItem(.separator())

        cpuItem.view = cpuMemoryRowView
        cpuItem.isEnabled = false
        menu.addItem(cpuItem)

        networkItem.view = networkRowView
        networkItem.isEnabled = false
        menu.addItem(networkItem)

        menu.addItem(metricsBottomSeparator)

        shopItem.submenu = makeShopMenu()
        menu.addItem(shopItem)

        skinItem.submenu = makeSkinMenu()
        menu.addItem(skinItem)

        petItem.submenu = makePetMenu()
        menu.addItem(petItem)

        petCustomizationItem.target = self
        menu.addItem(petCustomizationItem)

        settingItem.submenu = makeSettingMenu()
        menu.addItem(settingItem)

        menu.addItem(.separator())

        activityMonitorItem.target = self
        menu.addItem(activityMonitorItem)

        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        exitItem.target = self
        menu.addItem(exitItem)

        statusItem.menu = menu
        updateLocalizedText()
    }

    private func configureRootMenuImages() {
        shopItem.image = NSImage(systemSymbolName: "bag", accessibilityDescription: nil)
        skinItem.image = NSImage(systemSymbolName: "tshirt", accessibilityDescription: nil)
        petItem.image = NSImage(systemSymbolName: "pawprint", accessibilityDescription: nil)
        settingItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        activityMonitorItem.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        exitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        progressStore.synchronizeRuntime(ageStore.totalRuntime)
        updateLocalizedText()
    }

    func menuDidClose(_ menu: NSMenu) {
        updateMetricsMenuState()
        updateProgressMenuState()
    }

    @objc private func openActivityMonitor() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        onQuit()
    }

    @objc private func showAbout() {
        onShowAbout()
    }

    @objc private func openPetCustomization() {
        guard featureEntitlementStore.isUnlocked(.petCustomization) else {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = languageSettings.text(.petCustomizationLocked)
            alert.informativeText = languageSettings.text(.petCustomizationLockedMessage)
            alert.addButton(withTitle: languageSettings.text(.ok))
            alert.runModal()
            return
        }

        onShowPetCustomization()
    }

    @objc private func toggleSystemInfo() {
        showsSystemInfo.toggle()
        UserDefaults.standard.set(showsSystemInfo, forKey: Self.showsSystemInfoKey)

        if showsSystemInfo {
            metricsMonitor.start()
        } else {
            metricsMonitor.stop()
        }
        updateSystemInfoVisibility()
    }

    @objc private func selectMoveToTrash() {
        feedSettings.destination = .trash
        updateFeedMenuState()
    }

    @objc private func selectMoveToFolder() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = languageSettings.text(.chooseFeedFolder)
        panel.prompt = languageSettings.text(.choose)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = feedSettings.folderURL

        if panel.runModal() == .OK, let url = panel.url {
            feedSettings.folderURL = url
            feedSettings.destination = .folder
        }

        updateFeedMenuState()
    }

    @objc private func selectAirDrop() {
        feedSettings.destination = .airDrop
        updateFeedMenuState()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue)
        else { return }

        languageSettings.language = language
        updateLocalizedText()
    }

    @objc private func selectSkin(_ sender: NSMenuItem) {
        guard let skinID = sender.representedObject as? String else { return }

        if appearanceSettings.selectSkin(id: skinID, progress: progressStore) {
            updateStatusImage()
        }
        updateSkinMenuState()
    }

    @objc private func selectPet(_ sender: NSMenuItem) {
        guard let petID = sender.representedObject as? String else { return }

        let didSelect = PetCatalog.pet(id: petID) != nil
            ? appearanceSettings.selectPet(id: petID, progress: progressStore)
            : appearanceSettings.selectCustomPet(
                id: petID,
                customizationStore: customizationStore,
                featureEntitlementStore: featureEntitlementStore
            )

        if didSelect {
            skinItem.submenu = makeSkinMenu()
            shopSkinsItem.submenu = makeShopSkinMenu()
            updateStatusImage()
        }
        updatePetMenuState()
        updateSkinMenuState()
    }

    @objc private func buyFood(_ sender: NSMenuItem) {
        guard
            let foodID = sender.representedObject as? String,
            let food = ShopCatalog.food(id: foodID),
            progressStore.canAfford(food)
        else { return }

        do {
            let createdFood = try DesktopFoodFile.create(
                food: food,
                displayName: languageSettings.foodName(food.name)
            )
            guard progressStore.purchaseFood(food, token: createdFood.payload.token) else {
                DesktopFoodFile.remove(createdFood.url)
                return
            }
        } catch {
            showFoodCreationError(error)
            return
        }

        updateProgressMenuState()
    }

    private func showFoodCreationError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = languageSettings.text(.foodCreationFailed)
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: languageSettings.text(.ok))
        alert.runModal()
    }

    @objc private func buySkin(_ sender: NSMenuItem) {
        guard
            let skinID = sender.representedObject as? String,
            let skin = appearanceSettings.selectedPet.skin(id: skinID),
            progressStore.buySkin(skin, for: appearanceSettings.selectedPetID)
        else { return }

        _ = appearanceSettings.selectSkin(id: skin.id, progress: progressStore)
        updateStatusImage()
        updateProgressMenuState()
    }

    @objc private func buyPet(_ sender: NSMenuItem) {
        guard
            let petID = sender.representedObject as? String,
            let pet = PetCatalog.pet(id: petID),
            progressStore.buyPet(pet)
        else { return }

        _ = appearanceSettings.selectPet(id: pet.id, progress: progressStore)
        skinItem.submenu = makeSkinMenu()
        shopSkinsItem.submenu = makeShopSkinMenu()
        updateStatusImage()
        updateProgressMenuState()
    }

    private func makeShopMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        shopFoodMenuItems.removeAll()
        shopPetMenuItems.removeAll()

        let foodMenu = NSMenu()
        foodMenu.autoenablesItems = false
        for food in ShopCatalog.foods {
            let item = NSMenuItem(title: "", action: #selector(buyFood(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = food.id
            foodMenu.addItem(item)
            shopFoodMenuItems[food.id] = item
        }
        shopFoodItem.image = NSImage(
            systemSymbolName: "takeoutbag.and.cup.and.straw",
            accessibilityDescription: languageSettings.text(.food)
        )
        shopFoodItem.submenu = foodMenu
        menu.addItem(shopFoodItem)

        shopSkinsItem.image = NSImage(systemSymbolName: "tshirt", accessibilityDescription: nil)
        shopSkinsItem.submenu = makeShopSkinMenu()
        menu.addItem(shopSkinsItem)

        let petMenu = NSMenu()
        petMenu.autoenablesItems = false
        for pet in PetCatalog.pets {
            let item = NSMenuItem(title: "", action: #selector(buyPet(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pet.id
            item.image = Self.makeStatusImage(pet: pet, skin: pet.skins[0])
            petMenu.addItem(item)
            shopPetMenuItems[pet.id] = item
        }
        shopPetsItem.image = NSImage(systemSymbolName: "pawprint", accessibilityDescription: nil)
        shopPetsItem.submenu = petMenu
        menu.addItem(shopPetsItem)

        updateShopMenuState()
        return menu
    }

    private func makeShopSkinMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        shopSkinMenuItems.removeAll()

        guard !appearanceSettings.isCustomPetSelected else { return menu }

        for skin in appearanceSettings.selectedPet.skins {
            let item = NSMenuItem(title: "", action: #selector(buySkin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = skin.id
            item.image = Self.makeSkinSwatch(color: skin.color)
            menu.addItem(item)
            shopSkinMenuItems[skin.id] = item
        }

        updateShopMenuState()
        return menu
    }

    private func makeSkinMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        skinMenuItems.removeAll()

        guard !appearanceSettings.isCustomPetSelected else { return menu }

        for skin in appearanceSettings.selectedPet.skins {
            let item = NSMenuItem(title: "", action: #selector(selectSkin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = skin.id
            item.image = Self.makeSkinSwatch(color: skin.color)
            menu.addItem(item)
            skinMenuItems[skin.id] = item
        }

        updateSkinMenuState()
        return menu
    }

    private func makeSettingMenu() -> NSMenu {
        let menu = NSMenu()

        let feedMenu = NSMenu()

        moveToTrashItem.target = self
        feedMenu.addItem(moveToTrashItem)

        moveToFolderItem.target = self
        feedMenu.addItem(moveToFolderItem)

        airDropItem.target = self
        feedMenu.addItem(airDropItem)

        feedItem.submenu = feedMenu
        menu.addItem(feedItem)

        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            languageMenu.addItem(item)
            languageMenuItems[language] = item
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(.separator())
        showSystemInfoItem.target = self
        menu.addItem(showSystemInfoItem)

        updateFeedMenuState()
        updatePetMenuState()
        updateLanguageMenuState()
        updateSystemInfoVisibility()

        return menu
    }

    private func makePetMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        petMenuItems.removeAll()

        for pet in PetCatalog.pets {
            let item = NSMenuItem(title: "", action: #selector(selectPet(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pet.id
            item.isEnabled = true
            item.image = Self.makeStatusImage(pet: pet, skin: pet.skins[0])
            menu.addItem(item)
            petMenuItems[pet.id] = item
        }

        if featureEntitlementStore.isUnlocked(.petCustomization) {
            for pet in customizationStore.customPets {
                let item = NSMenuItem(title: pet.name, action: #selector(selectPet(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = pet.id
                item.isEnabled = true
                item.image = customPetStatusImage(pet)
                menu.addItem(item)
                petMenuItems[pet.id] = item
            }
        }

        updatePetMenuState()
        return menu
    }

    private func updateLocalizedText() {
        activityMonitorItem.title = languageSettings.text(.activityMonitor)
        skinItem.title = languageSettings.text(.changeSkin)
        shopItem.title = languageSettings.text(.shop)
        shopFoodItem.title = languageSettings.text(.food)
        shopSkinsItem.title = languageSettings.text(.skins)
        shopPetsItem.title = languageSettings.text(.pets)
        settingItem.title = languageSettings.text(.setting)
        petItem.title = languageSettings.text(.pet)
        skinItem.isEnabled = !appearanceSettings.isCustomPetSelected
        updatePetCustomizationMenuState()
        aboutItem.title = languageSettings.text(.aboutCubePet)
        feedItem.title = languageSettings.text(.eatAction)
        languageItem.title = languageSettings.text(.language)
        showSystemInfoItem.title = languageSettings.text(.showSystemInfo)
        exitItem.title = languageSettings.text(.exit)
        updateMetricsMenuState()
        updateProgressTitle()
        updateFeedMenuState()
        updatePetMenuState()
        updateSkinMenuState()
        updateShopMenuState()
        updateLanguageMenuState()
        updateSystemInfoVisibility()
    }

    private func updateFeedMenuState() {
        moveToTrashItem.state = feedSettings.destination == .trash ? .on : .off
        moveToFolderItem.state = feedSettings.destination == .folder ? .on : .off
        airDropItem.state = feedSettings.destination == .airDrop ? .on : .off
        moveToTrashItem.title = languageSettings.text(.moveToTrash)
        airDropItem.title = languageSettings.text(.airDrop)

        if let folderURL = feedSettings.folderURL {
            moveToFolderItem.title = languageSettings.moveToFolderTitle(folderName: folderURL.lastPathComponent)
            moveToFolderItem.toolTip = folderURL.path
        } else {
            moveToFolderItem.title = languageSettings.moveToFolderTitle(folderName: nil)
            moveToFolderItem.toolTip = nil
        }
    }

    private func updateLanguageMenuState() {
        for (language, item) in languageMenuItems {
            item.state = languageSettings.language == language ? .on : .off
        }
    }

    private func updatePetMenuState() {
        for pet in PetCatalog.pets {
            guard let item = petMenuItems[pet.id] else { continue }
            item.title = languageSettings.petName(pet.name)
            item.isEnabled = progressStore.ownsPet(pet.id)
            item.state = appearanceSettings.selectedPetID == pet.id ? .on : .off
        }
        for pet in customizationStore.customPets {
            guard let item = petMenuItems[pet.id] else { continue }
            item.title = pet.name
            item.isEnabled = featureEntitlementStore.isUnlocked(.petCustomization)
            item.state = appearanceSettings.selectedPetID == pet.id ? .on : .off
        }
        skinItem.isEnabled = !appearanceSettings.isCustomPetSelected
        updatePetCustomizationMenuState()
    }

    private func updatePetCustomizationMenuState() {
        let isUnlocked = featureEntitlementStore.isUnlocked(.petCustomization)
        petCustomizationItem.title = languageSettings.text(.petCustomization)
        petCustomizationItem.isEnabled = isUnlocked
        petCustomizationItem.image = NSImage(
            systemSymbolName: isUnlocked ? "slider.horizontal.3" : "lock.fill",
            accessibilityDescription: nil
        )
    }

    private func updateSkinMenuState() {
        guard !appearanceSettings.isCustomPetSelected else {
            skinItem.isEnabled = false
            return
        }
        let level = progressStore.level(for: appearanceSettings.selectedPetID)

        for skin in appearanceSettings.selectedPet.skins {
            guard let item = skinMenuItems[skin.id] else { continue }

            let isUnlocked = progressStore.ownsSkin(skin.id) && skin.isUnlocked(at: level)
            item.isEnabled = isUnlocked
            item.state = appearanceSettings.selectedSkinID == skin.id ? .on : .off
            item.title = level < skin.unlockLevel
                ? "\(languageSettings.skinName(skin.name)) · Lv\(skin.unlockLevel)"
                : languageSettings.skinName(skin.name)
        }
    }

    private func updateProgressMenuState() {
        updateProgressTitle()
        updatePetMenuState()
        updateSkinMenuState()
        updateShopMenuState()
    }

    private func updateProgressTitle() {
        let level = progressStore.level(for: appearanceSettings.selectedPetID)
        progressRowView.setText(
            left: "\(languageSettings.text(.level)) \(level)",
            right: "\(progressStore.coins)G"
        )
    }

    private func updateShopMenuState() {
        for food in ShopCatalog.foods {
            guard let item = shopFoodMenuItems[food.id] else { continue }
            item.attributedTitle = foodStoreTitle(food)
            item.isEnabled = progressStore.coins >= food.price
        }

        if !appearanceSettings.isCustomPetSelected {
            let petID = appearanceSettings.selectedPetID
            let level = progressStore.level(for: petID)
            for skin in appearanceSettings.selectedPet.skins {
                guard let item = shopSkinMenuItems[skin.id] else { continue }
                let isOwned = progressStore.ownsSkin(skin.id)
                item.title = languageSettings.skinStoreTitle(skin, isOwned: isOwned, currentLevel: level)
                item.isEnabled = !isOwned && skin.isUnlocked(at: level) && progressStore.coins >= skin.price
            }
        }

        for pet in PetCatalog.pets {
            guard let item = shopPetMenuItems[pet.id] else { continue }
            let isOwned = progressStore.ownsPet(pet.id)
            item.title = languageSettings.petStoreTitle(pet, isOwned: isOwned)
            item.isEnabled = !isOwned && progressStore.coins >= pet.price
        }
    }

    private func foodStoreTitle(_ food: FoodDefinition) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: foodPriceTabLocation(font: font))]

        return NSAttributedString(
            string: "\(languageSettings.foodName(food.name))\t\(food.price)G",
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private func foodPriceTabLocation(font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let longestName = ShopCatalog.foods
            .map { (languageSettings.foodName($0.name) as NSString).size(withAttributes: attributes).width }
            .max() ?? 0
        let widestPrice = ShopCatalog.foods
            .map { ("\($0.price)G" as NSString).size(withAttributes: attributes).width }
            .max() ?? 0

        return ceil(longestName + 12 + widestPrice)
    }

    private func updateMetricsMenuState() {
        cpuMemoryRowView.setText(
            left: "\(languageSettings.text(.cpu)): \(percentage(latestMetrics.cpuUsage))",
            right: "\(languageSettings.text(.memory)): \(percentage(latestMetrics.memoryUsage))"
        )
        networkRowView.setText(
            left: languageSettings.text(.network),
            right: "↓\(speed(latestMetrics.downloadBytesPerSecond)) ↑\(speed(latestMetrics.uploadBytesPerSecond))"
        )
    }

    private func updateSystemInfoVisibility() {
        cpuItem.isHidden = !showsSystemInfo
        networkItem.isHidden = !showsSystemInfo
        metricsBottomSeparator.isHidden = !showsSystemInfo
        showSystemInfoItem.state = showsSystemInfo ? .on : .off
    }

    private func percentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func speed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1_024 {
            return "\(Int(bytesPerSecond.rounded())) B/s"
        }
        if bytesPerSecond < 1_048_576 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_024)
        }
        if bytesPerSecond < 1_073_741_824 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        }
        return String(format: "%.1f GB/s", bytesPerSecond / 1_073_741_824)
    }

    private func updateStatusImage() {
        if let customPet = customizationStore.customPet(id: appearanceSettings.selectedPetID) {
            statusItem.button?.image = customPetStatusImage(customPet)
        } else {
            statusItem.button?.image = Self.makeStatusImage(
                pet: appearanceSettings.selectedPet,
                skin: appearanceSettings.selectedSkin
            )
        }
    }

    private func customPetStatusImage(_ pet: CustomPetDefinition) -> NSImage? {
        let state = pet.visualConfiguration.configuration(for: .normal)
        guard
            case let .importedAsset(assetID) = state.base,
            let url = customizationStore.assetURL(for: assetID),
            let source = NSImage(contentsOf: url)
        else {
            return NSImage(systemSymbolName: "pawprint", accessibilityDescription: nil)
        }

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(x: 0, y: 0, width: 18, height: 18),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func makeStatusImage(pet: PetDefinition, skin: PetSkinDefinition) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        switch pet.visualKind {
        case .cube:
            let bodyRect = NSRect(x: 2.5, y: 2.5, width: 13, height: 13)
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 3, yRadius: 3)
            skin.color.setFill()
            bodyPath.fill()

            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: 6, y: 8, width: 2.5, height: 4), xRadius: 1.2, yRadius: 1.2).fill()
            NSBezierPath(roundedRect: NSRect(x: 10, y: 8, width: 2.5, height: 4), xRadius: 1.2, yRadius: 1.2).fill()
        case .frog:
            NSGraphicsContext.current?.imageInterpolation = .high
            FrogPetAsset.image?.draw(
                in: NSRect(x: 0, y: 0, width: 18, height: 18),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6.4, y: 11.8, width: 0.9, height: 0.9)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10.9, y: 11.8, width: 0.9, height: 0.9)).fill()
        case .cat:
            NSGraphicsContext.current?.imageInterpolation = .high
            let catImage: NSImage? = switch skin.id {
            case "cat.grayTabby": CatPetAsset.grayTabbyImage
            case "cat.calico": CatPetAsset.calicoImage
            case "cat.black": CatPetAsset.blackImage
            case "cat.siamese": CatPetAsset.siameseImage
            default: CatPetAsset.image
            }
            catImage?.draw(
                in: NSRect(x: 0, y: 0, width: 18, height: 18),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6.1, y: 11.1, width: 2.5, height: 2.5)).fill()
            NSBezierPath(ovalIn: NSRect(x: 9.1, y: 11.1, width: 2.5, height: 2.5)).fill()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6.9, y: 11.9, width: 0.95, height: 0.95)).fill()
            NSBezierPath(ovalIn: NSRect(x: 9.9, y: 11.9, width: 0.95, height: 0.95)).fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func makeSkinSwatch(color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)

        image.lockFocus()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 12, height: 12), xRadius: 3, yRadius: 3).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private final class FixedMenuStatusRowView: NSView {
    private let leftLabel = NSTextField(labelWithString: "")
    private let rightLabel = NSTextField(labelWithString: "")
    private let preferredLeftWidth: CGFloat?
    private let horizontalInset: CGFloat = 16
    private let gap: CGFloat = 8
    private let labelHeight: CGFloat = 17

    init(width: CGFloat, height: CGFloat, leftWidth: CGFloat? = nil) {
        self.preferredLeftWidth = leftWidth
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        for label in [leftLabel, rightLabel] {
            label.font = .menuFont(ofSize: 0)
            label.textColor = .labelColor
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.usesSingleLineMode = true
            label.cell?.truncatesLastVisibleLine = true
            addSubview(label)
        }

        rightLabel.alignment = .right
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        frame.size
    }

    override func layout() {
        super.layout()

        let y = floor((bounds.height - labelHeight) / 2)
        let contentWidth = max(0, bounds.width - horizontalInset * 2)
        let leftWidth: CGFloat
        let rightWidth: CGFloat
        if let preferredLeftWidth {
            leftWidth = min(preferredLeftWidth, max(0, contentWidth - gap))
            rightWidth = max(0, contentWidth - leftWidth - gap)
        } else {
            rightWidth = min(92, max(58, contentWidth * 0.38))
            leftWidth = max(0, contentWidth - rightWidth - gap)
        }

        leftLabel.frame = NSRect(
            x: horizontalInset,
            y: y,
            width: leftWidth,
            height: labelHeight
        )
        rightLabel.frame = NSRect(
            x: horizontalInset + leftWidth + gap,
            y: y,
            width: rightWidth,
            height: labelHeight
        )
    }

    func setText(left: String, right: String) {
        leftLabel.stringValue = left
        rightLabel.stringValue = right
    }
}
