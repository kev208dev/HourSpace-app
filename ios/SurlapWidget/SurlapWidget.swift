import WidgetKit
import SwiftUI
import Foundation

// MARK: - Design tokens

extension Color {
    init(hexString: String, fallback: Color = Color(red: 0.35, green: 0.18, blue: 0.96)) {
        let hex = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&value) else {
            self = fallback
            return
        }

        switch hex.count {
        case 6:
            self = Color(
                .sRGB,
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                opacity: 1
            )
        case 8:
            // Flutter sends alpha first: #AARRGGBB.
            self = Color(
                .sRGB,
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                opacity: Double((value >> 24) & 0xFF) / 255
            )
        default:
            self = fallback
        }
    }
}

struct WidgetAppearance {
    let dark: Bool
    let accent: Color
    let background: Color
    let surface: Color
    let text: Color
    let textSoft: Color
    let hairline: Color

    static func defaults(dark: Bool) -> WidgetAppearance {
        WidgetAppearance(
            dark: dark,
            accent: Color(hexString: dark ? "#8B6CFF" : "#5A2DF4"),
            background: Color(hexString: dark ? "#15131F" : "#FBF9FE"),
            surface: Color(hexString: dark ? "#1A1A22" : "#FFFFFF"),
            text: Color(hexString: dark ? "#F2F2F6" : "#14131A"),
            textSoft: Color(hexString: dark ? "#ADADBC" : "#6E6B7A"),
            hairline: Color(hexString: dark ? "#38FFFFFF" : "#1F14131A")
        )
    }

    static func parse(root: [String: Any], defaults: UserDefaults?) -> WidgetAppearance {
        let appearance = root["appearance"] as? [String: Any] ?? [:]
        let theme = string(root["theme"]) ?? defaults?.string(forKey: "theme") ?? ""
        let dark = bool(appearance["dark"])
            ?? bool(root["dark"])
            ?? (theme == "dark")
        let fallback = WidgetAppearance.defaults(dark: dark)

        return WidgetAppearance(
            dark: dark,
            accent: color(appearance["accent"] ?? defaults?.string(forKey: "accent"), fallback: fallback.accent),
            background: color(appearance["background"], fallback: fallback.background),
            surface: color(appearance["surface"], fallback: fallback.surface),
            text: color(appearance["text"], fallback: fallback.text),
            textSoft: color(appearance["textSoft"], fallback: fallback.textSoft),
            hairline: color(appearance["hairline"], fallback: fallback.hairline)
        )
    }
}

// MARK: - Models

struct WidgetDday {
    let available: Bool
    let title: String
    let date: String
    let daysAway: Int
    let label: String

    static let placeholder = WidgetDday(
        available: true,
        title: "여름방학식",
        date: "2026-07-24",
        daysAway: 3,
        label: "D-3"
    )
}

struct WidgetEvent {
    let id: String
    let title: String
    let kind: String
    let allDay: Bool
    let start: String
    let end: String
    let timeLabel: String
    let color: Color
}

struct WidgetNextClass {
    let available: Bool
    let title: String
    let period: Int
    let start: String
    let end: String
    let source: String

    static let placeholder = WidgetNextClass(
        available: true,
        title: "영어",
        period: 4,
        start: "12:00",
        end: "12:50",
        source: "neis"
    )
}

struct WidgetMedium {
    let date: String
    let dateLabel: String
    let events: [WidgetEvent]
    let eventCount: Int
    let nextClass: WidgetNextClass
}

struct SurlapEntry: TimelineEntry {
    let date: Date
    let appearance: WidgetAppearance
    let small: WidgetDday
    let medium: WidgetMedium

    static let placeholder = SurlapEntry(
        date: Date(),
        appearance: .defaults(dark: false),
        small: .placeholder,
        medium: WidgetMedium(
            date: "2026-07-21",
            dateLabel: "7월 21일 (화)",
            events: [
                WidgetEvent(
                    id: "preview-1",
                    title: "수학 수행평가",
                    kind: "academic",
                    allDay: true,
                    start: "",
                    end: "",
                    timeLabel: "종일",
                    color: Color(hexString: "#5DCAA5")
                ),
                WidgetEvent(
                    id: "preview-2",
                    title: "동아리 회의",
                    kind: "event",
                    allDay: false,
                    start: "16:00",
                    end: "17:00",
                    timeLabel: "16:00",
                    color: Color(hexString: "#5A2DF4")
                )
            ],
            eventCount: 2,
            nextClass: .placeholder
        )
    )
}

// MARK: - App Group store

enum SurlapStore {
    static let appGroup = "group.com.kev208dev.Surlap"
    static let payloadKey = "hs_widget"

    static func load() -> SurlapEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let root = jsonObject(defaults?.string(forKey: payloadKey)) ?? [:]
        let appearance = WidgetAppearance.parse(root: root, defaults: defaults)
        let small = parseSmall(root: root, defaults: defaults)
        let medium = parseMedium(root: root, defaults: defaults, appearance: appearance)

        return SurlapEntry(
            date: Date(),
            appearance: appearance,
            small: small,
            medium: medium
        )
    }

    private static func parseSmall(root: [String: Any], defaults: UserDefaults?) -> WidgetDday {
        let payload = root["small"] as? [String: Any] ?? [:]
        let title = string(payload["title"])
            ?? defaults?.string(forKey: "ddayTitle")
            ?? ""
        let date = string(payload["date"]) ?? ""
        let daysAway = int(payload["daysAway"]) ?? -1
        let providedLabel = string(payload["label"])
            ?? defaults?.string(forKey: "ddayLabel")
            ?? ""
        let label: String
        if !providedLabel.isEmpty {
            label = providedLabel
        } else if daysAway == 0 {
            label = "D-DAY"
        } else if daysAway > 0 {
            label = "D-\(daysAway)"
        } else {
            label = ""
        }

        return WidgetDday(
            available: bool(payload["available"]) ?? !title.isEmpty,
            title: title,
            date: date,
            daysAway: daysAway,
            label: label
        )
    }

    private static func parseMedium(
        root: [String: Any],
        defaults: UserDefaults?,
        appearance: WidgetAppearance
    ) -> WidgetMedium {
        let payload = root["medium"] as? [String: Any] ?? [:]
        let rawEvents: [[String: Any]] = {
            if let nested = payload["events"] as? [[String: Any]] { return nested }
            if let flat = jsonArray(defaults?.string(forKey: "mediumEvents")) { return flat }

            // Old hs_widget payloads separated all-day and timed events.
            let allDay = (root["allDay"] as? [[String: Any]] ?? []).map { old -> [String: Any] in
                var event = old
                event["allDay"] = true
                event["timeLabel"] = "종일"
                return event
            }
            let timed = (root["timed"] as? [[String: Any]] ?? []).map { old -> [String: Any] in
                var event = old
                event["allDay"] = false
                event["start"] = string(old["time"]) ?? ""
                event["timeLabel"] = string(old["time"]) ?? ""
                return event
            }
            return allDay + timed
        }()

        let events = rawEvents.prefix(3).enumerated().map { index, value in
            WidgetEvent(
                id: string(value["id"]) ?? "event-\(index)",
                title: string(value["title"]) ?? "",
                kind: string(value["kind"]) ?? "event",
                allDay: bool(value["allDay"]) ?? false,
                start: string(value["start"]) ?? "",
                end: string(value["end"]) ?? "",
                timeLabel: string(value["timeLabel"])
                    ?? string(value["time"])
                    ?? "",
                color: color(value["color"], fallback: appearance.accent)
            )
        }.filter { !$0.title.isEmpty }

        let nextPayload: [String: Any] = {
            if let nested = payload["nextClass"] as? [String: Any] { return nested }
            if let flat = jsonObject(defaults?.string(forKey: "nextClass")) { return flat }
            return [
                "available": !(defaults?.string(forKey: "nextName") ?? "").isEmpty,
                "title": defaults?.string(forKey: "nextName") ?? "",
                "start": defaults?.string(forKey: "nextStart") ?? "",
                "end": "",
                "period": -1,
                "source": "legacy"
            ]
        }()
        let nextTitle = string(nextPayload["title"]) ?? ""
        let nextClass = WidgetNextClass(
            available: bool(nextPayload["available"]) ?? !nextTitle.isEmpty,
            title: nextTitle,
            period: int(nextPayload["period"]) ?? -1,
            start: string(nextPayload["start"]) ?? "",
            end: string(nextPayload["end"]) ?? "",
            source: string(nextPayload["source"]) ?? ""
        )

        return WidgetMedium(
            date: string(payload["date"]) ?? string(root["date"]) ?? "",
            dateLabel: string(payload["dateLabel"])
                ?? string(root["dateLabel"])
                ?? defaults?.string(forKey: "today")
                ?? "오늘",
            events: events,
            eventCount: int(payload["eventCount"]) ?? int(root["eventCount"]) ?? events.count,
            nextClass: nextClass
        )
    }
}

private func jsonObject(_ raw: String?) -> [String: Any]? {
    guard let raw = raw, let data = raw.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any] else { return nil }
    return dictionary
}

private func jsonArray(_ raw: String?) -> [[String: Any]]? {
    guard let raw = raw, let data = raw.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data),
          let array = object as? [[String: Any]] else { return nil }
    return array
}

private func string(_ value: Any?) -> String? {
    if let value = value as? String { return value }
    if let value = value as? NSNumber { return value.stringValue }
    return nil
}

private func bool(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = value as? NSNumber { return value.boolValue }
    if let value = value as? String {
        if value.lowercased() == "true" || value == "1" { return true }
        if value.lowercased() == "false" || value == "0" { return false }
    }
    return nil
}

private func int(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? String { return Int(value) }
    return nil
}

private func color(_ value: Any?, fallback: Color) -> Color {
    guard let hex = string(value), !hex.isEmpty else { return fallback }
    return Color(hexString: hex, fallback: fallback)
}

// MARK: - Small: nearest academic D-Day

struct SmallDdayView: View {
    let entry: SurlapEntry

    private var appearance: WidgetAppearance { entry.appearance }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("학사 D-DAY")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.3)
                Spacer(minLength: 0)
            }
            .foregroundColor(appearance.accent)

            Spacer(minLength: 8)

            if entry.small.available {
                Text(entry.small.label)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(appearance.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(entry.small.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appearance.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .padding(.top, 3)

                if !entry.small.date.isEmpty {
                    Text(formattedDate(entry.small.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(appearance.textSoft)
                        .lineLimit(1)
                        .padding(.top, 5)
                }
            } else {
                Text("예정된 학사 일정이 없어요")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(appearance.text)
                    .lineLimit(2)
                Text("앱에서 학사 일정을 확인해 주세요")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appearance.textSoft)
                    .lineLimit(2)
                    .padding(.top, 6)
            }
        }
    }
}

// MARK: - Medium: today events + next class

struct MediumTodayView: View {
    let entry: SurlapEntry

    private var appearance: WidgetAppearance { entry.appearance }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("오늘 일정")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appearance.text)
                Spacer(minLength: 4)
                Text(entry.medium.dateLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appearance.textSoft)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 5) {
                if entry.medium.events.isEmpty {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(appearance.hairline)
                            .frame(width: 6, height: 6)
                        Text("오늘 등록된 일정이 없어요")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(appearance.textSoft)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    ForEach(Array(entry.medium.events.prefix(3).enumerated()), id: \.offset) { _, event in
                        EventRow(event: event, appearance: appearance)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)

            Rectangle()
                .fill(appearance.hairline)
                .frame(height: 0.5)
                .padding(.bottom, 7)

            NextClassRow(nextClass: entry.medium.nextClass, appearance: appearance)
        }
    }
}

private struct EventRow: View {
    let event: WidgetEvent
    let appearance: WidgetAppearance

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.color)
                .frame(width: 3, height: 14)
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(appearance.text)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(event.timeLabel.isEmpty ? (event.allDay ? "종일" : event.start) : event.timeLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(appearance.textSoft)
                .lineLimit(1)
        }
        .frame(height: 16)
    }
}

private struct NextClassRow: View {
    let nextClass: WidgetNextClass
    let appearance: WidgetAppearance

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(appearance.accent)
                .frame(width: 14)
            Text("다음 수업")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(appearance.textSoft)
            Text(nextClass.available ? nextClass.title : "예정된 수업 없음")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(appearance.text)
                .lineLimit(1)
            Spacer(minLength: 5)
            if nextClass.available {
                Text(classLabel(nextClass))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(appearance.accent)
                    .lineLimit(1)
            }
        }
        .frame(height: 17)
    }
}

private func classLabel(_ nextClass: WidgetNextClass) -> String {
    if nextClass.period > 0 && !nextClass.start.isEmpty {
        return "\(nextClass.period)교시 · \(nextClass.start)"
    }
    if nextClass.period > 0 { return "\(nextClass.period)교시" }
    return nextClass.start
}

private func formattedDate(_ raw: String) -> String {
    let parts = raw.split(separator: "-")
    guard parts.count == 3,
          let month = Int(parts[1]),
          let day = Int(parts[2]) else { return raw }
    return "\(month)월 \(day)일"
}

// MARK: - Provider and widget

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SurlapEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SurlapEntry) -> Void) {
        completion(context.isPreview ? .placeholder : SurlapStore.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SurlapEntry>) -> Void) {
        let entry = SurlapStore.load()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

private struct SurfaceBackground: ViewModifier {
    let color: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { color }
        } else {
            content
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct SurlapWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SurlapEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallDdayView(entry: entry)
            default:
                MediumTodayView(entry: entry)
            }
        }
        .padding(family == .systemSmall ? 16 : 15)
        .modifier(SurfaceBackground(color: entry.appearance.surface))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .widgetURL(URL(string: "surlap://widget"))
    }
}

struct SurlapWidget: Widget {
    let kind = "SurlapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SurlapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Surlap")
        .description("가장 가까운 학사 일정과 오늘 일정을 확인해요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SurlapWidgetBundle: WidgetBundle {
    var body: some Widget {
        SurlapWidget()
    }
}
