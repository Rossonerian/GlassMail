import SwiftUI
import WidgetKit

private let appGroupId = "group.com.glassmail.dev.glassmail.shared"
private let widgetKind = "GlassMailInboxWidget"

private struct InboxEntry: TimelineEntry {
  let date: Date
  let unreadCount: Int
}

private struct InboxProvider: TimelineProvider {
  func placeholder(in context: Context) -> InboxEntry {
    InboxEntry(date: Date(), unreadCount: 3)
  }

  func getSnapshot(in context: Context, completion: @escaping (InboxEntry) -> Void) {
    completion(readEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<InboxEntry>) -> Void) {
    completion(Timeline(entries: [readEntry()], policy: .never))
  }

  private func readEntry() -> InboxEntry {
    let count = UserDefaults(suiteName: appGroupId)?.integer(forKey: "unreadCount") ?? 0
    return InboxEntry(date: Date(), unreadCount: max(0, count))
  }
}

private struct InboxWidgetView: View {
  let entry: InboxEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("GlassMail")
        .font(.headline)
      Text(entry.unreadCount > 99 ? "99+" : "\(entry.unreadCount)")
        .font(.system(size: 34, weight: .semibold, design: .rounded))
      Text("unread messages")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    .widgetURL(URL(string: "glassmail://inbox"))
  }
}

struct GlassMailInboxWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: widgetKind, provider: InboxProvider()) { entry in
      InboxWidgetView(entry: entry)
    }
    .configurationDisplayName("GlassMail Inbox")
    .description("Shows the number of unread messages without exposing message details.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct GlassMailWidgetBundle: WidgetBundle {
  var body: some Widget {
    GlassMailInboxWidget()
  }
}
