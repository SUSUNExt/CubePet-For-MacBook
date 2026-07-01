import AppKit
import SwiftUI

struct AboutCubePetView: View {
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

            Text(languageSettings.appStoreAvailabilityTitle())
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 3)

            Divider()
                .padding(.top, 14)

            Text(languageSettings.text(.aboutDescription))
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)

            Spacer(minLength: 4)
        }
        .padding(.top, 26)
        .frame(width: 400, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
