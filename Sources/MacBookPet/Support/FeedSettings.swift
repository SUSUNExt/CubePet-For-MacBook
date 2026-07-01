import Foundation

enum FeedDestination: String {
    case trash
    case folder
    case airDrop
}

final class FeedSettings {
    private enum Key {
        static let destination = "MacBookPet.feedDestination"
        static let folderPath = "MacBookPet.feedFolderPath"
    }

    var destination: FeedDestination {
        get {
            let rawValue = UserDefaults.standard.string(forKey: Key.destination) ?? FeedDestination.trash.rawValue
            return FeedDestination(rawValue: rawValue) ?? .trash
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Key.destination)
        }
    }

    var folderURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: Key.folderPath), !path.isEmpty else {
                return nil
            }

            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: Key.folderPath)
        }
    }
}
