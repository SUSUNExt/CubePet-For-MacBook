import Foundation

@MainActor
final class AppUpdateAvailability: ObservableObject {
    static let downloadURL = URL(string: "https://github.com/SUSUNExt/CubePet/releases/latest")!
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/SUSUNExt/CubePet/releases/latest"
    )!
    private static let dailyCheckInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var isUpdateAvailable = false

    private let currentVersion: String
    private var dailyCheckTimer: Timer?

    init(currentVersion: String? = nil) {
        self.currentVersion = currentVersion
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0.9.8"
    }

    func startCheckingForUpdates() {
        checkForUpdate()
        startDailyChecks()
    }

    func checkForUpdate() {
        Task { [weak self] in
            guard let self else { return }

            do {
                var request = URLRequest(url: Self.latestReleaseURL, timeoutInterval: 10)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("CubePet/\(currentVersion)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    isUpdateAvailable = false
                    return
                }

                let release = try JSONDecoder().decode(LatestRelease.self, from: data)
                isUpdateAvailable = Self.isNewerRelease(
                    tagName: release.tagName,
                    than: currentVersion
                )
            } catch {
                isUpdateAvailable = false
            }
        }
    }

    private func startDailyChecks() {
        guard dailyCheckTimer == nil else { return }

        dailyCheckTimer = Timer.scheduledTimer(
            withTimeInterval: Self.dailyCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForUpdate()
            }
        }
    }

    static func isNewerRelease(tagName: String, than currentVersion: String) -> Bool {
        guard let latest = AppVersion(tagName), let current = AppVersion(currentVersion) else {
            return false
        }
        return latest > current
    }
}

private struct LatestRelease: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}

private struct AppVersion: Comparable {
    private let components: [Int]

    init?(_ rawValue: String) {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionWithoutPrefix = trimmedValue.hasPrefix("v")
            ? String(trimmedValue.dropFirst())
            : trimmedValue
        let stableVersion = versionWithoutPrefix.split(separator: "-", maxSplits: 1).first ?? ""
        let components = stableVersion.split(separator: ".").compactMap { Int($0) }

        guard !components.isEmpty,
              components.count == stableVersion.split(separator: ".").count else {
            return nil
        }
        self.components = components
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let length = max(lhs.components.count, rhs.components.count)
        for index in 0..<length {
            let left = lhs.components.indices.contains(index) ? lhs.components[index] : 0
            let right = rhs.components.indices.contains(index) ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
