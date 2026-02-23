import SwiftUI

struct EarningsView: View {
    @Environment(GamesViewModel.self) private var gamesVM
    @State private var appeared = false
    @State private var ringProgress: Double = 0
    @State private var glowPulse = false
    @State private var borderRotation: Double = 0
    @State private var ringFilled = false

    var body: some View {
        ZStack {
            earningsBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                        .staggerIn(appeared: appeared, delay: 0)

                    if let earnings = gamesVM.earnings {
                        heroCard(earnings)
                            .staggerIn(appeared: appeared, delay: 0.06)

                        if !gamesVM.earningsChart.isEmpty {
                            chartSection
                                .staggerIn(appeared: appeared, delay: 0.10)
                        }

                        winRateSection(earnings)
                            .staggerIn(appeared: appeared, delay: 0.14)

                        statsGrid(earnings)
                            .staggerIn(appeared: appeared, delay: 0.20)

                        rankSection(earnings)
                            .staggerIn(appeared: appeared, delay: 0.26)

                        if !gamesVM.earningsHistory.isEmpty {
                            historySection
                                .staggerIn(appeared: appeared, delay: 0.30)
                        }
                    } else if gamesVM.isLoadingEarnings {
                        loadingState
                    } else {
                        emptyState
                    }

                    Spacer(minLength: 120)
                }
            }
            .refreshable { await gamesVM.loadEarnings() }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: ringFilled)
        .onAppear { handleAppear() }
        .onChange(of: gamesVM.earnings?.winRate) { _, newWR in
            if let wr = newWR {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.3)) {
                    ringProgress = wr / 100.0
                }
            }
        }
    }

    private func handleAppear() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowPulse = true }
        withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) { borderRotation = 360 }
        if let wr = gamesVM.earnings?.winRate {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.4)) {
                ringProgress = wr / 100.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { ringFilled = true }
        }
    }

    // MARK: - Background

    private var earningsBackground: some View {
        ZStack {
            Color.lavBackground.ignoresSafeArea()

            Circle()
                .fill(RadialGradient(
                    colors: [Color.lavPurple.opacity(glowPulse ? 0.1 : 0.03), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .offset(x: 120, y: -100)
                .blur(radius: 80)

            Circle()
                .fill(RadialGradient(
                    colors: [Color.lavEmerald.opacity(glowPulse ? 0.06 : 0.02), .clear],
                    center: .center, startRadius: 0, endRadius: 160
                ))
                .frame(width: 320, height: 320)
                .offset(x: -100, y: 350)
                .blur(radius: 60)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Results")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                Text("Earnings & match history")
                    .font(.system(size: 13))
                    .foregroundColor(.lavTextSecondary)
            }
            Spacer()
            tierBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var tierBadge: some View {
        let tier = gamesVM.earnings?.tier?.capitalized ?? "Bronze"
        let color = tierColor(for: tier)

        return HStack(spacing: 5) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 12))
            Text(tier.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1.5)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
        .shadow(color: color.opacity(glowPulse ? 0.4 : 0.1), radius: 8)
    }

    private func tierColor(for tier: String) -> Color {
        switch tier.lowercased() {
        case "gold": return .lavYellow
        case "silver": return .lavTextSecondary
        case "platinum": return .lavCyan
        case "diamond": return .lavPurple
        default: return .lavOrange
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ e: EarningsStats) -> some View {
        let total = e.totalEarnings ?? 0
        let accent: Color = total >= 0 ? .lavEmerald : .lavRed

        return VStack(spacing: 18) {
            Text("TOTAL EARNINGS")
                .font(.system(size: 10, weight: .black))
                .tracking(3)
                .foregroundColor(.lavTextMuted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.3f", total))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(accent)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: total))
                Text("SOL")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.lavTextMuted)
            }

            heroSubStats(e)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(heroBackground(accent: accent))
        .padding(.horizontal, 20)
    }

    private func heroSubStats(_ e: EarningsStats) -> some View {
        HStack(spacing: 0) {
            earningsPill(label: "TODAY", value: e.todayEarnings ?? 0)
            Spacer()
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 32)
            Spacer()
            earningsPill(label: "THIS WEEK", value: e.weekEarnings ?? 0)
        }
        .padding(.horizontal, 4)
    }

    private func heroBackground(accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.lavSurface)
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.04), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            gradientBorder(cornerRadius: 22)
        }
        .shadow(color: accent.opacity(glowPulse ? 0.15 : 0.05), radius: 24, y: 6)
    }

    private func gradientBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(.clear, lineWidth: 0)
            .overlay(
                Circle()
                    .fill(AngularGradient(
                        colors: [.lavEmerald, .lavCyan, .lavPurple, .lavEmerald.opacity(0.2)],
                        center: .center
                    ))
                    .scaleEffect(2)
                    .rotationEffect(.degrees(borderRotation))
            )
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(lineWidth: 1.5)
            )
    }

    private func earningsPill(label: String, value: Double) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(.lavTextMuted)
            HStack(spacing: 3) {
                Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%.3f", value))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(value >= 0 ? .lavEmerald : .lavRed)
        }
    }

    // MARK: - Win Rate

    private func winRateSection(_ e: EarningsStats) -> some View {
        HStack(spacing: 20) {
            winRateRing(e)
            winLossRecords(e)
            Spacer()
        }
        .padding(20)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func winRateRing(_ e: EarningsStats) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 8)
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [.lavEmerald, .lavCyan, .lavEmerald],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .shadow(color: .lavEmerald.opacity(0.5), radius: 8)

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", e.winRate ?? 0))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("WIN RATE")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.lavTextMuted)
            }
        }
    }

    private func winLossRecords(_ e: EarningsStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            recordRow(label: "Wins", value: "\(e.wins ?? 0)", color: .lavEmerald, icon: "checkmark.circle.fill")
            recordRow(label: "Losses", value: "\(e.losses ?? 0)", color: .lavRed, icon: "xmark.circle.fill")
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            recordRow(label: "Total", value: "\(e.totalGames ?? 0)", color: .lavCyan, icon: "number.circle.fill")
        }
    }

    private func recordRow(label: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.4), radius: 3)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.lavTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Stats Grid

    private func statsGrid(_ e: EarningsStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ], spacing: 10) {
            statTile(icon: "flame.fill", label: "Best Streak", value: "\(e.bestStreak ?? 0)", color: .lavOrange)
            statTile(icon: "bolt.fill", label: "Current", value: "\(e.currentStreak ?? 0)", color: streakColor(e.currentStreak ?? 0))
            statTile(icon: "trophy.fill", label: "Biggest Win", value: String(format: "%.3f SOL", e.biggestWin ?? 0), color: .lavYellow)
            statTile(icon: "gamecontroller.fill", label: "Games", value: "\(e.totalGames ?? 0)", color: .lavPurple)
        }
        .padding(.horizontal, 20)
    }

    private func streakColor(_ streak: Int) -> Color {
        streak > 0 ? .lavEmerald : streak < 0 ? .lavRed : .lavTextMuted
    }

    private func statTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.lavTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .premiumCard(cornerRadius: 18)
    }

    // MARK: - Rank

    private func rankSection(_ e: EarningsStats) -> some View {
        HStack(spacing: 0) {
            rankPill(icon: "number", label: "Rank", value: e.rank != nil ? "#\(e.rank!)" : "--", color: .lavYellow)
            Spacer()
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 36)
            Spacer()
            rankPill(icon: "chart.line.uptrend.xyaxis", label: "Percentile", value: String(format: "Top %.0f%%", e.percentile ?? 0), color: .lavCyan)
        }
        .padding(20)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func rankPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 4)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.lavTextMuted)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.lavEmerald)
                .scaleEffect(1.1)
            Text("Loading stats...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.lavTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - 7-Day Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LAST 7 DAYS")
                .font(.system(size: 10, weight: .black))
                .tracking(2)
                .foregroundColor(.lavTextMuted)
                .padding(.horizontal, 4)

            let data = gamesVM.earningsChart.suffix(7)
            let maxVal = data.map { abs($0.earnings) }.max() ?? 1
            let barScale = maxVal > 0 ? maxVal : 1

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data), id: \.id) { day in
                    VStack(spacing: 6) {
                        let isPositive = day.earnings >= 0
                        let barHeight = max(CGFloat(abs(day.earnings) / barScale) * 80, 4)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: isPositive
                                        ? [.lavEmerald, .lavEmerald.opacity(0.6)]
                                        : [.lavRed, .lavRed.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: barHeight)
                            .shadow(color: (isPositive ? Color.lavEmerald : Color.lavRed).opacity(0.3), radius: 4)

                        Text(shortDayLabel(day.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.lavTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .padding(20)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func shortDayLabel(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else {
            return String(dateStr.suffix(2))
        }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date).uppercased()
    }

    // MARK: - Game History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT GAMES")
                .font(.system(size: 10, weight: .black))
                .tracking(2)
                .foregroundColor(.lavTextMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(gamesVM.earningsHistory.prefix(20)) { game in
                    historyRow(game)
                }
            }
        }
        .padding(20)
        .premiumCard(cornerRadius: 22)
        .padding(.horizontal, 20)
    }

    private func historyRow(_ game: EarningsGame) -> some View {
        let isWin = game.result == "win"
        let amount = game.amount ?? 0

        return HStack(spacing: 12) {
            // Game type icon
            Circle()
                .fill((isWin ? Color.lavEmerald : Color.lavRed).opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: isWin ? "checkmark" : "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isWin ? .lavEmerald : .lavRed)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(gameDisplayName(game.gameType ?? ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(relativeTime(game.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.lavTextMuted)
            }

            Spacer()

            Text(String(format: "%@%.4f", amount >= 0 ? "+" : "", amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(amount >= 0 ? .lavEmerald : .lavRed)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func gameDisplayName(_ type: String) -> String {
        switch type {
        case "drivehard": return "Drive Hard"
        case "solsnake": return "SolSnake"
        case "rocketsol": return "Rocket Sol"
        case "warp": return "Warp"
        case "dropfusion": return "Drop Fusion"
        case "bountyboard": return "Bounty Board"
        default: return type.capitalized
        }
    }

    private func relativeTime(_ dateStr: String?) -> String {
        guard let dateStr else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.lavCyan.opacity(0.06))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.lavCyan.opacity(0.4), .lavPurple.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            VStack(spacing: 6) {
                Text("No earnings data yet")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Play some games to see your stats here")
                    .font(.system(size: 13))
                    .foregroundColor(.lavTextMuted)
            }
        }
        .padding(.top, 60)
    }
}
