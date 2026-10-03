import SwiftUI
import WidgetKit

/// Extensão de widgets da app: por agora só a Live Activity dos temporizadores.
@main
struct ReceitasWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CookingTimerLiveActivity()
    }
}
