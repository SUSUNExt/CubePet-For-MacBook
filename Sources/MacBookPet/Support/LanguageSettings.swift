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
    case satiety
    case skins
    case pets
    case owned
    case activityMonitor
    case changeSkin
    case pet
    case showSystemInfo
    case aboutCubePet
    case updateAvailable
    case aboutDescription
    case version
    case download
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
    case petCustomization
    case petCustomizationLocked
    case petCustomizationLockedMessage
    case shortcutSettings
    case menuAppearance
    case menuStyleDefault
    case menuStyleLiquidGlass
    case menuStyleDark
    case menuStyleLight
}

enum ShortcutSettingsText {
    case description
    case currentShortcut
    case currentShortcutTooltip
    case recordShortcut
    case pressNewShortcut
    case needsModifier
    case restoreDefault
    case cancel
    case save
}

enum LaunchAtLoginText {
    case title
    case approvalRequiredTitle
    case approvalRequiredMessage
    case updateFailedTitle
}

enum PetCustomizationText {
    case normal
    case happy
    case scared
    case sleeping
    case eating
    case hungry
    case showEyes
    case eyes
    case addEyes
    case addGIF
    case addFrames
    case actionFrequency
    case bottomPet
    case gravity
    case sleepingBreath
    case sleepingBreathHint
    case sleepingEffect
    case sleepingBubbles
    case sleepingZzz
    case smallActions
    case undo
    case redo
    case low
    case medium
    case high
    case alignEyes
    case eyeStyle
    case bigEyes
    case smallBlackBlockEyes
    case shibaWatercolorEyes
    case officialEyes
    case myEyePresets
    case importEyes
    case deleteEyePreset
    case importedEye
    case presetName
    case renameEyePreset
    case eyeColor
    case automatic
    case black
    case white
    case size
    case decreaseSize
    case increaseSize
    case whiteSize
    case pupilSize
    case spacing
    case moveSkinLeft
    case moveSkinRight
    case moveSkinUp
    case moveSkinDown
    case save
    case restoreOfficial
    case dragHint
    case independentDragHint
    case saved
    case currentAppearance
    case unlockedPets
    case customPets
    case newPet
    case petName
    case importImages
    case dropImagesHint
    case animationSettings
    case gifAnimation
    case frameAnimation
    case animationFrameCount
    case animationSpeed
    case framePlaybackOrder
    case dragFramesToReorder
    case clearPreview
    case deleteFrame
    case useOfficial
    case deletePet
    case deletePetConfirmation
    case deletePetWarning
    case cancel
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

    func customizationText(_ key: PetCustomizationText) -> String {
        switch (language, key) {
        case (.english, .normal): "Default"
        case (.english, .happy): "Happy"
        case (.english, .scared): "Scared"
        case (.english, .sleeping): "Sleeping"
        case (.english, .eating): "Eating"
        case (.english, .hungry): "Hungry"
        case (.english, .showEyes): "Show eye module"
        case (.english, .eyes): "Eyes"
        case (.english, .addEyes): "Add Eyes"
        case (.english, .addGIF): "Add GIF..."
        case (.english, .addFrames): "Add Image Frames..."
        case (.english, .actionFrequency): "Action frequency"
        case (.english, .bottomPet): "Bottom Pet"
        case (.english, .gravity): "Gravity"
        case (.english, .sleepingBreath): "Breathing effect"
        case (.english, .sleepingBreathHint): "Single images are recommended to use this effect."
        case (.english, .sleepingEffect): "Sleep effect"
        case (.english, .sleepingBubbles): "Bubbles"
        case (.english, .sleepingZzz): "Zzz"
        case (.english, .smallActions): "Small Actions"
        case (.english, .undo): "Undo"
        case (.english, .redo): "Redo"
        case (.english, .low): "Low"
        case (.english, .medium): "Medium"
        case (.english, .high): "High"
        case (.english, .alignEyes): "Align both eyes"
        case (.english, .eyeStyle): "Eye Type"
        case (.english, .bigEyes): "Big Eyes"
        case (.english, .smallBlackBlockEyes): "Small Black Block Eyes"
        case (.english, .shibaWatercolorEyes): "Shiba Watercolor Eyes"
        case (.english, .officialEyes): "Official Eyes"
        case (.english, .myEyePresets): "My Presets"
        case (.english, .importEyes): "Import Eyes..."
        case (.english, .deleteEyePreset): "Delete Preset"
        case (.english, .importedEye): "Imported Eyes"
        case (.english, .presetName): "Preset Name"
        case (.english, .renameEyePreset): "Rename Preset"
        case (.english, .eyeColor): "Eye color"
        case (.english, .automatic): "Automatic"
        case (.english, .black): "Black"
        case (.english, .white): "White"
        case (.english, .size): "Adjust Size"
        case (.english, .decreaseSize): "Decrease display size"
        case (.english, .increaseSize): "Increase display size"
        case (.english, .whiteSize): "White Size"
        case (.english, .pupilSize): "Pupil Size"
        case (.english, .spacing): "Spacing"
        case (.english, .moveSkinLeft): "Move skin left"
        case (.english, .moveSkinRight): "Move skin right"
        case (.english, .moveSkinUp): "Move skin up"
        case (.english, .moveSkinDown): "Move skin down"
        case (.english, .save): "Save"
        case (.english, .restoreOfficial): "Restore Official"
        case (.english, .dragHint): "Click to select. Drag the body or eyes to reposition the selected part."
        case (.english, .independentDragHint): "Click to select. Drag the body or either eye to reposition it."
        case (.english, .saved): "Saved"
        case (.english, .currentAppearance): "Current Appearance"
        case (.english, .unlockedPets): "Unlocked Pets"
        case (.english, .customPets): "Custom Pets"
        case (.english, .newPet): "New Pet"
        case (.english, .petName): "Pet Name"
        case (.english, .importImages): "Import Images..."
        case (.english, .dropImagesHint): "Drop a GIF or image frames here"
        case (.english, .animationSettings): "Animation Settings"
        case (.english, .gifAnimation): "GIF Animation"
        case (.english, .frameAnimation): "Frame Animation"
        case (.english, .animationFrameCount): "%d frames"
        case (.english, .animationSpeed): "Speed"
        case (.english, .framePlaybackOrder): "Frame Playback Order"
        case (.english, .dragFramesToReorder): "Drag thumbnails to reorder"
        case (.english, .clearPreview): "Clear Preview Image"
        case (.english, .deleteFrame): "Delete Frame"
        case (.english, .useOfficial): "Use Official Skin"
        case (.english, .deletePet): "Delete Pet"
        case (.english, .deletePetConfirmation): "Delete this pet?"
        case (.english, .deletePetWarning): "This removes the pet and its imported images. This action cannot be undone."
        case (.english, .cancel): "Cancel"
        case (.japanese, .normal): "デフォルト"
        case (.japanese, .happy): "うれしい"
        case (.japanese, .scared): "怖がる"
        case (.japanese, .sleeping): "睡眠"
        case (.japanese, .eating): "食べる"
        case (.japanese, .hungry): "空腹"
        case (.japanese, .showEyes): "目のモジュールを表示"
        case (.japanese, .eyes): "目"
        case (.japanese, .addEyes): "目を追加"
        case (.japanese, .addGIF): "GIFを追加..."
        case (.japanese, .addFrames): "連番画像を追加..."
        case (.japanese, .actionFrequency): "アクション頻度"
        case (.japanese, .bottomPet): "下部ペット"
        case (.japanese, .gravity): "重力"
        case (.japanese, .sleepingBreath): "呼吸エフェクト"
        case (.japanese, .sleepingBreathHint): "1枚の画像での使用をおすすめします。"
        case (.japanese, .sleepingEffect): "睡眠エフェクト"
        case (.japanese, .sleepingBubbles): "泡"
        case (.japanese, .sleepingZzz): "Zzz"
        case (.japanese, .smallActions): "小さなアクション"
        case (.japanese, .undo): "元に戻す"
        case (.japanese, .redo): "やり直す"
        case (.japanese, .low): "低"
        case (.japanese, .medium): "中"
        case (.japanese, .high): "高"
        case (.japanese, .alignEyes): "両目を揃える"
        case (.japanese, .eyeStyle): "目の種類"
        case (.japanese, .bigEyes): "大きな目"
        case (.japanese, .smallBlackBlockEyes): "小さな黒い四角の目"
        case (.japanese, .shibaWatercolorEyes): "柴犬の水彩風の目"
        case (.japanese, .officialEyes): "公式の目"
        case (.japanese, .myEyePresets): "マイプリセット"
        case (.japanese, .importEyes): "目を読み込む..."
        case (.japanese, .deleteEyePreset): "プリセットを削除"
        case (.japanese, .importedEye): "読み込んだ目"
        case (.japanese, .presetName): "プリセット名"
        case (.japanese, .renameEyePreset): "プリセット名を変更"
        case (.japanese, .eyeColor): "目の色"
        case (.japanese, .automatic): "自動"
        case (.japanese, .black): "黒"
        case (.japanese, .white): "白"
        case (.japanese, .size): "サイズを調整"
        case (.japanese, .decreaseSize): "表示サイズを小さくする"
        case (.japanese, .increaseSize): "表示サイズを大きくする"
        case (.japanese, .whiteSize): "白目サイズ"
        case (.japanese, .pupilSize): "瞳サイズ"
        case (.japanese, .spacing): "間隔"
        case (.japanese, .moveSkinLeft): "スキンを左へ移動"
        case (.japanese, .moveSkinRight): "スキンを右へ移動"
        case (.japanese, .moveSkinUp): "スキンを上へ移動"
        case (.japanese, .moveSkinDown): "スキンを下へ移動"
        case (.japanese, .save): "保存"
        case (.japanese, .restoreOfficial): "公式設定に戻す"
        case (.japanese, .dragHint): "クリックで選択し、胴体または目をドラッグして位置を調整します。"
        case (.japanese, .independentDragHint): "クリックで選択し、胴体または片目をドラッグして位置を調整します。"
        case (.japanese, .saved): "保存しました"
        case (.japanese, .currentAppearance): "現在の外観"
        case (.japanese, .unlockedPets): "アンロック済みペット"
        case (.japanese, .customPets): "カスタムペット"
        case (.japanese, .newPet): "新しいペット"
        case (.japanese, .petName): "ペット名"
        case (.japanese, .importImages): "画像を読み込む..."
        case (.japanese, .dropImagesHint): "GIFまたは連番画像をここにドロップ"
        case (.japanese, .animationSettings): "アニメーション設定"
        case (.japanese, .gifAnimation): "GIFアニメーション"
        case (.japanese, .frameAnimation): "フレームアニメーション"
        case (.japanese, .animationFrameCount): "%d フレーム"
        case (.japanese, .animationSpeed): "速度"
        case (.japanese, .framePlaybackOrder): "フレームの再生順"
        case (.japanese, .dragFramesToReorder): "サムネイルをドラッグして並べ替え"
        case (.japanese, .clearPreview): "プレビュー画像をクリア"
        case (.japanese, .deleteFrame): "フレームを削除"
        case (.japanese, .useOfficial): "公式スキンを使用"
        case (.japanese, .deletePet): "ペットを削除"
        case (.japanese, .deletePetConfirmation): "このペットを削除しますか？"
        case (.japanese, .deletePetWarning): "ペットと読み込んだ画像が削除されます。この操作は取り消せません。"
        case (.japanese, .cancel): "キャンセル"
        case (.korean, .normal): "기본"
        case (.korean, .happy): "행복"
        case (.korean, .scared): "무서움"
        case (.korean, .sleeping): "수면"
        case (.korean, .eating): "먹기"
        case (.korean, .hungry): "배고픔"
        case (.korean, .showEyes): "눈 모듈 표시"
        case (.korean, .eyes): "눈"
        case (.korean, .addEyes): "눈 추가"
        case (.korean, .addGIF): "GIF 추가..."
        case (.korean, .addFrames): "이미지 프레임 추가..."
        case (.korean, .actionFrequency): "동작 빈도"
        case (.korean, .bottomPet): "바닥 펫"
        case (.korean, .gravity): "중력"
        case (.korean, .sleepingBreath): "호흡 효과"
        case (.korean, .sleepingBreathHint): "단일 이미지에서 사용하는 것을 권장합니다."
        case (.korean, .sleepingEffect): "수면 효과"
        case (.korean, .sleepingBubbles): "거품"
        case (.korean, .sleepingZzz): "Zzz"
        case (.korean, .smallActions): "작은 동작"
        case (.korean, .undo): "실행 취소"
        case (.korean, .redo): "다시 실행"
        case (.korean, .low): "낮음"
        case (.korean, .medium): "중간"
        case (.korean, .high): "높음"
        case (.korean, .alignEyes): "두 눈 정렬"
        case (.korean, .eyeStyle): "눈 유형"
        case (.korean, .bigEyes): "큰 눈"
        case (.korean, .smallBlackBlockEyes): "작은 검은 네모 눈"
        case (.korean, .shibaWatercolorEyes): "시바견 수채화 눈"
        case (.korean, .officialEyes): "공식 눈"
        case (.korean, .myEyePresets): "내 프리셋"
        case (.korean, .importEyes): "눈 가져오기..."
        case (.korean, .deleteEyePreset): "프리셋 삭제"
        case (.korean, .importedEye): "가져온 눈"
        case (.korean, .presetName): "프리셋 이름"
        case (.korean, .renameEyePreset): "프리셋 이름 변경"
        case (.korean, .eyeColor): "눈 색상"
        case (.korean, .automatic): "자동"
        case (.korean, .black): "검정"
        case (.korean, .white): "흰색"
        case (.korean, .size): "크기 조절"
        case (.korean, .decreaseSize): "표시 크기 줄이기"
        case (.korean, .increaseSize): "표시 크기 늘리기"
        case (.korean, .whiteSize): "흰자 크기"
        case (.korean, .pupilSize): "동공 크기"
        case (.korean, .spacing): "간격"
        case (.korean, .moveSkinLeft): "스킨을 왼쪽으로 이동"
        case (.korean, .moveSkinRight): "스킨을 오른쪽으로 이동"
        case (.korean, .moveSkinUp): "스킨을 위로 이동"
        case (.korean, .moveSkinDown): "스킨을 아래로 이동"
        case (.korean, .save): "저장"
        case (.korean, .restoreOfficial): "공식 설정 복원"
        case (.korean, .dragHint): "클릭으로 선택한 뒤 몸통 또는 눈을 드래그해 위치를 조정하세요."
        case (.korean, .independentDragHint): "클릭으로 선택한 뒤 몸통 또는 한쪽 눈을 드래그해 위치를 조정하세요."
        case (.korean, .saved): "저장됨"
        case (.korean, .currentAppearance): "현재 외형"
        case (.korean, .unlockedPets): "잠금 해제된 펫"
        case (.korean, .customPets): "커스텀 펫"
        case (.korean, .newPet): "새 펫"
        case (.korean, .petName): "펫 이름"
        case (.korean, .importImages): "이미지 가져오기..."
        case (.korean, .dropImagesHint): "GIF 또는 애니메이션 프레임을 여기에 놓으세요"
        case (.korean, .animationSettings): "애니메이션 설정"
        case (.korean, .gifAnimation): "GIF 애니메이션"
        case (.korean, .frameAnimation): "프레임 애니메이션"
        case (.korean, .animationFrameCount): "%d 프레임"
        case (.korean, .animationSpeed): "속도"
        case (.korean, .framePlaybackOrder): "프레임 재생 순서"
        case (.korean, .dragFramesToReorder): "썸네일을 드래그하여 순서 변경"
        case (.korean, .clearPreview): "미리보기 이미지 지우기"
        case (.korean, .deleteFrame): "프레임 삭제"
        case (.korean, .useOfficial): "공식 스킨 사용"
        case (.korean, .deletePet): "펫 삭제"
        case (.korean, .deletePetConfirmation): "이 펫을 삭제할까요?"
        case (.korean, .deletePetWarning): "펫과 가져온 이미지가 삭제되며 되돌릴 수 없습니다."
        case (.korean, .cancel): "취소"
        case (.simplifiedChinese, .normal): "默认"
        case (.simplifiedChinese, .happy): "开心"
        case (.simplifiedChinese, .scared): "害怕"
        case (.simplifiedChinese, .sleeping): "睡着"
        case (.simplifiedChinese, .eating): "吃"
        case (.simplifiedChinese, .hungry): "饥饿"
        case (.simplifiedChinese, .showEyes): "显示眼睛模块"
        case (.simplifiedChinese, .eyes): "眼睛"
        case (.simplifiedChinese, .addEyes): "添加眼睛"
        case (.simplifiedChinese, .addGIF): "添加 GIF..."
        case (.simplifiedChinese, .addFrames): "添加多帧图片..."
        case (.simplifiedChinese, .actionFrequency): "小动作出现频率"
        case (.simplifiedChinese, .bottomPet): "底部宠物"
        case (.simplifiedChinese, .gravity): "重力"
        case (.simplifiedChinese, .sleepingBreath): "呼吸感"
        case (.simplifiedChinese, .sleepingBreathHint): "单张图片建议开启"
        case (.simplifiedChinese, .sleepingEffect): "睡眠特效"
        case (.simplifiedChinese, .sleepingBubbles): "气泡"
        case (.simplifiedChinese, .sleepingZzz): "Zzz"
        case (.simplifiedChinese, .smallActions): "小动作"
        case (.simplifiedChinese, .undo): "撤销"
        case (.simplifiedChinese, .redo): "重做"
        case (.simplifiedChinese, .low): "低"
        case (.simplifiedChinese, .medium): "中"
        case (.simplifiedChinese, .high): "高"
        case (.simplifiedChinese, .alignEyes): "双眼对齐"
        case (.simplifiedChinese, .eyeStyle): "眼睛类型"
        case (.simplifiedChinese, .bigEyes): "大眼睛"
        case (.simplifiedChinese, .smallBlackBlockEyes): "小黑块眼睛"
        case (.simplifiedChinese, .shibaWatercolorEyes): "柴犬水彩眼睛"
        case (.simplifiedChinese, .officialEyes): "官方眼睛"
        case (.simplifiedChinese, .myEyePresets): "我的预设"
        case (.simplifiedChinese, .importEyes): "导入眼睛..."
        case (.simplifiedChinese, .deleteEyePreset): "删除预设"
        case (.simplifiedChinese, .importedEye): "导入的眼睛"
        case (.simplifiedChinese, .presetName): "预设名称"
        case (.simplifiedChinese, .renameEyePreset): "修改预设名称"
        case (.simplifiedChinese, .eyeColor): "眼睛颜色"
        case (.simplifiedChinese, .automatic): "自动"
        case (.simplifiedChinese, .black): "黑色"
        case (.simplifiedChinese, .white): "白色"
        case (.simplifiedChinese, .size): "调整大小"
        case (.simplifiedChinese, .decreaseSize): "缩小展示大小"
        case (.simplifiedChinese, .increaseSize): "放大展示大小"
        case (.simplifiedChinese, .whiteSize): "白色大小"
        case (.simplifiedChinese, .pupilSize): "黑眼珠大小"
        case (.simplifiedChinese, .spacing): "间距"
        case (.simplifiedChinese, .moveSkinLeft): "皮肤向左微调"
        case (.simplifiedChinese, .moveSkinRight): "皮肤向右微调"
        case (.simplifiedChinese, .moveSkinUp): "皮肤向上微调"
        case (.simplifiedChinese, .moveSkinDown): "皮肤向下微调"
        case (.simplifiedChinese, .save): "保存"
        case (.simplifiedChinese, .restoreOfficial): "恢复官方设置"
        case (.simplifiedChinese, .dragHint): "点击只选中；拖动身体或眼睛，才会移动对应部件。"
        case (.simplifiedChinese, .independentDragHint): "点击只选中；拖动身体或任意一只眼睛，才会移动对应部件。"
        case (.simplifiedChinese, .saved): "已保存"
        case (.simplifiedChinese, .currentAppearance): "当前外观"
        case (.simplifiedChinese, .unlockedPets): "已解锁宠物"
        case (.simplifiedChinese, .customPets): "自定义宠物"
        case (.simplifiedChinese, .newPet): "新建宠物"
        case (.simplifiedChinese, .petName): "宠物名称"
        case (.simplifiedChinese, .importImages): "导入图片..."
        case (.simplifiedChinese, .dropImagesHint): "拖入图片或GIF"
        case (.simplifiedChinese, .animationSettings): "动画设置"
        case (.simplifiedChinese, .gifAnimation): "GIF 动画"
        case (.simplifiedChinese, .frameAnimation): "帧动画"
        case (.simplifiedChinese, .animationFrameCount): "%d 帧"
        case (.simplifiedChinese, .animationSpeed): "播放速度"
        case (.simplifiedChinese, .framePlaybackOrder): "帧播放顺序"
        case (.simplifiedChinese, .dragFramesToReorder): "拖动缩略图调整顺序"
        case (.simplifiedChinese, .clearPreview): "清空预览图片"
        case (.simplifiedChinese, .deleteFrame): "删除这一帧"
        case (.simplifiedChinese, .useOfficial): "使用官方皮肤"
        case (.simplifiedChinese, .deletePet): "删除宠物"
        case (.simplifiedChinese, .deletePetConfirmation): "删除这个宠物？"
        case (.simplifiedChinese, .deletePetWarning): "宠物及其导入的图片将被删除，此操作无法撤销。"
        case (.simplifiedChinese, .cancel): "取消"
        case (.traditionalChinese, .normal): "預設"
        case (.traditionalChinese, .happy): "開心"
        case (.traditionalChinese, .scared): "害怕"
        case (.traditionalChinese, .sleeping): "睡著"
        case (.traditionalChinese, .eating): "吃"
        case (.traditionalChinese, .hungry): "飢餓"
        case (.traditionalChinese, .showEyes): "顯示眼睛模組"
        case (.traditionalChinese, .eyes): "眼睛"
        case (.traditionalChinese, .addEyes): "加入眼睛"
        case (.traditionalChinese, .addGIF): "加入 GIF..."
        case (.traditionalChinese, .addFrames): "加入多影格圖片..."
        case (.traditionalChinese, .actionFrequency): "小動作出現頻率"
        case (.traditionalChinese, .bottomPet): "底部寵物"
        case (.traditionalChinese, .gravity): "重力"
        case (.traditionalChinese, .sleepingBreath): "呼吸感"
        case (.traditionalChinese, .sleepingBreathHint): "建議在單張圖片時開啟"
        case (.traditionalChinese, .sleepingEffect): "睡眠特效"
        case (.traditionalChinese, .sleepingBubbles): "氣泡"
        case (.traditionalChinese, .sleepingZzz): "Zzz"
        case (.traditionalChinese, .smallActions): "小動作"
        case (.traditionalChinese, .undo): "復原"
        case (.traditionalChinese, .redo): "重做"
        case (.traditionalChinese, .low): "低"
        case (.traditionalChinese, .medium): "中"
        case (.traditionalChinese, .high): "高"
        case (.traditionalChinese, .alignEyes): "雙眼對齊"
        case (.traditionalChinese, .eyeStyle): "眼睛類型"
        case (.traditionalChinese, .bigEyes): "大眼睛"
        case (.traditionalChinese, .smallBlackBlockEyes): "小黑塊眼睛"
        case (.traditionalChinese, .shibaWatercolorEyes): "柴犬水彩眼睛"
        case (.traditionalChinese, .officialEyes): "官方眼睛"
        case (.traditionalChinese, .myEyePresets): "我的預設"
        case (.traditionalChinese, .importEyes): "匯入眼睛..."
        case (.traditionalChinese, .deleteEyePreset): "刪除預設"
        case (.traditionalChinese, .importedEye): "匯入的眼睛"
        case (.traditionalChinese, .presetName): "預設名稱"
        case (.traditionalChinese, .renameEyePreset): "修改預設名稱"
        case (.traditionalChinese, .eyeColor): "眼睛顏色"
        case (.traditionalChinese, .automatic): "自動"
        case (.traditionalChinese, .black): "黑色"
        case (.traditionalChinese, .white): "白色"
        case (.traditionalChinese, .size): "調整大小"
        case (.traditionalChinese, .decreaseSize): "縮小顯示大小"
        case (.traditionalChinese, .increaseSize): "放大顯示大小"
        case (.traditionalChinese, .whiteSize): "白色大小"
        case (.traditionalChinese, .pupilSize): "黑眼珠大小"
        case (.traditionalChinese, .spacing): "間距"
        case (.traditionalChinese, .moveSkinLeft): "皮膚向左微調"
        case (.traditionalChinese, .moveSkinRight): "皮膚向右微調"
        case (.traditionalChinese, .moveSkinUp): "皮膚向上微調"
        case (.traditionalChinese, .moveSkinDown): "皮膚向下微調"
        case (.traditionalChinese, .save): "儲存"
        case (.traditionalChinese, .restoreOfficial): "恢復官方設定"
        case (.traditionalChinese, .dragHint): "點擊只會選取；拖動身體或眼睛，才會移動對應部件。"
        case (.traditionalChinese, .independentDragHint): "點擊只會選取；拖動身體或任意一隻眼睛，才會移動對應部件。"
        case (.traditionalChinese, .saved): "已儲存"
        case (.traditionalChinese, .currentAppearance): "目前外觀"
        case (.traditionalChinese, .unlockedPets): "已解鎖寵物"
        case (.traditionalChinese, .customPets): "自訂寵物"
        case (.traditionalChinese, .newPet): "新增寵物"
        case (.traditionalChinese, .petName): "寵物名稱"
        case (.traditionalChinese, .importImages): "匯入圖片..."
        case (.traditionalChinese, .dropImagesHint): "將 GIF 或多張動畫影格拖到這裡"
        case (.traditionalChinese, .animationSettings): "動畫設定"
        case (.traditionalChinese, .gifAnimation): "GIF 動畫"
        case (.traditionalChinese, .frameAnimation): "影格動畫"
        case (.traditionalChinese, .animationFrameCount): "%d 影格"
        case (.traditionalChinese, .animationSpeed): "播放速度"
        case (.traditionalChinese, .framePlaybackOrder): "影格播放順序"
        case (.traditionalChinese, .dragFramesToReorder): "拖動縮圖調整順序"
        case (.traditionalChinese, .clearPreview): "清空預覽圖片"
        case (.traditionalChinese, .deleteFrame): "刪除這一影格"
        case (.traditionalChinese, .useOfficial): "使用官方皮膚"
        case (.traditionalChinese, .deletePet): "刪除寵物"
        case (.traditionalChinese, .deletePetConfirmation): "刪除這個寵物？"
        case (.traditionalChinese, .deletePetWarning): "寵物及其匯入的圖片將被刪除，此操作無法復原。"
        case (.traditionalChinese, .cancel): "取消"
        }
    }

    func shortcutText(_ key: ShortcutSettingsText) -> String {
        switch (language, key) {
        case (.english, .description): "Use a global shortcut to open the CubePet menu when the menu bar icon is hidden or hard to reach."
        case (.english, .currentShortcut): "Current shortcut"
        case (.english, .currentShortcutTooltip): "Current shortcut: %@"
        case (.english, .recordShortcut): "Click to change"
        case (.english, .pressNewShortcut): "Press a new shortcut"
        case (.english, .needsModifier): "Press a normal key together with Control, Option, Command, or Shift."
        case (.english, .restoreDefault): "Restore Default"
        case (.english, .cancel): "Cancel"
        case (.english, .save): "Save"
        case (.japanese, .description): "メニューバーアイコンが隠れている、または押しにくい場合に、グローバルショートカットでCubePetメニューを開きます。"
        case (.japanese, .currentShortcut): "現在のショートカット"
        case (.japanese, .currentShortcutTooltip): "現在のショートカット: %@"
        case (.japanese, .recordShortcut): "クリックして変更"
        case (.japanese, .pressNewShortcut): "新しいショートカットを押してください"
        case (.japanese, .needsModifier): "Control、Option、Command、Shiftのいずれかと通常キーを同時に押してください。"
        case (.japanese, .restoreDefault): "デフォルトに戻す"
        case (.japanese, .cancel): "キャンセル"
        case (.japanese, .save): "保存"
        case (.korean, .description): "메뉴 막대 아이콘이 숨겨졌거나 누르기 어려울 때 전역 단축키로 CubePet 메뉴를 엽니다."
        case (.korean, .currentShortcut): "현재 단축키"
        case (.korean, .currentShortcutTooltip): "현재 단축키: %@"
        case (.korean, .recordShortcut): "클릭하여 변경"
        case (.korean, .pressNewShortcut): "새 단축키를 누르세요"
        case (.korean, .needsModifier): "Control, Option, Command, Shift 중 하나와 일반 키를 함께 누르세요."
        case (.korean, .restoreDefault): "기본값 복원"
        case (.korean, .cancel): "취소"
        case (.korean, .save): "저장"
        case (.simplifiedChinese, .description): "当菜单栏图标被遮挡或不方便点击时，可以用全局快捷键打开 CubePet 菜单。"
        case (.simplifiedChinese, .currentShortcut): "当前快捷键"
        case (.simplifiedChinese, .currentShortcutTooltip): "当前快捷键：%@"
        case (.simplifiedChinese, .recordShortcut): "点击修改"
        case (.simplifiedChinese, .pressNewShortcut): "请按下新的快捷键"
        case (.simplifiedChinese, .needsModifier): "请同时按下普通按键和 Control、Option、Command 或 Shift。"
        case (.simplifiedChinese, .restoreDefault): "恢复默认"
        case (.simplifiedChinese, .cancel): "取消"
        case (.simplifiedChinese, .save): "保存"
        case (.traditionalChinese, .description): "當選單列圖示被遮擋或不方便點擊時，可以用全域快速鍵開啟 CubePet 選單。"
        case (.traditionalChinese, .currentShortcut): "目前快速鍵"
        case (.traditionalChinese, .currentShortcutTooltip): "目前快速鍵：%@"
        case (.traditionalChinese, .recordShortcut): "點擊修改"
        case (.traditionalChinese, .pressNewShortcut): "請按下新的快速鍵"
        case (.traditionalChinese, .needsModifier): "請同時按下普通按鍵和 Control、Option、Command 或 Shift。"
        case (.traditionalChinese, .restoreDefault): "恢復預設"
        case (.traditionalChinese, .cancel): "取消"
        case (.traditionalChinese, .save): "儲存"
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

    func satietyGainText(_ amount: Int) -> String {
        switch language {
        case .english: "+\(amount) Satiety"
        case .japanese: "満腹度 +\(amount)"
        case .korean: "포만감 +\(amount)"
        case .simplifiedChinese: "+\(amount) 饱腹"
        case .traditionalChinese: "+\(amount) 飽腹"
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
        case (.english, .catBlack): "White-Tuft Black Cat"
        case (.english, .catSiamese): "Fluffy Siamese Cat"
        case (.english, .catYellow): "Huang Xiaohuang"
        case (.english, .shibaClassic): "Shiba Inu"
        case (.japanese, .classic): "黒ブロック"
        case (.japanese, .blue): "青ブロック"
        case (.japanese, .green): "緑ブロック"
        case (.japanese, .red): "赤ブロック"
        case (.japanese, .pink): "ピンクブロック"
        case (.japanese, .frogClassic): "クラシックカエル"
        case (.japanese, .catClassic): "クラシック猫"
        case (.japanese, .catGrayTabby): "食いしん坊猫"
        case (.japanese, .catCalico): "三毛猫"
        case (.japanese, .catBlack): "白い毛の黒猫"
        case (.japanese, .catSiamese): "ふわふわシャム猫"
        case (.japanese, .catYellow): "ホアン・シャオホアン"
        case (.japanese, .shibaClassic): "柴犬"
        case (.korean, .classic): "검은 블록"
        case (.korean, .blue): "파란 블록"
        case (.korean, .green): "초록 블록"
        case (.korean, .red): "빨간 블록"
        case (.korean, .pink): "분홍 블록"
        case (.korean, .frogClassic): "기본 개구리"
        case (.korean, .catClassic): "기본 고양이"
        case (.korean, .catGrayTabby): "먹보 고양이"
        case (.korean, .catCalico): "삼색 고양이"
        case (.korean, .catBlack): "흰점 검은 고양이"
        case (.korean, .catSiamese): "복슬복슬 샴고양이"
        case (.korean, .catYellow): "황샤오황"
        case (.korean, .shibaClassic): "시바견"
        case (.simplifiedChinese, .classic): "黑块"
        case (.simplifiedChinese, .blue): "蓝块"
        case (.simplifiedChinese, .green): "绿块"
        case (.simplifiedChinese, .red): "红块"
        case (.simplifiedChinese, .pink): "粉块"
        case (.simplifiedChinese, .frogClassic): "青蛙原色"
        case (.simplifiedChinese, .catClassic): "橘色虎斑猫"
        case (.simplifiedChinese, .catGrayTabby): "贪吃猫"
        case (.simplifiedChinese, .catCalico): "三花猫"
        case (.simplifiedChinese, .catBlack): "白额黑猫"
        case (.simplifiedChinese, .catSiamese): "蓬松暹罗猫"
        case (.simplifiedChinese, .catYellow): "黄小黄"
        case (.simplifiedChinese, .shibaClassic): "柴犬"
        case (.traditionalChinese, .classic): "黑塊"
        case (.traditionalChinese, .blue): "藍塊"
        case (.traditionalChinese, .green): "綠塊"
        case (.traditionalChinese, .red): "紅塊"
        case (.traditionalChinese, .pink): "粉塊"
        case (.traditionalChinese, .frogClassic): "青蛙原色"
        case (.traditionalChinese, .catClassic): "貓咪原色"
        case (.traditionalChinese, .catGrayTabby): "貪吃貓"
        case (.traditionalChinese, .catCalico): "三花貓"
        case (.traditionalChinese, .catBlack): "白額黑貓"
        case (.traditionalChinese, .catSiamese): "蓬鬆暹羅貓"
        case (.traditionalChinese, .catYellow): "黃小黃"
        case (.traditionalChinese, .shibaClassic): "柴犬"
        }
    }

    func petName(_ name: PetName) -> String {
        switch (language, name) {
        case (.english, .cube): "Cube"
        case (.english, .frog): "Frog"
        case (.english, .cat): "Cat"
        case (.english, .dog): "Dog"
        case (.japanese, .cube): "キューブ"
        case (.japanese, .frog): "カエル"
        case (.japanese, .cat): "猫"
        case (.japanese, .dog): "犬"
        case (.korean, .cube): "큐브"
        case (.korean, .frog): "개구리"
        case (.korean, .cat): "고양이"
        case (.korean, .dog): "강아지"
        case (.simplifiedChinese, .cube): "方块"
        case (.simplifiedChinese, .frog): "青蛙"
        case (.simplifiedChinese, .cat): "猫咪"
        case (.simplifiedChinese, .dog): "狗狗"
        case (.traditionalChinese, .cube): "方塊"
        case (.traditionalChinese, .frog): "青蛙"
        case (.traditionalChinese, .cat): "貓咪"
        case (.traditionalChinese, .dog): "狗狗"
        }
    }

    func launchAtLoginText(_ key: LaunchAtLoginText) -> String {
        switch (language, key) {
        case (.english, .title): "Launch at Login"
        case (.english, .approvalRequiredTitle): "Approve Launch at Login"
        case (.english, .approvalRequiredMessage): "Allow CubePet in System Settings to finish enabling launch at login."
        case (.english, .updateFailedTitle): "Could Not Update Launch at Login"
        case (.japanese, .title): "ログイン時に起動"
        case (.japanese, .approvalRequiredTitle): "ログイン時に起動を許可"
        case (.japanese, .approvalRequiredMessage): "ログイン時に起動を有効にするには、システム設定でCubePetを許可してください。"
        case (.japanese, .updateFailedTitle): "ログイン時に起動を更新できませんでした"
        case (.korean, .title): "로그인 시 실행"
        case (.korean, .approvalRequiredTitle): "로그인 시 실행 승인"
        case (.korean, .approvalRequiredMessage): "로그인 시 실행을 완료하려면 시스템 설정에서 CubePet을 허용하세요."
        case (.korean, .updateFailedTitle): "로그인 시 실행을 업데이트할 수 없음"
        case (.simplifiedChinese, .title): "登陆自启"
        case (.simplifiedChinese, .approvalRequiredTitle): "请允许开机登录自动启动"
        case (.simplifiedChinese, .approvalRequiredMessage): "请在系统设置中允许 CubePet，以完成开机登录自动启动。"
        case (.simplifiedChinese, .updateFailedTitle): "无法更新开机登录自动启动"
        case (.traditionalChinese, .title): "登入時自動啟動"
        case (.traditionalChinese, .approvalRequiredTitle): "請允許登入時自動啟動"
        case (.traditionalChinese, .approvalRequiredMessage): "請在系統設定中允許 CubePet，以完成登入時自動啟動。"
        case (.traditionalChinese, .updateFailedTitle): "無法更新登入時自動啟動"
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

    private func englishText(_ key: AppText) -> String {
        switch key {
        case .level: "Lv."
        case .shop: "Shop"
        case .food: "Food"
        case .satiety: "Satiety"
        case .skins: "Skins"
        case .pets: "Pets"
        case .owned: "Owned"
        case .activityMonitor: "Activity Monitor"
        case .changeSkin: "Change Skin"
        case .pet: "Change Pet"
        case .showSystemInfo: "Show System Info"
        case .aboutCubePet: "About CubePet"
        case .updateAvailable: "Update available"
        case .aboutDescription: "A casual desktop pet app currently in an early stage of development.\nDeveloped with assistance from GPT."
        case .version: "Version"
        case .download: "Download"
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
        case .petCustomization: "Pet Customization"
        case .petCustomizationLocked: "Pet Customization Is Locked"
        case .petCustomizationLockedMessage: "Unlock this feature to create custom pets, import state images, and arrange visual modules."
        case .shortcutSettings: "Shortcut Settings"
        case .menuAppearance: "Menu Appearance"
        case .menuStyleDefault: "Follow System"
        case .menuStyleLiquidGlass: "Liquid Glass"
        case .menuStyleDark: "Dark appearance"
        case .menuStyleLight: "Light appearance"
        }
    }

    private func japaneseText(_ key: AppText) -> String {
        switch key {
        case .level: "Lv."
        case .shop: "ショップ"
        case .food: "食べ物"
        case .satiety: "満腹度"
        case .skins: "スキン"
        case .pets: "ペット"
        case .owned: "購入済み"
        case .activityMonitor: "アクティビティモニタ"
        case .changeSkin: "スキンを変更"
        case .pet: "ペットを変更"
        case .showSystemInfo: "システム情報を表示"
        case .aboutCubePet: "CubePetについて"
        case .updateAvailable: "アップデートがあります"
        case .aboutDescription: "気軽に楽しめるデスクトップペットアプリです。現在は初期開発段階です。\n本ソフトウェアはGPTの支援を受けて開発されました。"
        case .version: "バージョン"
        case .download: "ダウンロード"
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
        case .petCustomization: "ペットのカスタマイズ"
        case .petCustomizationLocked: "ペットのカスタマイズはロックされています"
        case .petCustomizationLockedMessage: "ロックを解除すると、カスタムペットの作成、状態画像の読み込み、視覚モジュールの配置ができます。"
        case .shortcutSettings: "ショートカット設定"
        case .menuAppearance: "メニューの外観"
        case .menuStyleDefault: "システムに合わせる"
        case .menuStyleLiquidGlass: "リキッドグラス"
        case .menuStyleDark: "ダーク外観"
        case .menuStyleLight: "ライト外観"
        }
    }

    private func koreanText(_ key: AppText) -> String {
        switch key {
        case .level: "Lv."
        case .shop: "상점"
        case .food: "먹이"
        case .satiety: "포만감"
        case .skins: "스킨"
        case .pets: "펫"
        case .owned: "보유"
        case .activityMonitor: "활성 상태 보기"
        case .changeSkin: "스킨 변경"
        case .pet: "펫 변경"
        case .showSystemInfo: "시스템 정보 표시"
        case .aboutCubePet: "CubePet 정보"
        case .updateAvailable: "새 업데이트가 있습니다"
        case .aboutDescription: "가볍게 즐기는 데스크톱 펫 앱으로, 현재 초기 개발 단계입니다.\n이 소프트웨어는 GPT의 도움을 받아 개발되었습니다."
        case .version: "버전"
        case .download: "다운로드"
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
        case .petCustomization: "펫 커스터마이징"
        case .petCustomizationLocked: "펫 커스터마이징이 잠겨 있습니다"
        case .petCustomizationLockedMessage: "잠금을 해제하면 커스텀 펫을 만들고 상태 이미지를 가져오며 시각 모듈을 배치할 수 있습니다."
        case .shortcutSettings: "단축키 설정"
        case .menuAppearance: "메뉴 모양"
        case .menuStyleDefault: "시스템 설정 따르기"
        case .menuStyleLiquidGlass: "리퀴드 글래스"
        case .menuStyleDark: "다크 모드 모양"
        case .menuStyleLight: "라이트 모드 모양"
        }
    }

    private func simplifiedChineseText(_ key: AppText) -> String {
        switch key {
        case .level: "等级"
        case .shop: "商店"
        case .food: "食物"
        case .satiety: "饱腹值"
        case .skins: "皮肤"
        case .pets: "宠物"
        case .owned: "已拥有"
        case .activityMonitor: "活动监视器"
        case .changeSkin: "更换皮肤"
        case .pet: "更换宠物"
        case .showSystemInfo: "显示系统信息"
        case .aboutCubePet: "关于CubePet"
        case .updateAvailable: "发现新版本，点击更新"
        case .aboutDescription: "CubePet 是一只住在桌面上的小宠物，\n陪你工作、安静成长～\n偶尔也能帮你吃掉不需要的文件^_^"
        case .version: "版本"
        case .download: "下载地址"
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
        case .petCustomization: "宠物自定义"
        case .petCustomizationLocked: "宠物自定义尚未解锁"
        case .petCustomizationLockedMessage: "解锁后可以创建自定义宠物、导入状态图片并调整视觉模块。"
        case .shortcutSettings: "快捷键设置"
        case .menuAppearance: "菜单外观"
        case .menuStyleDefault: "跟随系统"
        case .menuStyleLiquidGlass: "液态玻璃"
        case .menuStyleDark: "黑夜模式"
        case .menuStyleLight: "白天模式"
        }
    }

    private func traditionalChineseText(_ key: AppText) -> String {
        switch key {
        case .level: "等級"
        case .shop: "商店"
        case .food: "食物"
        case .satiety: "飽腹值"
        case .skins: "皮膚"
        case .pets: "寵物"
        case .owned: "已擁有"
        case .activityMonitor: "活動監視器"
        case .changeSkin: "更換皮膚"
        case .pet: "更換寵物"
        case .showSystemInfo: "顯示系統資訊"
        case .aboutCubePet: "關於CubePet"
        case .updateAvailable: "發現新版本，點擊更新"
        case .aboutDescription: "這是一款休閒桌面寵物軟體，目前只是初步開發階段。\n本軟體由GPT協助開發"
        case .version: "版本"
        case .download: "下載連結"
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
        case .petCustomization: "寵物自訂"
        case .petCustomizationLocked: "寵物自訂尚未解鎖"
        case .petCustomizationLockedMessage: "解鎖後可以建立自訂寵物、匯入狀態圖片並調整視覺模組。"
        case .shortcutSettings: "快速鍵設定"
        case .menuAppearance: "選單外觀"
        case .menuStyleDefault: "跟隨系統"
        case .menuStyleLiquidGlass: "液態玻璃"
        case .menuStyleDark: "夜間模式"
        case .menuStyleLight: "日間模式"
        }
    }
}
