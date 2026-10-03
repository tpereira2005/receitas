import AlarmKit
import Foundation
import Observation
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Progresso guardado

/// Ingredientes e passos marcados numa receita. Ficam guardados durante 12 horas
/// (sair da receita a meio não perde nada) ou até "Fiz esta receita".
nonisolated struct CookingProgress: Codable, Equatable, Sendable {
    var ingredients: Set<UUID> = []
    var steps: Set<UUID> = []
    var updatedAt = Date()

    static let lifetime: TimeInterval = 12 * 60 * 60

    var isEmpty: Bool { ingredients.isEmpty && steps.isEmpty }

    private static func key(_ id: UUID) -> String { "cooking.\(id.uuidString)" }

    static func load(for id: UUID, now: Date = .now, defaults: UserDefaults = .standard) -> CookingProgress {
        guard let data = defaults.data(forKey: key(id)),
              let progress = try? JSONDecoder().decode(CookingProgress.self, from: data),
              now.timeIntervalSince(progress.updatedAt) < lifetime
        else { return CookingProgress() }
        return progress
    }

    static func save(_ progress: CookingProgress, for id: UUID, defaults: UserDefaults = .standard) {
        if progress.isEmpty {
            defaults.removeObject(forKey: key(id))
        } else if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: key(id))
        }
    }

    static func clear(for id: UUID, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(id))
    }
}

// MARK: - Leitura dos passos

/// Tira de cada passo os temporizadores ("forno durante 30 minutos") e os ingredientes que usa.
nonisolated enum StepAnalysis {
    struct Duration: Hashable, Sendable {
        let seconds: Int

        var label: String {
            if seconds < 60 { return "\(seconds) s" }
            return Format.minutes(seconds / 60)
        }
    }

    // Só se lê depois de criada (não muda): partilhá-la entre tarefas é seguro.
    nonisolated(unsafe) private static let durationPattern = try! NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)(?:\s*(?:a|-|–)\s*\d+(?:[.,]\d+)?)?\s*(minutos|minuto|min|horas|hora|h|segundos|segundo|seg|s)\b"#,
        options: [.caseInsensitive]
    )

    /// Temporizadores de 10 segundos a 3 horas (esperas maiores, como congelar 24 h, têm o seu próprio aviso).
    static func durations(in text: String) -> [Duration] {
        let range = NSRange(text.startIndex..., in: text)
        var result: [Duration] = []
        for match in durationPattern.matches(in: text, range: range) {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let value = Double(text[numberRange].replacingOccurrences(of: ",", with: "."))
            else { continue }
            let unit = text[unitRange].lowercased()
            let factor: Double = unit.hasPrefix("h") ? 3600 : unit.hasPrefix("s") ? 1 : 60
            let seconds = Int((value * factor).rounded())
            guard (10...(3 * 3600)).contains(seconds) else { continue }
            let duration = Duration(seconds: seconds)
            if !result.contains(duration) { result.append(duration) }
        }
        return result
    }

    /// Palavras dos nomes que não identificam um ingrediente ("Leite magro" → "leite").
    private static let ignoredWords: Set<String> = [
        "natural", "magro", "magra", "inteiro", "inteira", "liquido", "liquida", "proteina", "proteinas",
        "recheio", "powder", "gourmet", "select", "protein", "fresco", "fresca", "reduzido", "sucralose",
    ]

    private static func words(_ text: String) -> [String] {
        text.searchNormalized
            .split { !$0.isLetter }
            .map { word in
                // Plural simples: "leites" → "leite", "avelãs" → "avela".
                let word = String(word)
                return word.count > 3 && word.hasSuffix("s") ? String(word.dropLast()) : word
            }
    }

    /// Ingredientes mencionados no texto de um passo, pela ordem da lista de ingredientes.
    static func ingredients(in text: String, from ingredients: [Ingredient]) -> [Ingredient] {
        let stepWords = Set(words(text))
        return ingredients.filter { ingredient in
            words(ingredient.name).contains { word in
                guard word.count >= 3, !ignoredWords.contains(word) else { return false }
                if stepWords.contains(word) { return true }
                // Palavras compridas também valem pelo início ("proteico" não, "amêndoas" sim).
                return word.count >= 5 && stepWords.contains { $0.count >= 5 && ($0.hasPrefix(word) || word.hasPrefix($0)) }
            }
        }
    }
}

// MARK: - Temporizadores

/// Temporizadores do modo cozinhar e dos passos.
/// Com autorização, cada um é um alarme do AlarmKit: toca mesmo em silêncio e mostra a contagem no ecrã
/// bloqueado e na Dynamic Island. Sem autorização, chega uma notificação no fim.
/// Ficam guardados, por isso voltam a aparecer se a app for fechada.
@Observable
final class CookingTimers {
    static let shared = CookingTimers()
    private static let storageKey = "cookingTimers"
    /// "Mais 1 min" no alarme.
    nonisolated static let snoozeSeconds: TimeInterval = 60

    nonisolated struct ActiveTimer: Identifiable, Equatable, Codable, Sendable {
        var id = UUID()
        let label: String
        let recipeTitle: String
        /// Receita de onde veio (a cápsula no Início abre-a).
        var recipeID: UUID?
        /// Passo de onde veio, para o botão do passo mostrar a contagem.
        var stepID: UUID?
        var end: Date
        /// Em pausa (na Live Activity): o tempo que faltava.
        var pausedRemaining: TimeInterval?
        /// É um alarme do AlarmKit (senão, uma notificação).
        var isAlarm = false

        var isPaused: Bool { pausedRemaining != nil }

        func remaining(at date: Date) -> TimeInterval { pausedRemaining ?? max(0, end.timeIntervalSince(date)) }
    }

    /// Estado de um alarme, para acertar a lista com o que se passou fora da app.
    nonisolated enum AlarmPhase: Sendable {
        case scheduled, countdown, paused, alerting
    }

    private(set) var timers: [ActiveTimer] = []
    private var observing = false

    private init() {
        timers = Self.load()
    }

    func start(_ duration: StepAnalysis.Duration, label: String, recipeTitle: String,
               recipeID: UUID? = nil, stepID: UUID? = nil) {
        let timer = ActiveTimer(label: label, recipeTitle: recipeTitle, recipeID: recipeID, stepID: stepID,
                                end: .now.addingTimeInterval(TimeInterval(duration.seconds)))
        timers.append(timer)
        save()
        Task { await schedule(timer) }
    }

    func cancel(_ timer: ActiveTimer) {
        timers.removeAll { $0.id == timer.id }
        save()
        if timer.isAlarm { try? AlarmManager.shared.cancel(id: timer.id) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(timer)])
    }

    /// Temporizador a correr para um passo (e a duração), se houver.
    func timer(forStep stepID: UUID, duration: StepAnalysis.Duration) -> ActiveTimer? {
        timers.first { $0.stepID == stepID && $0.label.hasSuffix(duration.label) }
    }

    // MARK: Alarmes

    /// Acompanha os alarmes (parar, mais 1 min, pausar na Live Activity). Chamado uma vez, ao abrir a app.
    func observeAlarms() async {
        guard !observing, TimerAlarms.isEnabled else { return }
        observing = true
        if let alarms = try? AlarmManager.shared.alarms { apply(alarms) }
        for await alarms in AlarmManager.shared.alarmUpdates {
            apply(alarms)
        }
    }

    private func apply(_ alarms: [Alarm]) {
        var phases: [UUID: AlarmPhase] = [:]
        for alarm in alarms {
            switch alarm.state {
            case .countdown: phases[alarm.id] = .countdown
            case .paused: phases[alarm.id] = .paused
            case .alerting: phases[alarm.id] = .alerting
            default: phases[alarm.id] = .scheduled
            }
        }
        let updated = Self.reconcile(timers, with: phases, now: .now)
        if updated != timers {
            timers = updated
            save()
        }
    }

    /// Acerta os temporizadores com o estado dos alarmes:
    /// sem alarme (parado) sai da lista; em pausa guarda o que falta; ao continuar volta a contar;
    /// a contar depois do fim é o "Mais 1 min"; a tocar fica em "Terminou".
    nonisolated static func reconcile(_ timers: [ActiveTimer], with phases: [UUID: AlarmPhase], now: Date) -> [ActiveTimer] {
        timers.compactMap { timer in
            guard timer.isAlarm else { return timer }
            guard let phase = phases[timer.id] else { return nil }
            var timer = timer
            switch phase {
            case .paused:
                if timer.pausedRemaining == nil { timer.pausedRemaining = max(0, timer.end.timeIntervalSince(now)) }
            case .countdown:
                if let remaining = timer.pausedRemaining {
                    timer.end = now.addingTimeInterval(remaining)
                    timer.pausedRemaining = nil
                } else if timer.end <= now {
                    timer.end = now.addingTimeInterval(snoozeSeconds)
                }
            case .alerting:
                timer.pausedRemaining = nil
                if timer.end > now { timer.end = now }
            case .scheduled:
                break
            }
            return timer
        }
    }

    private func schedule(_ timer: ActiveTimer) async {
        if await TimerAlarms.authorize() {
            do {
                try await TimerAlarms.schedule(timer)
                if let index = timers.firstIndex(where: { $0.id == timer.id }) {
                    timers[index].isAlarm = true
                    save()
                } else {
                    // Parado entretanto.
                    try? AlarmManager.shared.cancel(id: timer.id)
                }
                return
            } catch {
                // Sem alarme: fica a notificação.
            }
        }
        await scheduleNotification(timer)
    }

    // MARK: Notificações (sem alarmes)

    private static func identifier(_ timer: ActiveTimer) -> String { "timer-\(timer.id.uuidString)" }

    private func scheduleNotification(_ timer: ActiveTimer) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Temporizador terminado"
        content.body = "\(timer.label) · \(timer.recipeTitle)"
        content.sound = .default
        let interval = max(1, timer.end.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.identifier(timer), content: content, trigger: trigger))
    }

    // MARK: Guardar

    private func save() {
        guard let data = try? JSONEncoder().encode(timers) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Ao abrir: os temporizadores com notificação que acabaram há mais de 30 minutos já não interessam.
    private static func load() -> [ActiveTimer] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ActiveTimer].self, from: data) else { return [] }
        let cutoff = Date.now.addingTimeInterval(-30 * 60)
        return saved.filter { $0.isAlarm || $0.end > cutoff }
    }

    /// "4:59" ou "1:02:30".
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

/// Alarmes do AlarmKit para os temporizadores.
enum TimerAlarms {
    typealias Configuration = AlarmManager.AlarmConfiguration<CookingTimerMetadata>

    /// Nos testes e nas capturas do CI ficam as notificações (sem o pedido de autorização a meio).
    static var isEnabled: Bool { !ScreenshotMode.flag("screenshots") }

    static var state: AlarmManager.AuthorizationState { AlarmManager.shared.authorizationState }

    /// Pede autorização na primeira vez; devolve se os alarmes podem ser usados.
    static func authorize() async -> Bool {
        guard isEnabled else { return false }
        switch state {
        case .authorized: return true
        case .notDetermined: return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
        default: return false
        }
    }

    static func schedule(_ timer: CookingTimers.ActiveTimer) async throws {
        let title = LocalizedStringResource(stringLiteral: "\(timer.recipeTitle) · \(timer.label)")
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(text: "Parar", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: "Mais 1 min", textColor: .white, systemImageName: "plus"),
            secondaryButtonBehavior: .countdown
        )
        let countdown = AlarmPresentation.Countdown(
            title: title,
            pauseButton: AlarmButton(text: "Pausar", textColor: .orange, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: "Em pausa",
            resumeButton: AlarmButton(text: "Continuar", textColor: .orange, systemImageName: "play.fill")
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: paused),
            metadata: CookingTimerMetadata(label: timer.label, recipeTitle: timer.recipeTitle,
                                           recipeID: timer.recipeID, stepID: timer.stepID),
            tintColor: Color.orange
        )
        let seconds = max(1, timer.end.timeIntervalSinceNow)
        let configuration = Configuration(
            countdownDuration: Alarm.CountdownDuration(preAlert: seconds, postAlert: CookingTimers.snoozeSeconds),
            schedule: nil,
            attributes: attributes
        )
        _ = try await AlarmManager.shared.schedule(id: timer.id, configuration: configuration)
    }
}

// MARK: - À espera (congelador, frigorífico, repouso)

/// "Congelei agora": marca o início da espera e avisa quando a receita está pronta.
enum WaitReminder {
    private static func identifier(_ recipe: Recipe) -> String { "wait-\(recipe.id.uuidString)" }

    /// Quando fica pronta (início da espera + tempo de espera).
    static func readyDate(of recipe: Recipe) -> Date? {
        recipe.frozenAt.map { $0.addingTimeInterval(TimeInterval(recipe.waitMinutes * 60)) }
    }

    static func isReady(_ recipe: Recipe, now: Date = .now) -> Bool {
        readyDate(of: recipe).map { $0 <= now } ?? false
    }

    static func start(_ recipe: Recipe) {
        recipe.frozenAt = .now
        Task { await schedule(recipe) }
    }

    static func cancel(_ recipe: Recipe) {
        recipe.frozenAt = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(recipe)])
    }

    /// Terminou a espera e a receita foi feita: conta como "Fiz esta receita".
    static func finish(_ recipe: Recipe) {
        cancel(recipe)
        recipe.cookedDates.append(.now)
        CookingProgress.clear(for: recipe.id)
    }

    private static func schedule(_ recipe: Recipe) async {
        guard let ready = readyDate(of: recipe), ready > .now else { return }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        switch recipe.waitKind {
        case .freezer?:
            content.title = "\(recipe.title): pronto a processar"
            content.body = "A base já está congelada há \(Format.minutes(recipe.waitMinutes))."
        case .fridge?:
            content.title = "\(recipe.title): pronto a comer"
            content.body = "Já passaram \(Format.minutes(recipe.waitMinutes)) no frigorífico."
        default:
            content.title = "\(recipe.title): pronto"
            content.body = "Já passaram \(Format.minutes(recipe.waitMinutes)) de repouso."
        }
        content.sound = .default
        content.userInfo = ["recipeID": recipe.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, ready.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier(recipe), content: content, trigger: trigger))
    }
}

extension WaitKind {
    /// Botão para começar a espera.
    var startTitle: String {
        switch self {
        case .freezer: "Congelei agora"
        case .fridge: "Pus no frigorífico"
        case .rest: "Pus a repousar"
        }
    }

    /// Botão para terminar quando está pronta.
    var finishTitle: String {
        switch self {
        case .freezer: "Processei"
        case .fridge, .rest: "Já está feita"
        }
    }

    /// "No congelador", "No frigorífico", "A repousar".
    var waitingTitle: String {
        switch self {
        case .freezer: "No congelador"
        case .fridge: "No frigorífico"
        case .rest: "A repousar"
        }
    }
}

// MARK: - Notificações com a app aberta

/// Mostra as notificações (temporizadores, esperas) mesmo com a app aberta,
/// e abre a receita quando se toca no aviso de uma espera.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["recipeID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run { AppRouter.shared.open(id) }
    }
}

// MARK: - Ecrã aceso

/// Mantém o ecrã aceso enquanto alguma vista o pedir (receita a meio, modo cozinhar).
enum ScreenAwake {
    private static var holders: Set<String> = []

    static func set(_ holder: String, _ isOn: Bool) {
        if isOn { holders.insert(holder) } else { holders.remove(holder) }
        UIApplication.shared.isIdleTimerDisabled = !holders.isEmpty
    }
}
