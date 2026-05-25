import ActivityKit
import SwiftUI
import WidgetKit

struct StrydeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StrydeLiveActivityAttributes.self) { context in
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(formatDistance(context.state.distance), systemImage: "figure.run")
                        .font(.headline)
                        .foregroundStyle(Color.strydePrimary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label(formatDuration(context.state.elapsed), systemImage: "timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let pace = context.state.pace {
                        HStack {
                            Image(systemName: "speedometer")
                            Text(formatPace(pace))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(Color.strydePrimary)
            } compactTrailing: {
                Text(formatDistance(context.state.distance))
                    .font(.caption2.bold())
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(Color.strydePrimary)
            }
            .keylineTint(Color.strydePrimary)
        }
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {
    let state: StrydeLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(Color.strydePrimary)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Stryde")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(formatDistance(state.distance))
                    .font(.title3.bold())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(state.elapsed))
                    .font(.title3.bold().monospacedDigit())
                if let pace = state.pace {
                    Text(formatPace(pace))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.trailing, 8)
        }
        .padding(12)
        .background(Color(.systemBackground))
    }
}
