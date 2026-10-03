import AlarmKit
import AppIntents
import Foundation

// Botões da Live Activity dos temporizadores. Correm na app (mesmo fechada) e mexem no alarme do AlarmKit.
// Ficam fora dos Atalhos: só fazem sentido a partir da Live Activity.

struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pausar temporizador"
    static let isDiscoverable = false

    @Parameter(title: "Alarme")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { alarmID = "" }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.pause(id: id) }
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Continuar temporizador"
    static let isDiscoverable = false

    @Parameter(title: "Alarme")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { alarmID = "" }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.resume(id: id) }
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Parar temporizador"
    static let isDiscoverable = false

    @Parameter(title: "Alarme")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { alarmID = "" }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.cancel(id: id) }
        return .result()
    }
}
