import SwiftUI

/// About, Fair Use & Intellectual Property view
struct AboutView: View {
    @EnvironmentObject var appState: AppState

    private let appVersion = "1.0.1"
    private let githubURL = URL(string: "https://github.com/neel0210/MCons")!
    private let telegramChannelURL = URL(string: "https://t.me/MConsOfficial")!
    private let telegramSupportURL = URL(string: "https://t.me/MConsupport")!

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                // App Identity
                appHeader
                    .fadeInUp()

                // Links
                linksSection
                    .fadeInUp(delay: 0.1)

                // Fair Use Statement
                fairUseSection
                    .fadeInUp(delay: 0.2)

                // IP Credits
                ipCreditsSection
                    .fadeInUp(delay: 0.3)

                // Developer
                developerSection
                    .fadeInUp(delay: 0.4)

                Spacer(minLength: AppTheme.Spacing.xxl)
            }
            .padding(AppTheme.Spacing.xxl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "folder.fill.badge.gearshape")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(AppTheme.Colors.accentGradient)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("MCons")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.primary)

                Text("Icons for MacOS")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.accentGradient)

                Text("Version \(appVersion)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
    }

    // MARK: - Links Section

    private var linksSection: some View {
        aboutSection(title: "Links", icon: "link") {
            VStack(spacing: AppTheme.Spacing.md) {
                linkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub Repository",
                    subtitle: "github.com/neel0210/MCons",
                    color: "#6C5CE7",
                    url: githubURL
                )

                Divider()

                linkRow(
                    icon: "megaphone.fill",
                    title: "Telegram Channel",
                    subtitle: "@MConsOfficial — Updates & releases",
                    color: "#0088CC",
                    url: telegramChannelURL
                )

                Divider()

                linkRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Telegram Support",
                    subtitle: "@MConsupport — Help & feedback",
                    color: "#00B894",
                    url: telegramSupportURL
                )
            }
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String, color: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverScale(1.01)
    }

    // MARK: - Fair Use Section

    private var fairUseSection: some View {
        aboutSection(title: "Fair Use Notice", icon: "scalemass.fill") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Notice banner
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#6C5CE7"))

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("MCons is a free, non-profit, open-source personal customization utility provided for personal desktop aesthetics, non-commercial commentary, fan tribute, and organizational use.")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(Color(hex: "#6C5CE7").opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .stroke(Color(hex: "#6C5CE7").opacity(0.2), lineWidth: 1)
                )

                // Legal text
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Title 17 U.S.C. Section 107 (Fair Use Doctrine)")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(.primary)

                    fairUsePoint("The software is distributed free of charge with zero monetization, advertising, or commercial intent.")
                    fairUsePoint("Icons and vector assets are included for transformative desktop interface customization by individual end-users.")
                    fairUsePoint("No copyright or trademark infringement is intended.")
                    fairUsePoint("If you are a copyright holder and wish to have specific material removed, please contact the developer or open an issue on GitHub.")
                }
            }
        }
    }

    private func fairUsePoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Text("•")
                .font(AppTheme.Typography.body)
                .foregroundStyle(.secondary)
            Text(text)
                .font(AppTheme.Typography.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - IP Credits Section

    private var ipCreditsSection: some View {
        aboutSection(title: "Intellectual Property", icon: "shield.lefthalf.filled") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("All character designs, vector artwork, logos, and trademarks remain the intellectual property and copyright of their respective owners:")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)

                Divider()

                ipRow(emoji: "⚡", franchise: "Pokémon", holder: "© Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company")
                ipRow(emoji: "⚔️", franchise: "Attack on Titan (Shingeki no Kyojin)", holder: "© Hajime Isayama / Kodansha / \"ATTACK ON TITAN\" Production Committee / MAPPA / WIT Studio")
                ipRow(emoji: "⚔️", franchise: "Demon Slayer (Kimetsu no Yaiba)", holder: "© Koyoharu Gotouge / SHUEISHA / Aniplex / ufotable")
                ipRow(emoji: "🏴\u{200D}☠️", franchise: "One Piece", holder: "© Eiichiro Oda / SHUEISHA / Toei Animation")
                ipRow(emoji: "🗡️", franchise: "Solo Leveling", holder: "Story by Chugong, Art by DUBU (REDICE STUDIO), © D&C Media / KakaoPage / A-1 Pictures")
                ipRow(emoji: "🍎", franchise: "Apple & macOS", holder: "macOS, SF Symbols, Finder, and Dock are trademarks of Apple Inc.")
            }
        }
    }

    private func ipRow(emoji: String, franchise: String, holder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text(emoji)
                    .font(.body)
                Text(franchise)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)
            }

            Text(holder)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        aboutSection(title: "Developer", icon: "person.fill") {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.Colors.accentGradient)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                            .fill(Color(hex: "#6C5CE7").opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Neel0210")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.primary)

                    Text("Made with ❤️ while vibe coding")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Section Builder

    private func aboutSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.primary)

            content()
                .padding(AppTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
        }
    }
}
