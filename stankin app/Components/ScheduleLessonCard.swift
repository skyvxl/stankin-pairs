import SwiftUI

struct ScheduleLessonCard: View {
    let entry: ScheduleEntry
    let date: Date

    private var progress: (completed: Int, total: Int)? {
        entry.progress(on: date)
    }

    private var tone: LessonTone {
        LessonTone(classType: entry.classType)
    }

    var body: some View {
        SchedulePanel(style: .plain, cornerRadius: 28, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.timeString)
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()

                        Text(slotSummary)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 8) {
                        SchedulePill(
                            title: entry.classType.rawValue,
                            systemImage: nil,
                            tint: tone.color
                        )

                        if let progress {
                            SchedulePill(
                                title: "\(progress.completed)/\(progress.total)",
                                systemImage: nil,
                                tint: .secondary
                            )
                        }
                    }
                }

                Text(entry.subject)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let teacher = entry.teacher, !teacher.isEmpty {
                    Text(teacher)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        locationPill

                        if entry.subgroup != .all {
                            subgroupPill
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        locationPill

                        if entry.subgroup != .all {
                            subgroupPill
                        }
                    }
                }
            }
        }
    }
}

private extension ScheduleLessonCard {
    @ViewBuilder
    var locationPill: some View {
        SchedulePill(
            title: entry.isRemote ? "Дистанционно" : (entry.room ?? "Аудитория"),
            systemImage: entry.isRemote ? "video.fill" : "building.2.fill",
            tint: .secondary
        )
    }

    @ViewBuilder
    var subgroupPill: some View {
        SchedulePill(
            title: "Подгруппа \(entry.subgroup.rawValue)",
            systemImage: "person.2.fill",
            tint: .accentColor
        )
    }

    var slotSummary: String {
        let start = entry.slotStart + 1
        let end = entry.slotEnd + 1

        if start == end {
            return "\(start)-я пара"
        }

        return "\(start)-\(end)-я пары"
    }
}

private struct LessonTone {
    let color: Color

    init(classType: ClassType) {
        switch classType {
        case .lecture:
            color = .blue
        case .seminar:
            color = .orange
        case .lab:
            color = .green
        }
    }
}
