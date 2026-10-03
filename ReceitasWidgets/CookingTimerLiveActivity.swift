import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Contagem de um temporizador no ecrã bloqueado e na Dynamic Island.
/// Ainda não é usada: os temporizadores passam a ser alarmes na fase seguinte.
struct CookingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingTimerMetadata>.self) { context in
            Text(context.attributes.metadata?.label ?? "Temporizador")
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.label ?? "Temporizador")
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}
