import SwiftUI

struct ScheduleDashboardView: View {
    let store: ScheduleStore
    let calendar: Calendar

    @Binding var selectedDate: Date

    @State private var scrolledDateID: String?

    private var normalizedSelectedDate: Date {
        calendar.startOfDay(for: selectedDate)
    }

    private var pagerDates: [Date] {
        ScheduleCalendar.pagerDates
    }

    var body: some View {
        VStack(spacing: 0) {
            ScheduleWeekStripBar(
                calendar: calendar,
                selectedDate: $selectedDate
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            dayPager
        }
        .onAppear {
            scrolledDateID = normalizedSelectedDate.dayID
        }
        .onChange(of: selectedDate) { _, newValue in
            let normalized = calendar.startOfDay(for: newValue)
            let id = normalized.dayID

            guard scrolledDateID != id else { return }

            withAnimation(.snappy(duration: 0.22)) {
                scrolledDateID = id
            }
        }
        .onChange(of: scrolledDateID) { _, newID in
            guard let newID else { return }
            guard let date = ScheduleFormatters.dayID.date(from: newID) else { return }

            let normalized = calendar.startOfDay(for: date)
            if !calendar.isDate(normalized, inSameDayAs: selectedDate) {
                selectedDate = normalized
            }
        }
    }
}

private extension ScheduleDashboardView {
    var dayPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pagerDates, id: \.dayID) { date in
                    ScheduleDayPage(
                        date: date,
                        entries: store.entries(for: date),
                        calendar: calendar
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledDateID)
        .scrollIndicators(.hidden)
    }
}

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
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
    }
}

private struct ScheduleWeekStripBar: View {
    let calendar: Calendar

    @Binding var selectedDate: Date

    private var weekDates: [Date] {
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: selectedDate
        )

        guard let weekStart = calendar.date(from: components) else {
            return []
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    var body: some View {
        SchedulePanel(style: .card, cornerRadius: 28, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            ScheduleFormatters.monthYear
                                .string(from: selectedDate)
                                .capitalized
                        )
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(selectedDate.dayHeadline(calendar: calendar))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        WeekNavigationButton(systemName: "chevron.left") {
                            moveWeek(by: -1)
                        }

                        WeekNavigationButton(systemName: "chevron.right") {
                            moveWeek(by: 1)
                        }
                    }
                }

                HStack(spacing: 6) {
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
            }
        }
    }
}

private extension ScheduleWeekStripBar {
    func moveWeek(by value: Int) {
        guard let nextDate = calendar.date(
            byAdding: .weekOfYear,
            value: value,
            to: selectedDate
        ) else {
            return
        }

        select(nextDate)
    }

    func select(_ date: Date) {
        withAnimation(.snappy(duration: 0.22)) {
            selectedDate = calendar.startOfDay(for: date)
        }
    }
}

private struct WeekNavigationButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(buttonBackground, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var buttonBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.white.opacity(0.75)
    }
}

private struct WeekChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let calendar: Calendar
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(
                    ScheduleFormatters.shortWeekday
                        .string(from: date)
                        .lowercased()
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(weekdayColor)

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(numberColor)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        if isSelected {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.14)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.03)
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(colorScheme == .dark ? 0.16 : 0.72)
        }

        if isToday {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.22)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.white.opacity(0.72)
    }

    private var weekdayColor: Color {
        if isSelected {
            return selectedSecondary
        }

        return isToday ? .accentColor : .secondary
    }

    private var numberColor: Color {
        if isSelected {
            return .primary
        }

        return isToday ? .accentColor : .primary
    }

    private var selectedSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .primary.opacity(0.6)
    }
}

private struct ScheduleDayPage: View {
    let date: Date
    let entries: [ScheduleEntry]
    let calendar: Calendar

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                DayHeader(date: date, entries: entries, calendar: calendar)

                if entries.isEmpty {
                    DayEmptyState(date: date, calendar: calendar)
                } else {
                    ForEach(entries) { entry in
                        ScheduleLessonCard(entry: entry, date: date)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }
}

private struct DayHeader: View {
    let date: Date
    let entries: [ScheduleEntry]
    let calendar: Calendar

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.dayHeadline(calendar: calendar))
                    .font(.title2.weight(.bold))

                Text(
                    ScheduleFormatters.fullDate
                        .string(from: date)
                        .capitalized
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(lessonCountText(entries.count))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
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
                    ? "Выберите другой день в верхнем блоке."
                    : "Переключитесь на соседний день в верхнем блоке."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
