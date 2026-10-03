import AlarmKit
import Foundation

/// Dados de um temporizador do modo cozinhar, guardados no alarme do AlarmKit.
/// Este ficheiro é partilhado com a extensão de widgets, que os mostra na Live Activity.
nonisolated struct CookingTimerMetadata: AlarmMetadata {
    /// Nome do passo ("Forno · 30 min").
    var label: String
    var recipeTitle: String
    var recipeID: UUID?
    var stepID: UUID?
}
