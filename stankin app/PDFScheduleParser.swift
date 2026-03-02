//
//  PDFScheduleParser.swift
//  stankin app
//
//  Created by Дмитрий Нилов on 01.03.2026.
//

import Foundation
import PDFKit

// MARK: - 1. Модели данных ═══════════════════════════════════════

private extension String {
    var scheduleTrimmed: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedDateToken: String {
        replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Weekday: Int, Codable, CaseIterable, Comparable {
    case monday = 0
    case tuesday, wednesday, thursday, friday, saturday

    var name: String {
        switch self {
        case .monday: return "Понедельник"
        case .tuesday: return "Вторник"
        case .wednesday: return "Среда"
        case .thursday: return "Четверг"
        case .friday: return "Пятница"
        case .saturday: return "Суббота"
        }
    }

    static func from(calendarWeekday: Int) -> Weekday? {
        let mapped = (calendarWeekday + 5) % 7
        return Weekday(rawValue: mapped)
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum ClassType: String, Codable {
    case lecture = "Лекция"
    case seminar = "Семинар"
    case lab = "Лабораторная"
}

enum Subgroup: String, Codable {
    case a = "А"
    case b = "Б"
    case all = "all"
}

struct DateRange: Codable, Equatable {
    let start: String
    let end: String?
    let isEveryWeek: Bool
    let isBiweekly: Bool

    init(start: String, end: String?, isEveryWeek: Bool, isBiweekly: Bool) {
        self.start = start.cleanedDateToken
        self.end = end?.cleanedDateToken
        self.isEveryWeek = isEveryWeek
        self.isBiweekly = isBiweekly
    }

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case isEveryWeek
        case isBiweekly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startRaw = try container.decode(String.self, forKey: .start)
        let endRaw = try container.decodeIfPresent(String.self, forKey: .end)
        let decodedBiweekly = try container.decodeIfPresent(
            Bool.self,
            forKey: .isBiweekly
        )
        let decodedEveryWeek = try container.decodeIfPresent(
            Bool.self,
            forKey: .isEveryWeek
        )

        let hasRangeEnd = (endRaw?.cleanedDateToken.isEmpty == false)
        let biweekly = decodedBiweekly ?? false
        let everyWeek = decodedEveryWeek ?? (hasRangeEnd && !biweekly)

        self.init(
            start: startRaw,
            end: endRaw,
            isEveryWeek: everyWeek,
            isBiweekly: biweekly
        )
    }

    func expand(academicYear: Int, forceBiweekly: Bool = false) -> [Date] {
        let cal = Calendar(identifier: .gregorian)
        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM.yyyy"
        fmt.locale = Locale(identifier: "ru_RU")

        func resolveYear(for ddMM: String) -> Int {
            let month = Int(ddMM.split(separator: ".").last ?? "1") ?? 1
            return month >= 9 ? academicYear : academicYear + 1
        }

        guard
            let startDate = fmt.date(
                from: "\(start).\(resolveYear(for: start))"
            )
        else { return [] }

        guard let endStr = end,
            let endDate = fmt.date(
                from: "\(endStr).\(resolveYear(for: endStr))"
            )
        else { return [startDate] }

        let step = (isBiweekly || (isEveryWeek && forceBiweekly)) ? 14 : 7
        var dates: [Date] = []
        var current = startDate
        while current <= endDate {
            dates.append(current)
            guard let next = cal.date(byAdding: .day, value: step, to: current)
            else { break }
            current = next
        }
        return dates
    }
}

struct TimeSlot: Codable, Equatable, Hashable {
    let index: Int
    let start: String
    let end: String

    static let slots: [TimeSlot] = [
        .init(index: 0, start: "8:30", end: "10:10"),
        .init(index: 1, start: "10:20", end: "12:00"),
        .init(index: 2, start: "12:20", end: "14:00"),
        .init(index: 3, start: "14:10", end: "15:50"),
        .init(index: 4, start: "16:00", end: "17:40"),
        .init(index: 5, start: "18:00", end: "19:30"),
        .init(index: 6, start: "19:40", end: "21:10"),
        .init(index: 7, start: "21:20", end: "22:50"),
    ]

    static let headerStrings: [String] = [
        "8:30", "10:20", "12:20", "14:10", "16:00", "18:00", "19:40", "21:20",
    ]
}

struct ScheduleEntry: Codable, Identifiable {
    let id: String
    let subject: String
    let teacher: String?
    let classType: ClassType
    let subgroup: Subgroup
    let room: String?
    let weekday: Weekday
    let slotStart: Int
    let slotEnd: Int
    let dates: [DateRange]

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case teacher
        case classType
        case subgroup
        case room
        case weekday
        case slotStart
        case slotEnd
        case dates
    }

    init(
        id: String,
        subject: String,
        teacher: String?,
        classType: ClassType,
        subgroup: Subgroup,
        room: String?,
        weekday: Weekday,
        slotStart: Int,
        slotEnd: Int,
        dates: [DateRange]
    ) {
        self.id = id
        self.subject = Self.normalizeSubject(subject)
        self.teacher = teacher?.scheduleTrimmed
        let normalizedRoom = room?.scheduleTrimmed
        self.room =
            (normalizedRoom?.isEmpty == false) ? normalizedRoom : nil
        self.classType = classType
        self.subgroup = subgroup
        self.weekday = weekday
        self.slotStart = slotStart
        self.slotEnd = slotEnd
        self.dates = dates
    }

    private static func normalizeSubject(_ raw: String) -> String {
        var value = raw.scheduleTrimmed
        while value.hasPrefix(".") || value.hasPrefix(",") {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        while value.hasSuffix(".") || value.hasSuffix(",") {
            value = String(value.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return value.isEmpty ? "Без названия" : value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString
        let subject = try container.decode(String.self, forKey: .subject)
        let teacher = try container.decodeIfPresent(String.self, forKey: .teacher)
        let classType = try container.decode(ClassType.self, forKey: .classType)
        let subgroup = try container.decodeIfPresent(Subgroup.self, forKey: .subgroup)
            ?? .all
        let room = try container.decodeIfPresent(String.self, forKey: .room)
        let weekday = try container.decode(Weekday.self, forKey: .weekday)
        let slotStart = try container.decode(Int.self, forKey: .slotStart)
        let slotEnd =
            try container.decodeIfPresent(Int.self, forKey: .slotEnd) ?? slotStart
        let dates = try container.decode([DateRange].self, forKey: .dates)

        self.init(
            id: id,
            subject: subject,
            teacher: teacher,
            classType: classType,
            subgroup: subgroup,
            room: room,
            weekday: weekday,
            slotStart: slotStart,
            slotEnd: slotEnd,
            dates: dates
        )
    }

    var isRemote: Bool { room == nil }

    var timeString: String {
        let s = TimeSlot.slots[slotStart]
        let e = TimeSlot.slots[slotEnd]
        return "\(s.start) – \(e.end)"
    }
}

struct GroupSchedule: Codable {
    let groupName: String
    let entries: [ScheduleEntry]

    func forDate(
        _ date: Date,
        subgroup: Subgroup = .all,
        academicYear: Int? = nil
    ) -> [ScheduleEntry] {
        let cal = Calendar(identifier: .gregorian)
        let cw = cal.component(.weekday, from: date)
        guard let weekday = Weekday.from(calendarWeekday: cw) else { return [] }

        let year =
            academicYear
            ?? {
                let m = cal.component(.month, from: date)
                let y = cal.component(.year, from: date)
                return m >= 9 ? y : y - 1
            }()

        let target = cal.startOfDay(for: date)
        let alternatingLabIDs = detectAlternatingLabEntries()

        return
            entries
            .filter { $0.weekday == weekday }
            .filter { e in
                subgroup == .all || e.subgroup == .all || e.subgroup == subgroup
            }
            .filter { e in
                let forceBiweekly = alternatingLabIDs.contains(e.id)
                return e.dates.flatMap {
                    $0.expand(
                        academicYear: year,
                        forceBiweekly: forceBiweekly
                    )
                }
                    .contains { cal.startOfDay(for: $0) == target }
            }
            .sorted { $0.slotStart < $1.slotStart }
    }

    private func detectAlternatingLabEntries() -> Set<String> {
        let subgroupLabs = entries.filter {
            $0.classType == .lab && $0.subgroup != .all
        }
        guard !subgroupLabs.isEmpty else { return [] }

        var result: Set<String> = []

        for lhs in subgroupLabs {
            let oppositeSubgroup: Subgroup = lhs.subgroup == .a ? .b : .a

            let matchingPartners = subgroupLabs.filter {
                $0.id != lhs.id
                    && $0.weekday == lhs.weekday
                    && $0.slotStart == lhs.slotStart
                    && $0.slotEnd == lhs.slotEnd
                    && $0.subgroup == oppositeSubgroup
            }

            guard !matchingPartners.isEmpty else { continue }

            for rhs in matchingPartners {
                if hasWeekShiftBetweenSubgroups(lhs, rhs) {
                    result.insert(lhs.id)
                    result.insert(rhs.id)
                }
            }
        }

        return result
    }

    private func hasWeekShiftBetweenSubgroups(
        _ lhs: ScheduleEntry,
        _ rhs: ScheduleEntry
    ) -> Bool {
        for l in lhs.dates where l.end != nil && l.isEveryWeek && !l.isBiweekly {
            for r in rhs.dates where r.end != nil && r.isEveryWeek && !r.isBiweekly
            {
                guard let delta = dayDelta(l.start, r.start) else { continue }
                if abs(delta) == 7 { return true }
            }
        }
        return false
    }

    private func dayDelta(_ lhs: String, _ rhs: String) -> Int? {
        func makeDate(from token: String) -> Date? {
            let cleaned = token.cleanedDateToken
            let parts = cleaned.split(separator: ".")
            guard parts.count >= 2,
                let day = Int(parts[0]),
                let month = Int(parts[1])
            else { return nil }

            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.year = 2001
            components.month = month
            components.day = day
            return components.date
        }

        guard let leftDate = makeDate(from: lhs), let rightDate = makeDate(from: rhs)
        else { return nil }

        return Calendar(identifier: .gregorian)
            .dateComponents([.day], from: leftDate, to: rightDate).day
    }
}

// MARK: - 2. Grid Detection ═══════════════════════════════════════

struct ScheduleGrid {
    /// 9 значений — левые границы 8 столбцов + правый край (top-down coords)
    let columnEdges: [CGFloat]
    /// 7 значений — верхние границы 6 строк + нижний край (top-down coords)
    let rowEdges: [CGFloat]
    let groupName: String
    let pageHeight: CGFloat

    /// CGRect ячейки в PDF-координатах (bottom-up) для selection.
    /// Добавляем 3px padding по горизонтали чтобы не терять текст на границах.
    func pdfRect(row: Int, colStart: Int, colEnd: Int) -> CGRect {
        let hPad: CGFloat = 3.0
        let x0 = columnEdges[colStart] - hPad
        let x1 = columnEdges[colEnd + 1] + hPad
        let topY = rowEdges[row]
        let botY = rowEdges[row + 1]
        // top-down → PDF bottom-up
        return CGRect(
            x: x0,
            y: pageHeight - botY,
            width: x1 - x0,
            height: botY - topY
        )
    }
}

struct GridDetector {

    /// Находит X-позицию маркера в PDF (top-down Y).
    /// Проверяет несколько символов маркера — берёт первый с валидным bounds.
    static func findX(of marker: String, in page: PDFPage) -> CGFloat? {
        guard let str = page.string else { return nil }
        let ns = str as NSString

        let range = ns.range(of: marker)
        guard range.location != NSNotFound else { return nil }

        for offset in 0..<range.length {
            let raw = page.characterBounds(at: range.location + offset)
            if !raw.isEmpty && raw.width > 0 && raw.height > 0 {
                return raw.origin.x
            }
        }
        return nil
    }

    /// Находит Y-позицию (top-down) маркера.
    static func findY(of marker: String, in page: PDFPage) -> CGFloat? {
        guard let str = page.string else { return nil }
        let ns = str as NSString
        let pageHeight = page.bounds(for: .mediaBox).height

        let range = ns.range(of: marker)
        guard range.location != NSNotFound else { return nil }

        for offset in 0..<range.length {
            let raw = page.characterBounds(at: range.location + offset)
            if !raw.isEmpty && raw.width > 0 && raw.height > 0 {
                return pageHeight - raw.origin.y - raw.height
            }
        }
        return nil
    }

    static func detect(page: PDFPage) -> ScheduleGrid? {
        let pageH = page.bounds(for: .mediaBox).height
        let pageW = page.bounds(for: .mediaBox).width

        guard let str = page.string else { return nil }

        // ── Группа ──
        let groupName: String = {
            let ns = str as NSString
            let re = try? NSRegularExpression(
                pattern: #"[А-ЯA-Z]{2,4}-\d{2}-\d{2}"#
            )
            if let m = re?.firstMatch(
                in: str,
                range: NSRange(location: 0, length: ns.length)
            ) {
                return ns.substring(with: m.range)
            }
            return "Unknown"
        }()

        // ── Находим X-позиции заголовков времени ──
        var headerXs: [(index: Int, x: CGFloat)] = []
        for (i, h) in TimeSlot.headerStrings.enumerated() {
            if let x = findX(of: h, in: page) {
                headerXs.append((i, x))
            }
        }

        guard headerXs.count >= 7 else {
            print("❌ Найдено \(headerXs.count) заголовков, нужно >= 7")
            return nil
        }

        let sortedXs = headerXs.sorted { $0.x < $1.x }
        print("🔍 Группа: \(groupName)")
        for h in sortedXs {
            print(
                "  ⏰ Слот \(h.index) '\(TimeSlot.headerStrings[h.index])' → x=\(h.x.rounded())"
            )
        }

        // ── Вычисляем столбцы ──
        //
        // Из анализа PDF: текст заголовка начинается ~28-30px правее левой границы столбца.
        // Столбцы равномерные. Ширина столбца = расстояние между соседними заголовками.
        //
        // Формула: leftEdge[i] = headerX[i] - padding
        //
        // Вычисляем padding как среднее расстояние между заголовками / 3.2
        // (эмпирически: column_width ≈ 93.6, padding ≈ 29, ratio ≈ 3.2)

        let firstX = sortedXs.first!.x
        let lastX = sortedXs.last!.x
        let colWidth = (lastX - firstX) / CGFloat(sortedXs.count - 1)
        let padding = colWidth * 0.31  // ≈ 29px при colWidth=93

        var columnEdges: [CGFloat] = []
        for h in sortedXs {
            columnEdges.append(h.x - padding)
        }
        columnEdges.append(min(sortedXs.last!.x - padding + colWidth, pageW))

        // ── Вычисляем строки ──
        //
        // Дни недели написаны вертикально → characterBounds ненадёжен.
        // Вместо этого вычисляем математически:
        //   - headerY = Y-позиция любого заголовка времени
        //   - firstRowTop = headerY + headerHeight (≈ headerY + 10)
        //   - rowHeight = (pageHeight - firstRowTop - bottomMargin) / 6
        //
        // Из анализа: headerBottom ≈ 76, bottomMargin ≈ 51, rowHeight = 78.0

        guard let headerY = findY(of: TimeSlot.headerStrings[0], in: page)
        else {
            print("❌ Не удалось определить Y заголовков")
            return nil
        }

        let firstRowTop = headerY + 10.0  // низ строки заголовков
        let bottomMargin: CGFloat = 51.0  // из анализа PDF
        let contentHeight = pageH - firstRowTop - bottomMargin
        let rowHeight = contentHeight / 6.0

        var rowEdges: [CGFloat] = []
        for i in 0...5 {
            rowEdges.append(firstRowTop + CGFloat(i) * rowHeight)
        }
        rowEdges.append(pageH - bottomMargin)

        print(
            "  📊 colEdges (\(columnEdges.count)): \(columnEdges.map { Int($0.rounded()) })"
        )
        print(
            "  📊 rowEdges (\(rowEdges.count)): \(rowEdges.map { Int($0.rounded()) })"
        )
        print(
            "  📐 colWidth=\(colWidth.rounded()) padding=\(padding.rounded()) rowHeight=\(rowHeight.rounded())"
        )

        guard columnEdges.count == 9 && rowEdges.count == 7 else { return nil }

        return ScheduleGrid(
            columnEdges: columnEdges,
            rowEdges: rowEdges,
            groupName: groupName,
            pageHeight: pageH
        )
    }
}

// MARK: - 3. Cell Extraction ══════════════════════════════════════

struct TableCell {
    let weekday: Weekday
    let slotStart: Int
    let slotEnd: Int
    let text: String
}

struct CellExtractor {

    static func extractText(from page: PDFPage, rect: CGRect) -> String {
        guard let sel = page.selection(for: rect) else { return "" }
        return sel.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func extractAll(from page: PDFPage, grid: ScheduleGrid)
        -> [TableCell]
    {
        let numRows = 6
        let numCols = 8

        // Извлекаем текст каждой ячейки
        var rawTexts: [[String]] = Array(
            repeating: Array(repeating: "", count: numCols),
            count: numRows
        )

        for row in 0..<numRows {
            for col in 0..<numCols {
                let rect = grid.pdfRect(row: row, colStart: col, colEnd: col)
                rawTexts[row][col] = extractText(from: page, rect: rect)
            }
        }

        // Формируем ячейки, определяем merged cells.
        //
        // Лабораторные занимают 2 пары → merged cell на 2 столбца.
        // Признак: одиночная ячейка содержит "[" без парного "]"
        // (текст обрезался на границе столбца).
        //
        // Алгоритм:
        // 1. Извлекаем текст каждого одиночного столбца
        // 2. Если скобки не сбалансированы → пробуем 2-колоночный rect
        // 3. Если 2-колоночный текст содержит больше полных [...] блоков → merged

        var cells: [TableCell] = []

        for row in 0..<numRows {
            guard let weekday = Weekday(rawValue: row) else { continue }
            var col = 0

            while col < numCols {
                let text = rawTexts[row][col]
                if text.isEmpty {
                    col += 1
                    continue
                }

                let openCount = text.filter({ $0 == "[" }).count
                let closeCount = text.filter({ $0 == "]" }).count
                let balanced = openCount == closeCount && openCount > 0

                // Пробуем merge если:
                //   - Скобки не сбалансированы (truncated text)
                //   - Или текст содержит "Лабораторная" (лабы часто на 2 пары)
                let shouldTryMerge = !balanced || text.contains("Лабораторная")

                if shouldTryMerge && col + 1 < numCols {
                    let mergedRect = grid.pdfRect(
                        row: row,
                        colStart: col,
                        colEnd: col + 1
                    )
                    let mergedText = extractText(from: page, rect: mergedRect)

                    let mergedOpen = mergedText.filter({ $0 == "[" }).count
                    let mergedClose = mergedText.filter({ $0 == "]" }).count
                    let mergedBalanced =
                        mergedOpen == mergedClose && mergedOpen > 0

                    // Используем merged если:
                    //   - merged сбалансирован, а одиночный нет
                    //   - или merged содержит больше полных [...] блоков
                    if (mergedBalanced && !balanced) || mergedClose > closeCount
                    {
                        cells.append(
                            TableCell(
                                weekday: weekday,
                                slotStart: col,
                                slotEnd: col + 1,
                                text: mergedText
                            )
                        )
                        col += 2
                        continue
                    }
                }

                cells.append(
                    TableCell(
                        weekday: weekday,
                        slotStart: col,
                        slotEnd: col,
                        text: text
                    )
                )
                col += 1
            }
        }

        return cells
    }
}

// MARK: - 4. Cell Text Parser ═════════════════════════════════════

struct CellTextParser {

    static let teacherRe = try! NSRegularExpression(
        pattern: #"[А-ЯЁ][а-яёА-ЯЁ-]+\s+[А-ЯЁ]\.[А-ЯЁ]\."#
    )
    static let datesRe = try! NSRegularExpression(pattern: #"\[([^\]]+)\]"#)
    static let typeRe = try! NSRegularExpression(
        pattern: #"(Лабораторная|Семинар|Лекция)"#
    )
    static let subgroupRe = try! NSRegularExpression(pattern: #"\(([АБ])\)"#)

    static func parse(
        cellText: String,
        weekday: Weekday,
        slotStart: Int,
        slotEnd: Int
    ) -> [ScheduleEntry] {
        splitEntries(cellText).compactMap {
            parseOne(
                $0,
                weekday: weekday,
                slotStart: slotStart,
                slotEnd: slotEnd
            )
        }
    }

    static func splitEntries(_ text: String) -> [String] {
        let ns = text as NSString
        let matches = datesRe.matches(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        )
        guard !matches.isEmpty else { return [] }

        var results: [String] = []
        var lastEnd = 0
        for m in matches {
            let end = m.range.location + m.range.length
            let slice = ns.substring(
                with: NSRange(location: lastEnd, length: end - lastEnd)
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            if !slice.isEmpty { results.append(slice) }
            lastEnd = end
        }
        return results
    }

    static func parseOne(
        _ text: String,
        weekday: Weekday,
        slotStart: Int,
        slotEnd: Int
    ) -> ScheduleEntry? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        guard let dm = datesRe.firstMatch(in: text, range: full) else {
            return nil
        }
        let dates = parseDates(ns.substring(with: dm.range(at: 1)))
        guard !dates.isEmpty else { return nil }

        let clean = datesRe.stringByReplacingMatches(
            in: text,
            range: full,
            withTemplate: ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        let nsc = clean as NSString
        let cr = NSRange(location: 0, length: nsc.length)

        guard let tm = typeRe.firstMatch(in: clean, range: cr),
            let classType = ClassType(rawValue: nsc.substring(with: tm.range))
        else { return nil }

        let subgroup: Subgroup = {
            guard let m = subgroupRe.firstMatch(in: clean, range: cr) else {
                return .all
            }
            return Subgroup(rawValue: nsc.substring(with: m.range(at: 1)))
                ?? .all
        }()

        let teacher: String? = {
            guard let m = teacherRe.firstMatch(in: clean, range: cr) else {
                return nil
            }
            return nsc.substring(with: m.range)
        }()

        let subjectEnd: Int = {
            if let t = teacher {
                let r = (clean as NSString).range(of: t)
                if r.location != NSNotFound { return r.location }
            }
            return tm.range.location
        }()

        var subject = nsc.substring(
            with: NSRange(location: 0, length: subjectEnd)
        )
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        while subject.hasPrefix(".") || subject.hasPrefix(",") {
            subject = String(subject.dropFirst()).trimmingCharacters(
                in: .whitespaces
            )
        }
        while subject.hasSuffix(".") || subject.hasSuffix(",") {
            subject = String(subject.dropLast()).trimmingCharacters(
                in: .whitespaces
            )
        }
        guard !subject.isEmpty else { return nil }

        let room = extractRoom(clean, classType: classType, subgroup: subgroup)

        return ScheduleEntry(
            id: UUID().uuidString,
            subject: subject,
            teacher: teacher,
            classType: classType,
            subgroup: subgroup,
            room: room,
            weekday: weekday,
            slotStart: slotStart,
            slotEnd: slotEnd,
            dates: dates
        )
    }

    static func extractRoom(
        _ text: String,
        classType: ClassType,
        subgroup: Subgroup
    ) -> String? {
        // Если явной аудитории нет, считаем пару дистанционной.
        var s = text
        guard let r = s.range(of: classType.rawValue) else { return nil }
        s = String(s[r.upperBound...])
        if subgroup != .all, let sr = s.range(of: "(\(subgroup.rawValue))") {
            s = String(s[sr.upperBound...])
        }
        if let teacher = teacherRe.firstMatch(
            in: s,
            range: NSRange(location: 0, length: (s as NSString).length)
        ) {
            s = (s as NSString).replacingCharacters(in: teacher.range, with: "")
        }

        let ns = s as NSString
        let c = datesRe.stringByReplacingMatches(
            in: s,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: ""
        )
        let normalized = c.scheduleTrimmed.lowercased()
        if normalized.contains("дист") || normalized.contains("online") {
            return nil
        }

        let roomRegex = try? NSRegularExpression(
            pattern: #"(Фрезер\s*С\/З\s*\d+|\b\d{3,4}(?:\([а-яА-Яa-zA-Z]\))?\b)"#
        )

        guard let roomRegex,
            let match = roomRegex.firstMatch(
                in: c,
                range: NSRange(location: 0, length: (c as NSString).length)
            )
        else { return nil }

        let room = (c as NSString).substring(with: match.range).scheduleTrimmed
        return room.isEmpty ? nil : room
    }

    static func parseDates(_ text: String) -> [DateRange] {
        text.components(separatedBy: ",").compactMap { part in
            let p = part.trimmingCharacters(in: .whitespaces)
            guard !p.isEmpty else { return nil }
            let ew = p.contains("к.н.")
            let bw = p.contains("ч.н.")
            let c = p.replacingOccurrences(of: "к.н.", with: "")
                .replacingOccurrences(of: "ч.н.", with: "")
                .trimmingCharacters(in: .whitespaces)
            if c.contains("-") {
                let pts = c.split(separator: "-").map {
                    String($0).cleanedDateToken
                }
                guard pts.count == 2 else { return nil }
                return DateRange(
                    start: pts[0],
                    end: pts[1],
                    isEveryWeek: ew || (!ew && !bw),
                    isBiweekly: bw
                )
            }
            return DateRange(
                start: c.cleanedDateToken,
                end: nil,
                isEveryWeek: false,
                isBiweekly: false
            )
        }
    }
}

// MARK: - 5. Main Parser ═════════════════════════════════════════

struct PDFScheduleParser {

    nonisolated static func parse(pdfURL: URL) -> GroupSchedule? {
        guard let doc = PDFDocument(url: pdfURL) else { return nil }
        return parse(document: doc)
    }

    nonisolated static func parse(pdfData: Data) -> GroupSchedule? {
        guard let doc = PDFDocument(data: pdfData) else { return nil }
        return parse(document: doc)
    }

    nonisolated static func parse(document: PDFDocument) -> GroupSchedule? {
        guard document.pageCount > 0 else { return nil }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            if let schedule = parse(page: page), !schedule.entries.isEmpty {
                return schedule
            }
        }
        return nil
    }

    nonisolated static func parse(page: PDFPage) -> GroupSchedule? {
        guard let grid = GridDetector.detect(page: page) else { return nil }

        let cells = CellExtractor.extractAll(from: page, grid: grid)
        print("✅ Ячеек: \(cells.count)")

        var entries: [ScheduleEntry] = []
        for cell in cells {
            entries.append(
                contentsOf: CellTextParser.parse(
                    cellText: cell.text,
                    weekday: cell.weekday,
                    slotStart: cell.slotStart,
                    slotEnd: cell.slotEnd
                )
            )
        }
        print("✅ Записей: \(entries.count)")

        return GroupSchedule(groupName: grid.groupName, entries: entries)
    }

    static func toJSON(_ schedule: GroupSchedule) -> Data? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(schedule)
    }

    static func fromJSON(_ data: Data) -> GroupSchedule? {
        try? JSONDecoder().decode(GroupSchedule.self, from: data)
    }
}

// MARK: - 6. Diagnostics ═════════════════════════════════════════

func runDiagnostics(pdfPath: String) -> Data? {
    print("═══════════════════════════════════════════")
    print("  ДИАГНОСТИКА v4")
    print("═══════════════════════════════════════════\n")

    let url = URL(fileURLWithPath: pdfPath)
    guard FileManager.default.fileExists(atPath: pdfPath) else {
        print("❌ Файл не найден: \(pdfPath)")
        return nil
    }
    guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else {
        print("❌ Не удалось открыть PDF")
        return nil
    }

    let bounds = page.bounds(for: .mediaBox)
    print("📐 Страница: \(bounds.width) × \(bounds.height)")
    print("📝 Символов: \(page.numberOfCharacters)\n")

    // Step 1
    print("── STEP 1: Grid ──")
    guard let grid = GridDetector.detect(page: page) else {
        print("❌ Сетка не найдена")
        return nil
    }

    // Step 2
    print("\n── STEP 2: Cells ──")
    let cells = CellExtractor.extractAll(from: page, grid: grid)
    print("  Ячеек: \(cells.count)\n")
    for c in cells {
        let preview = c.text.replacingOccurrences(of: "\n", with: " | ").prefix(
            120
        )
        print(
            "  \(c.weekday.name.prefix(3)) [\(c.slotStart)-\(c.slotEnd)]: \(preview)"
        )
    }

    // Step 3
    print("\n── STEP 3: Parse ──")
    var all: [ScheduleEntry] = []
    for c in cells {
        let parsed = CellTextParser.parse(
            cellText: c.text,
            weekday: c.weekday,
            slotStart: c.slotStart,
            slotEnd: c.slotEnd
        )
        if parsed.isEmpty && !c.text.isEmpty {
            let preview = c.text.replacingOccurrences(of: "\n", with: " ")
                .prefix(80)
            print(
                "  ⚠️ НЕ РАСПАРСИЛОСЬ: \(c.weekday.name) [\(c.slotStart)]: \(preview)"
            )
        }
        all.append(contentsOf: parsed)
    }

    print("\n  ✅ Записей: \(all.count)\n")
    for e in all {
        let sub = e.subgroup == .all ? "  " : " \(e.subgroup.rawValue)"
        let room = e.room ?? "дист."
        let datesPreview = e.dates.map { d in
            if let end = d.end { return "\(d.start)-\(end)" }
            return d.start
        }.joined(separator: ", ")
        print(
            "  \(e.weekday.name.prefix(3)) \(e.timeString) | \(e.subject) | \(e.classType.rawValue)\(sub) | \(e.teacher ?? "-") | \(room) | [\(datesPreview)]"
        )
    }

    // JSON
    let schedule = GroupSchedule(groupName: grid.groupName, entries: all)
    return PDFScheduleParser.toJSON(schedule)
}
