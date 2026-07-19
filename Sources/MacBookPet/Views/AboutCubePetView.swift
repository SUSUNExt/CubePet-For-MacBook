import AppKit
import SwiftUI

struct AboutCubePetView: View {
    private static let downloadURL = URL(string: "https://github.com/SUSUNExt/CubePet")!

    @ObservedObject var languageSettings: LanguageSettings
    let appIcon: NSImage

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)

            Text("CubePet")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 14)

            Text(languageSettings.editionTitle())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Divider()
                .padding(.top, 14)

            Text(languageSettings.text(.aboutDescription))
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)

            Spacer(minLength: 8)

            Text(versionText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Link(destination: Self.downloadURL) {
                Label(languageSettings.text(.download), systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .padding(.top, 26)
        .frame(width: 400, height: 410)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.8"
        return "\(languageSettings.text(.version)) \(version)"
    }
}
