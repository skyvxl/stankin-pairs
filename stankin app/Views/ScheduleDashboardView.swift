import SwiftUI

struct ScheduleDashboardView: View {
    let store: ScheduleStore
    let calendar: Calendar

    @Binding var selectedDate: Date

    @State private var scrolledOffset: Int?

    private let today: Date = ScheduleCalendar.russian.startOfDay(for: Date())
    private let pagerRadius: Int = ScheduleCalendar.pagerRadius

    // MARK: - Helpers

    private func pagerDate(at offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func pagerOffset(for date: Date) -> Int {
        let days = calendar.dateComponents(
            [.day], from: today, to: calendar.startOfDay(for: date)
        ).day ?? 0
        return max(-pagerRadius, min(pagerRadius, days))
    }

    private var isOnToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScheduleWeekStripBar(
                calendar: calendar,
                selectedDate: $selectedDate
            )

            ZStack(alignment: .bottom) {
                dayPager

                if !isOnToday {
                    HStack {
                        Spacer()
                        backToTodayButton
                        Spacer()
                    }
                    .padding(.bottom, 10)
                    .transition(
                        .scale(scale: 0.85, anchor: .bottom)
                        .combined(with: .opacity)
                    )
                }
            }
            .animation(
                .spring(duration: 0.35, bounce: 0.2),
                value: isOnToday
            )
        }
        .onAppear {
            scrolledOffset = pagerOffset(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            let offset = pagerOffset(for: newValue)
            guard scrolledOffset != offset else { return }
            withAnimation(.snappy(duration: 0.22)) {
                scrolledOffset = offset
            }
        }
        .onChange(of: scrolledOffset) { _, offset in
            guard let offset else { return }
            let newDate = pagerDate(at: offset)
            guard !calendar.isDate(newDate, inSameDayAs: selectedDate) else { return }
            selectedDate = newDate
        }
    }
}

// MARK: - Subviews

private extension ScheduleDashboardView {

    var dayPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(-pagerRadius...pagerRadius, id: \.self) { offset in
                    let date = pagerDate(at: offset)
                    ScheduleDayPage(
                        date: date,
                        entries: store.entries(for: date),
                        calendar: calendar,
                        extraBottomPadding: !isOnToday
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledOffset)
        .scrollIndicators(.hidden)
    }

    var backToTodayButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                selectedDate = today
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("Сегодня")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Onboarding

struct ScheduleOnboardingView: View {
    let chooseGroup: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Нет расписания")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Выберите группу, и приложение сразу покажет пары по дням.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: chooseGroup) {
                Text("Выбрать группу")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Week Strip

private struct ScheduleWeekStripBar: View {
    let calendar: Calendar

    @Binding var selectedDate: Date

    private var weekDates: [Date] {
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: selectedDate
        )
        guard let weekStart = calendar.date(from: components) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        ScheduleFormatters.monthYear
                            .string(from: selectedDate)
                            .capitalized
                    )
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                    Text(selectedDate.dayHeadline(calendar: calendar))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button { moveWeek(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)

                    Button { moveWeek(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 14)

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.dayID) { date in
                    WeekChip(
                        date: date,
                        calendar: calendar,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date)
                    ) {
                        select(date)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)

            Divider()
        }
    }

    private func moveWeek(by value: Int) {
        guard let next = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDate)
        else { return }
        select(next)
    }

    // No withAnimation here — the onChange in ScheduleDashboardView owns the
    // scroll animation to avoid stacking two concurrent transactions.
    private func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }
}

// MARK: - Week Chip

private struct WeekChip: View {
    let date: Date
    let calendar: Calendar
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Day abbreviation — uses accentColor for selected so it's
                // visible on both light (white) and dark (black) backgrounds.
                Text(
                    ScheduleFormatters.shortWeekday
                        .string(from: date)
                        .lowercased()
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(labelColor)

                ZStack {
                    // Squircle background for selected day — consistent with
                    // the card cornerRadius language used throughout the app.
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor)
                            .frame(width: 36, height: 36)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(numberColor)
                        .monospacedDigit()
                }
                .frame(width: 36, height: 36)

                // Today indicator — a small dot below the number.
                Circle()
                    .fill(isToday && !isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        // White is invisible on light-theme background — use accentColor instead.
        if isSelected || isToday { return .accentColor }
        return .secondary
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }
}

// MARK: - Day Page

private struct ScheduleDayPage: View {
    let date: Date
    let entries: [ScheduleEntry]
    let calendar: Calendar
    // When the "Back to Today" button is visible, add extra bottom padding
    // so the last card is never hidden behind the floating button.
    let extraBottomPadding: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if entries.isEmpty {
                    DayEmptyState(date: date, calendar: calendar)
                        .padding(.top, 8)
                } else {
                    GlassEffectContainer(spacing: 14) {
                        VStack(spacing: 14) {
                            ForEach(entries) { entry in
                                ScheduleLessonCard(entry: entry, date: date)
                            }
                        }
                    }
                    .id(colorScheme)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, extraBottomPadding ? 68 : 56)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollIndicators(.hidden)
    }
}

private struct DayEmptyState: View {
    let date: Date
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: calendar.isDateInToday(date) ? "sun.max.fill" : "calendar")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text(calendar.isDateInToday(date) ? "Сегодня занятий нет" : "На этот день пар нет")
                .font(.headline.weight(.semibold))

            Text(
                calendar.isDateInToday(date)
                    ? "Выберите другой день выше."
                    : "Переключитесь на соседний день."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private func lessonCountText(_ count: Int) -> String {
    switch count {
    case 0: return "Свободно"
    case 1: return "1 занятие"
    case 2...4: return "\(count) занятия"
    default: return "\(count) занятий"
    }
}
