import Combine
import Foundation

enum AppLanguage: String, CaseIterable {
    case english
    case japanese
    case korean
    case simplifiedChinese
    case traditionalChinese

    var displayName: String {
        switch self {
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .simplifiedChinese: "中文（简体）"
        case .traditionalChinese: "中文（繁體）"
        }
    }
}

enum AppText {
    case level
    case shop
    case food
    case skins
    case pets
    case owned
    case activityMonitor
    case changeSkin
    case pet
    case showSystemInfo
    case aboutCubePet
    case aboutDescription
    case cpu
    case memory
    case network
    case setting
    case exit
    case eatAction
    case language
    case moveToTrash
    case moveToFolder
    case airDrop
    case chooseFeedFolder
    case choose
    case ok
    case folderNotFound
    case folderNotFoundMessage
    case airDropUnavailable
    case airDropUnavailableMessage
    case foodCreationFailed
}

final class LanguageSettings: ObservableObject {
    private static let languageKey = "MacBookPet.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    init() {
        let savedValue = UserDefaults.standard.string(forKey: Self.languageKey)
        language = savedValue.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    func text(_ key: AppText) -> String {
        switch language {
        case .english:
            englishText(key)
        case .japanese:
            japaneseText(key)
        case .korean:
            koreanText(key)
        case .simplifiedChinese:
            simplifiedChineseText(key)
        case .traditionalChinese:
            traditionalChineseText(key)
        }
    }

    func moveToFolderTitle(folderName: String?) -> String {
        guard let folderName else { return text(.moveToFolder) }
        return "\(text(.moveToFolder)) (\(folderName))"
    }

    func progressTitle(level: Int, coins: Int) -> String {
        "\(text(.level)) \(level)\u{2002}\u{2002}·\u{2002}\u{2002}\(coins)G"
    }

    func experienceGainText(_ amount: Int) -> String {
        switch language {
        case .english: "+\(amount) XP"
        case .japanese: "経験値 +\(amount)"
        case .korean: "경험치 +\(amount)"
        case .simplifiedChinese: "+\(amount) 经验"
        case .traditionalChinese: "+\(amount) 經驗"
        }
    }

    func skinStoreTitle(_ skin: PetSkinDefinition, isOwned: Bool, currentLevel: Int) -> String {
        if isOwned {
            return "\(skinName(skin.name)) · \(text(.owned))"
        }
        if currentLevel < skin.unlockLevel {
            return "\(skinName(skin.name)) · Lv\(skin.unlockLevel)"
        }
        return "\(skinName(skin.name)) · \(skin.price)G"
    }

    func petStoreTitle(_ pet: PetDefinition, isOwned: Bool) -> String {
        isOwned
            ? "\(petName(pet.name)) · \(text(.owned))"
            : "\(petName(pet.name)) · \(pet.price)G"
    }

    func foodName(_ name: FoodName) -> String {
        switch (language, name) {
        case (.english, .smallCookie): "Small Cookie"
        case (.english, .energyBar): "Energy Bar"
        case (.english, .petCola): "Pet Cola"
        case (.japanese, .smallCookie): "ミニクッキー"
        case (.japanese, .energyBar): "エナジーバー"
        case (.japanese, .petCola): "ペットコーラ"
        case (.korean, .smallCookie): "작은 쿠키"
        case (.korean, .energyBar): "에너지 바"
        case (.korean, .petCola): "펫 콜라"
        case (.simplifiedChinese, .smallCookie): "小饼干"
        case (.simplifiedChinese, .energyBar): "能量棒"
        case (.simplifiedChinese, .petCola): "宠物可乐"
        case (.traditionalChinese, .smallCookie): "小餅乾"
        case (.traditionalChinese, .energyBar): "能量棒"
        case (.traditionalChinese, .petCola): "寵物可樂"
        }
    }

    func skinName(_ name: PetSkinName) -> String {
        switch (language, name) {
        case (.english, .classic): "Black Cube"
        case (.english, .blue): "Blue Cube"
        case (.english, .green): "Green Cube"
        case (.english, .red): "Red Cube"
        case (.english, .pink): "Pink Cube"
        case (.english, .frogClassic): "Classic Frog"
        case (.english, .catClassic): "Classic Cat"
        case (.english, .catGrayTabby): "Glutton Cat"
        case (.english, .catCalico): "Calico Cat"
        case (.japanese, .classic): "黒ブロック"
        case (.japanese, .blue): "青ブロック"
        case (.japanese, .green): "緑ブロック"
        case (.japanese, .red): "赤ブロック"
        case (.japanese, .pink): "ピンクブロック"
        case (.japanese, .frogClassic): "クラシックカエル"
        case (.japanese, .catClassic): "クラシック猫"
        case (.japanese, .catGrayTabby): "食いしん坊猫"
        case (.japanese, .catCalico): "三毛猫"
        case (.korean, .classic): "검은 블록"
        case (.korean, .blue): "파란 블록"
        case (.korean, .green): "초록 블록"
        case (.korean, .red): "빨간 블록"
        case (.korean, .pink): "분홍 블록"
        case (.korean, .frogClassic): "기본 개구리"
        case (.korean, .catClassic): "기본 고양이"
        case (.korean, .catGrayTabby): "먹보 고양이"
        case (.korean, .catCalico): "삼색 고양이"
        case (.simplifiedChinese, .classic): "黑块"
        case (.simplifiedChinese, .blue): "蓝块"
        case (.simplifiedChinese, .green): "绿块"
        case (.simplifiedChinese, .red): "红块"
        case (.simplifiedChinese, .pink): "粉块"
        case (.simplifiedChinese, .frogClassic): "青蛙原色"
        case (.simplifiedChinese, .catClassic): "橘色虎斑猫"
        case (.simplifiedChinese, .catGrayTabby): "贪吃猫"
        case (.simplifiedChinese, .catCalico): "三花猫"
        case (.traditionalChinese, .classic): "黑塊"
        case (.traditionalChinese, .blue): "藍塊"
        case (.traditionalChinese, .green): "綠塊"
        case (.traditionalChinese, .red): "紅塊"
        case (.traditionalChinese, .pink): "粉塊"
        case (.traditionalChinese, .frogClassic): "青蛙原色"
        case (.traditionalChinese, .catClassic): "貓咪原色"
        case (.traditionalChinese, .catGrayTabby): "貪吃貓"
        case (.traditionalChinese, .catCalico): "三花貓"
        }
    }

    func petName(_ name: PetName) -> String {
        switch (language, name) {
        case (.english, .cube): "Cube"
        case (.english, .frog): "Frog"
        case (.english, .cat): "Cat"
        case (.japanese, .cube): "キューブ"
        case (.japanese, .frog): "カエル"
        case (.japanese, .cat): "猫"
        case (.korean, .cube): "큐브"
        case (.korean, .frog): "개구리"
        case (.korean, .cat): "고양이"
        case (.simplifiedChinese, .cube): "方块"
        case (.simplifiedChinese, .frog): "青蛙"
        case (.simplifiedChinese, .cat): "猫咪"
        case (.traditionalChinese, .cube): "方塊"
        case (.traditionalChinese, .frog): "青蛙"
        case (.traditionalChinese, .cat): "貓咪"
        }
    }

    func editionTitle() -> String {
        switch language {
        case .english: "Free & Open Source Edition"
        case .japanese: "無料オープンソース版"
        case .korean: "무료 오픈 소스 버전"
        case .simplifiedChinese: "免费开源版"
        case .traditionalChinese: "免費開源版"
        }
    }

    func appStoreAvailabilityTitle() -> String {
        switch language {
        case .english: "Full version available free on the App Store"
        case .japanese: "App Storeで無料のフル版を配信中"
        case .korean: "App Store에서 무료 정식 버전 제공"
        case .simplifiedChinese: "免费完整版在App Store"
        case .traditionalChinese: "免費完整版在App Store"
        }
    }

    private func englishText(_ key: AppText) -> String {
        switch key {
        case .level: "Lv."
        case .shop: "Shop"
        case .food: "Food"
        case .skins: "Skins"
        case .pets: "Pets"
        case .owned: "Owned"
        case .activityMonitor: "Activity Monitor"
        case .changeSkin: "Change Skin"
        case .pet: "Change Pet"
        case .showSystemInfo: "Show System Info"
        case .aboutCubePet: "About CubePet"
        case .aboutDescription: "A casual desktop pet app currently in an early stage of development.\nDeveloped with assistance from GPT."
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "Net"
        case .setting: "Setting"
        case .exit: "Exit"
        case .eatAction: "Eat Action"
        case .language: "Language"
        case .moveToTrash: "Move to Trash"
        case .moveToFolder: "Move to Folder..."
        case .airDrop: "AirDrop"
        case .chooseFeedFolder: "Choose Feed Folder"
        case .choose: "Choose"
        case .ok: "OK"
        case .folderNotFound: "Folder Not Found"
        case .folderNotFoundMessage: "The target folder could not be found, so the dropped items were moved to the Trash."
        case .airDropUnavailable: "AirDrop Unavailable"
        case .airDropUnavailableMessage: "AirDrop is unavailable for the dropped items."
        case .foodCreationFailed: "Could Not Create Food"
        }
    }

    private func japaneseText(_ key: AppText) -> String {
        switch key {
        case .level: "Lv."
        case .shop: "ショップ"
        case .food: "食べ物"
        case .skins: "スキン"
        case .pets: "ペット"
        case .owned: "購入済み"
        case .activityMonitor: "アクティビティモニタ"
        case .changeSkin: "スキンを変更"
        case .pet: "ペットを変更"
        case .showSystemInfo: "システム情報を表示"
        case .aboutCubePet: "CubePetについて"
        case .aboutDescription: "気軽に楽しめるデスクトップペットアプリです。現在は初期開発段階です。\n本ソフトウェアはGPTの支援を受けて開発されました。"
        case .cpu: "CPU"
        case .memory: "メモリ"
        case .network: "通信"
        case .setting: "設定"
        case .exit: "終了"
        case .eatAction: "食べる設定"
        case .language: "言語"
        case .moveToTrash: "ゴミ箱に移動"
        case .moveToFolder: "フォルダに移動..."
        case .airDrop: "AirDrop"
        case .chooseFeedFolder: "保存先フォルダを選択"
        case .choose: "選択"
        case .ok: "OK"
        case .folderNotFound: "フォルダが見つかりません"
        case .folderNotFoundMessage: "保存先フォルダが見つからないため、ドロップした項目をゴミ箱に移動しました。"
        case .airDropUnavailable: "AirDropを使用できません"
        case .airDropUnavailableMessage: "ドロップした項目をAirDropで送信できません。"
        case .foodCreationFailed: "食べ物を作成できませんでした"
        }
    }

    private func koreanText(_ key: AppText) -> String {
        switch key {
        case .level: "Lv."
        case .shop: "상점"
        case .food: "먹이"
        case .skins: "스킨"
        case .pets: "펫"
        case .owned: "보유"
        case .activityMonitor: "활성 상태 보기"
        case .changeSkin: "스킨 변경"
        case .pet: "펫 변경"
        case .showSystemInfo: "시스템 정보 표시"
        case .aboutCubePet: "CubePet 정보"
        case .aboutDescription: "가볍게 즐기는 데스크톱 펫 앱으로, 현재 초기 개발 단계입니다.\n이 소프트웨어는 GPT의 도움을 받아 개발되었습니다."
        case .cpu: "CPU"
        case .memory: "메모리"
        case .network: "네트워크"
        case .setting: "설정"
        case .exit: "종료"
        case .eatAction: "먹기 설정"
        case .language: "언어"
        case .moveToTrash: "휴지통으로 이동"
        case .moveToFolder: "폴더로 이동..."
        case .airDrop: "AirDrop"
        case .chooseFeedFolder: "저장 폴더 선택"
        case .choose: "선택"
        case .ok: "확인"
        case .folderNotFound: "폴더를 찾을 수 없음"
        case .folderNotFoundMessage: "대상 폴더를 찾을 수 없어 드롭한 항목을 휴지통으로 이동했습니다."
        case .airDropUnavailable: "AirDrop을 사용할 수 없음"
        case .airDropUnavailableMessage: "드롭한 항목을 AirDrop으로 보낼 수 없습니다."
        case .foodCreationFailed: "먹이 파일을 만들 수 없음"
        }
    }

    private func simplifiedChineseText(_ key: AppText) -> String {
        switch key {
        case .level: "等级"
        case .shop: "商店"
        case .food: "食物"
        case .skins: "皮肤"
        case .pets: "宠物"
        case .owned: "已拥有"
        case .activityMonitor: "活动监视器"
        case .changeSkin: "更换皮肤"
        case .pet: "更换宠物"
        case .showSystemInfo: "显示系统信息"
        case .aboutCubePet: "关于CubePet"
        case .aboutDescription: "CubePet 是一只住在桌面上的小宠物，\n陪你工作、安静成长～\n偶尔也能帮你吃掉不需要的文件^_^"
        case .cpu: "CPU"
        case .memory: "内存"
        case .network: "网速"
        case .setting: "设置"
        case .exit: "退出"
        case .eatAction: "吃掉设置"
        case .language: "语言"
        case .moveToTrash: "移到废纸篓"
        case .moveToFolder: "移动到文件夹..."
        case .airDrop: "隔空投送"
        case .chooseFeedFolder: "选择保存文件夹"
        case .choose: "选择"
        case .ok: "好"
        case .folderNotFound: "找不到文件夹"
        case .folderNotFoundMessage: "找不到目标文件夹，拖入的项目已移到废纸篓。"
        case .airDropUnavailable: "隔空投送不可用"
        case .airDropUnavailableMessage: "无法通过隔空投送发送拖入的项目。"
        case .foodCreationFailed: "无法创建食物"
        }
    }

    private func traditionalChineseText(_ key: AppText) -> String {
        switch key {
        case .level: "等級"
        case .shop: "商店"
        case .food: "食物"
        case .skins: "皮膚"
        case .pets: "寵物"
        case .owned: "已擁有"
        case .activityMonitor: "活動監視器"
        case .changeSkin: "更換皮膚"
        case .pet: "更換寵物"
        case .showSystemInfo: "顯示系統資訊"
        case .aboutCubePet: "關於CubePet"
        case .aboutDescription: "這是一款休閒桌面寵物軟體，目前只是初步開發階段。\n本軟體由GPT協助開發"
        case .cpu: "CPU"
        case .memory: "記憶體"
        case .network: "網速"
        case .setting: "設定"
        case .exit: "結束"
        case .eatAction: "吃掉設定"
        case .language: "語言"
        case .moveToTrash: "移到垃圾桶"
        case .moveToFolder: "移動到資料夾..."
        case .airDrop: "AirDrop"
        case .chooseFeedFolder: "選擇儲存資料夾"
        case .choose: "選擇"
        case .ok: "好"
        case .folderNotFound: "找不到資料夾"
        case .folderNotFoundMessage: "找不到目標資料夾，拖入的項目已移到垃圾桶。"
        case .airDropUnavailable: "AirDrop無法使用"
        case .airDropUnavailableMessage: "無法透過AirDrop傳送拖入的項目。"
        case .foodCreationFailed: "無法建立食物"
        }
    }
}
