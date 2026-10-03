import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Contagem de um temporizador (alarme do AlarmKit) no ecrã bloqueado e na Dynamic Island.
/// Tocar abre a receita na app.
struct CookingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingTimerMetadata>.self) { context in
            let metadata = context.attributes.metadata
            CookingTimerLockScreenView(
                label: metadata?.label ?? "Temporizador",
                recipeTitle: metadata?.recipeTitle ?? "Receitas",
                alarmID: context.state.alarmID,
                display: Self.display(context.state)
            )
            .activityBackgroundTint(Color.black.opacity(0.35))
            .activitySystemActionForegroundColor(.orange)
            .widgetURL(Self.url(metadata))
        } dynamicIsland: { context in
            let metadata = context.attributes.metadata
            let display = Self.display(context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: display.isPaused ? "pause.circle.fill" : "timer.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookingTimerCountdown(display: display)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metadata?.label ?? "Temporizador")
                            .font(.headline)
                            .lineLimit(1)
                        Text(metadata?.recipeTitle ?? "Receitas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        CookingTimerButtons(alarmID: context.state.alarmID, display: display)
                    }
                }
            } compactLeading: {
                Image(systemName: display.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                CookingTimerCountdown(display: display)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
            .widgetURL(Self.url(metadata))
            .keylineTint(.orange)
        }
    }

    private static func display(_ state: AlarmPresentationState) -> CookingTimerDisplay {
        switch state.mode {
        case .countdown(let countdown):
            return .countdown(end: countdown.fireDate)
        case .paused(let paused):
            return .paused(remaining: paused.totalCountdownDuration - paused.previouslyElapsedDuration)
        default:
            return .ringing
        }
    }

    private static func url(_ metadata: CookingTimerMetadata?) -> URL? {
        guard let id = metadata?.recipeID else { return nil }
        return URL(string: "receitas://receita/\(id.uuidString)")
    }
}
