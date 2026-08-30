import SwiftUI

/// About, Fair Use & Intellectual Property view
struct AboutView: View {
    @EnvironmentObject var appState: AppState

    private let appVersion = "1.0.4"
    private let githubURL = URL(string: "https://github.com/neel0210/MCons")!
    private let telegramChannelURL = URL(string: "https://t.me/MConsOfficial")!
    private let telegramSupportURL = URL(string: "https://t.me/MConsupport")!

    @StateObject private var updateService = UpdateService.shared

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
        .background(AppTheme.Colors.background)
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(nsImage: .appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("MCons")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.primary)

                Text("Icons for MacOS")
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(AppTheme.Colors.accentGradient)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Text("Version \(updateService.currentFullVersion)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    
                    if case .updateAvailable = updateService.status {
                        Button {
                            appState.selectedSidebarItem = .updates
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Update Available")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.accentGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
    }

    // MARK: - Links Section

    private var linksSection: some View {
        aboutSection(title: "Links", icon: "link") {
            VStack(spacing: AppTheme.Spacing.md) {
                customLinkRow(
                    title: "GitHub Repository",
                    subtitle: "github.com/neel0210/MCons",
                    url: githubURL
                ) {
                    GitHubLogo(size: 26)
                }

                Divider()

                customLinkRow(
                    title: "Telegram Channel",
                    subtitle: "@MConsOfficial — Updates & releases",
                    url: telegramChannelURL
                ) {
                    TelegramLogo(size: 26)
                }

                Divider()

                customLinkRow(
                    title: "Telegram Support",
                    subtitle: "@MConsupport — Help & feedback",
                    url: telegramSupportURL
                ) {
                    TelegramGroupLogo(size: 26)
                }
            }
        }
    }

    private func customLinkRow<Logo: View>(
        title: String,
        subtitle: String,
        url: URL,
        @ViewBuilder logo: () -> Logo
    ) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                logo()
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

                ipRow(packId: "pokemon", iconName: "Pikachu", franchise: "Pokémon", holder: "© Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company")
                ipRow(packId: "attack-on-titan", iconName: "Attack Titan", franchise: "Attack on Titan (Shingeki no Kyojin)", holder: "© Hajime Isayama / Kodansha / \"ATTACK ON TITAN\" Production Committee / MAPPA / WIT Studio")
                ipRow(packId: "demon-slayer", iconName: "Tanjiro", franchise: "Demon Slayer (Kimetsu no Yaiba)", holder: "© Koyoharu Gotouge / SHUEISHA / Aniplex / ufotable")
                ipRow(packId: "one-piece", iconName: "Luffy", franchise: "One Piece", holder: "© Eiichiro Oda / SHUEISHA / Toei Animation")
                ipRow(packId: "naruto", iconName: "Naruto Uzumaki", franchise: "Naruto (Naruto Shippūden)", holder: "© Masashi Kishimoto / SHUEISHA / TV TOKYO / Pierrot")
                ipRow(packId: "solo-leveling", iconName: "Sung Jinwoo", franchise: "Solo Leveling", holder: "Story by Chugong, Art by DUBU (REDICE STUDIO), © D&C Media / KakaoPage / A-1 Pictures")
                ipRow(packId: "google", iconName: "Google Chrome", franchise: "Google & Alphabet", holder: "© Google LLC / Alphabet Inc. Google, Chrome, Drive, Gmail, Maps, Photos, Files, Keep, Camera, YouTube and related marks are trademarks of Google LLC.")
                ipRow(systemIcon: "apple.logo", franchise: "Apple & macOS", holder: "macOS, SF Symbols, Finder, and Dock are trademarks of Apple Inc.")
            }
        }
    }

    private func ipRow(
        packId: String? = nil,
        iconName: String? = nil,
        systemIcon: String? = nil,
        franchise: String,
        holder: String
    ) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            // Icon thumbnail SVG
            Group {
                if let packId = packId,
                   let pack = appState.cachedIconPacks.first(where: { $0.id.localizedCaseInsensitiveContains(packId) }),
                   let icon = (iconName != nil ? pack.icons.first(where: { $0.name.localizedCaseInsensitiveContains(iconName!) }) : nil) ?? pack.icons.first {
                    Image(nsImage: icon.thumbnailImage(size: 64))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let systemIcon = systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accentGradient)
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(franchise)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(.primary)

                Text(holder)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        aboutSection(title: "Developer", icon: "person.fill") {
            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/neel0210")!)
            } label: {
                HStack(spacing: AppTheme.Spacing.md) {
                    AsyncImage(url: URL(string: "https://github.com/neel0210.png")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(AppTheme.Colors.accentGradient)
                        } else {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.border, lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Text("Neel0210")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(.primary)
                            
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text("Creator & Maintainer • Made with ❤️ while vibe coding")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverScale(1.01)
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
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Brand Vector Logos

struct GitHubShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        
        path.move(to: CGPoint(x: 12 * sx, y: 1.5 * sy))
        path.addCurve(to: CGPoint(x: 1.5 * sx, y: 12.18 * sy), control1: CGPoint(x: 6.2 * sx, y: 1.5 * sy), control2: CGPoint(x: 1.5 * sx, y: 6.28 * sy))
        path.addCurve(to: CGPoint(x: 8.68 * sx, y: 22.18 * sy), control1: CGPoint(x: 1.5 * sx, y: 16.91 * sy), control2: CGPoint(x: 4.54 * sx, y: 20.91 * sy))
        path.addCurve(to: CGPoint(x: 9.21 * sx, y: 21.66 * sy), control1: CGPoint(x: 9.04 * sx, y: 22.25 * sy), control2: CGPoint(x: 9.21 * sx, y: 21.99 * sy))
        path.addLine(to: CGPoint(x: 9.2 * sx, y: 19.82 * sy))
        path.addCurve(to: CGPoint(x: 5.68 * sx, y: 18.36 * sy), control1: CGPoint(x: 6.23 * sx, y: 20.48 * sy), control2: CGPoint(x: 5.68 * sx, y: 18.36 * sy))
        path.addCurve(to: CGPoint(x: 4.45 * sx, y: 16.78 * sy), control1: CGPoint(x: 5.18 * sx, y: 17.1 * sy), control2: CGPoint(x: 4.45 * sx, y: 16.78 * sy))
        path.addCurve(to: CGPoint(x: 5.46 * sx, y: 16.71 * sy), control1: CGPoint(x: 3.47 * sx, y: 16.1 * sy), control2: CGPoint(x: 5.46 * sx, y: 16.71 * sy))
        path.addCurve(to: CGPoint(x: 7.12 * sx, y: 18.36 * sy), control1: CGPoint(x: 6.55 * sx, y: 17.51 * sy), control2: CGPoint(x: 7.12 * sx, y: 18.36 * sy))
        path.addCurve(to: CGPoint(x: 10.32 * sx, y: 17.44 * sy), control1: CGPoint(x: 8.09 * sx, y: 20.03 * sy), control2: CGPoint(x: 9.68 * sx, y: 19.5 * sy))
        path.addCurve(to: CGPoint(x: 11.02 * sx, y: 15.98 * sy), control1: CGPoint(x: 10.42 * sx, y: 16.74 * sy), control2: CGPoint(x: 10.7 * sx, y: 16.26 * sy))
        path.addCurve(to: CGPoint(x: 6.13 * sx, y: 10.6 * sy), control1: CGPoint(x: 8.57 * sx, y: 15.7 * sy), control2: CGPoint(x: 6.13 * sx, y: 14.75 * sy))
        path.addCurve(to: CGPoint(x: 7.28 * sx, y: 7.64 * sy), control1: CGPoint(x: 6.13 * sx, y: 9.4 * sy), control2: CGPoint(x: 6.56 * sx, y: 8.42 * sy))
        path.addCurve(to: CGPoint(x: 7.39 * sx, y: 4.74 * sy), control1: CGPoint(x: 7.17 * sx, y: 7.36 * sy), control2: CGPoint(x: 6.81 * sx, y: 6.24 * sy))
        path.addCurve(to: CGPoint(x: 10.37 * sx, y: 5.86 * sy), control1: CGPoint(x: 8.31 * sx, y: 4.45 * sy), control2: CGPoint(x: 10.37 * sx, y: 5.86 * sy))
        path.addCurve(to: CGPoint(x: 12 * sx, y: 5.64 * sy), control1: CGPoint(x: 10.89 * sx, y: 5.72 * sy), control2: CGPoint(x: 11.45 * sx, y: 5.64 * sy))
        path.addCurve(to: CGPoint(x: 13.63 * sx, y: 5.86 * sy), control1: CGPoint(x: 12.55 * sx, y: 5.64 * sy), control2: CGPoint(x: 13.11 * sx, y: 5.72 * sy))
        path.addCurve(to: CGPoint(x: 16.61 * sx, y: 4.74 * sy), control1: CGPoint(x: 13.63 * sx, y: 5.86 * sy), control2: CGPoint(x: 15.69 * sx, y: 4.45 * sy))
        path.addCurve(to: CGPoint(x: 16.72 * sx, y: 7.64 * sy), control1: CGPoint(x: 17.19 * sx, y: 6.24 * sy), control2: CGPoint(x: 16.83 * sx, y: 7.36 * sy))
        path.addCurve(to: CGPoint(x: 17.87 * sx, y: 10.6 * sy), control1: CGPoint(x: 17.44 * sx, y: 8.42 * sy), control2: CGPoint(x: 17.87 * sx, y: 9.4 * sy))
        path.addCurve(to: CGPoint(x: 12.96 * sx, y: 15.99 * sy), control1: CGPoint(x: 17.87 * sx, y: 14.76 * sy), control2: CGPoint(x: 15.42 * sx, y: 15.71 * sy))
        path.addCurve(to: CGPoint(x: 13.72 * sx, y: 18.04 * sy), control1: CGPoint(x: 13.36 * sx, y: 16.37 * sy), control2: CGPoint(x: 13.72 * sx, y: 17.06 * sy))
        path.addLine(to: CGPoint(x: 13.72 * sx, y: 21.66 * sy))
        path.addCurve(to: CGPoint(x: 14.26 * sx, y: 22.18 * sy), control1: CGPoint(x: 13.72 * sx, y: 22 * sy), control2: CGPoint(x: 13.9 * sx, y: 22.25 * sy))
        path.addCurve(to: CGPoint(x: 22.5 * sx, y: 12.18 * sy), control1: CGPoint(x: 18.42 * sx, y: 20.89 * sy), control2: CGPoint(x: 22.5 * sx, y: 16.89 * sy))
        path.addCurve(to: CGPoint(x: 12 * sx, y: 1.5 * sy), control1: CGPoint(x: 22.5 * sx, y: 6.28 * sy), control2: CGPoint(x: 17.8 * sx, y: 1.5 * sy))
        path.closeSubpath()
        
        return path
    }
}

struct GitHubLogo: View {
    var size: CGFloat = 26
    
    var body: some View {
        GitHubShape()
            .fill(.primary)
            .frame(width: size, height: size)
    }
}

struct TelegramPaperPlaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        
        path.move(to: CGPoint(x: 17.8 * sx, y: 6.6 * sy))
        path.addLine(to: CGPoint(x: 4.8 * sx, y: 11.6 * sy))
        path.addCurve(to: CGPoint(x: 4.9 * sx, y: 12.6 * sy), control1: CGPoint(x: 4.1 * sx, y: 11.9 * sy), control2: CGPoint(x: 4.2 * sx, y: 12.5 * sy))
        path.addLine(to: CGPoint(x: 8.2 * sx, y: 13.7 * sy))
        path.addLine(to: CGPoint(x: 15.6 * sx, y: 9.1 * sy))
        path.addCurve(to: CGPoint(x: 15.2 * sx, y: 9.8 * sy), control1: CGPoint(x: 16.0 * sx, y: 8.8 * sy), control2: CGPoint(x: 15.6 * sx, y: 9.4 * sy))
        path.addLine(to: CGPoint(x: 9.6 * sx, y: 14.8 * sy))
        path.addLine(to: CGPoint(x: 9.2 * sx, y: 18.2 * sy))
        path.addCurve(to: CGPoint(x: 10.4 * sx, y: 17.8 * sy), control1: CGPoint(x: 9.5 * sx, y: 18.5 * sy), control2: CGPoint(x: 10.1 * sx, y: 18.2 * sy))
        path.addLine(to: CGPoint(x: 12.4 * sx, y: 15.9 * sy))
        path.addLine(to: CGPoint(x: 16.2 * sx, y: 18.7 * sy))
        path.addCurve(to: CGPoint(x: 17.2 * sx, y: 18.2 * sy), control1: CGPoint(x: 16.8 * sx, y: 19.1 * sy), control2: CGPoint(x: 17.1 * sx, y: 18.7 * sy))
        path.addLine(to: CGPoint(x: 19.2 * sx, y: 7.7 * sy))
        path.addCurve(to: CGPoint(x: 17.8 * sx, y: 6.6 * sy), control1: CGPoint(x: 19.5 * sx, y: 6.6 * sy), control2: CGPoint(x: 18.8 * sx, y: 6.2 * sy))
        path.closeSubpath()
        
        return path
    }
}

struct TelegramLogo: View {
    var size: CGFloat = 26
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#2AABEE"), Color(hex: "#229ED9")],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            
            TelegramPaperPlaneShape()
                .fill(.white)
                .padding(size * 0.12)
        }
        .frame(width: size, height: size)
    }
}

struct TelegramGroupLogo: View {
    var size: CGFloat = 26
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#00B894"), Color(hex: "#00A381")],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: size * 0.46))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
