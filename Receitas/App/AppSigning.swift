import Foundation
import Observation
import UserNotifications
import UIKit

/// Validade da assinatura da app (SideStore com conta gratuita: 7 dias).
/// Quando expira, a app deixa de abrir até ser renovada no SideStore; os dados continuam guardados.
enum AppSigning {
    /// Data de expiração do perfil que veio dentro da app (`embedded.mobileprovision`); `nil` no simulador.
    /// Só muda quando a app é instalada de novo: ao renovar, o SideStore instala um perfil novo no
    /// sistema mas não toca neste, por isso a renovação é registada à parte (`SigningState`).
    private static let embeddedExpirationDate: Date? = {
        #if DEBUG
        if let days = ScreenshotMode.string("screenshotExpiryDays").flatMap(Double.init) {
            return Date.now.addingTimeInterval(days * 86_400)
        }
        #endif
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return parseExpiration(from: data)
    }()

    /// Data de expiração mais recente que se conhece: a do perfil da app ou a da última renovação registada.
    static var expirationDate: Date? {
        #if DEBUG
        if ScreenshotMode.string("screenshotExpiryDays") != nil { return embeddedExpirationDate }
        #endif
        return effectiveExpiration(embedded: embeddedExpirationDate, renewedUntil: SigningState.shared.renewedUntil)
    }

    /// Numa instalação sem perfil (desenvolvimento) não há validade, mesmo que haja renovações registadas.
    nonisolated static func effectiveExpiration(embedded: Date?, renewedUntil: Date?) -> Date? {
        guard let embedded else { return nil }
        guard let renewedUntil else { return embedded }
        return max(embedded, renewedUntil)
    }

    /// O perfil é um plist assinado (CMS); o XML está no meio dos bytes.
    nonisolated static func parseExpiration(from data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }

    /// Dias (arredondados para cima) até expirar.
    static var daysLeft: Int? {
        guard let expirationDate else { return nil }
        let seconds = expirationDate.timeIntervalSince(SigningState.shared.now)
        return max(0, Int((seconds / 86_400).rounded(.up)))
    }

    /// Mostra o aviso no Início nos últimos 2 dias.
    static var isExpiringSoon: Bool { (daysLeft ?? .max) <= 2 }

    static var expiryText: String {
        switch daysLeft {
        case nil: "sem data"
        case 0?: "hoje"
        case 1?: "amanhã"
        case let days?: "daqui a \(days) dias"
        }
    }

    static func openSideStore() {
        if let url = URL(string: "sidestore://") { UIApplication.shared.open(url) }
    }
}

/// Renovações registadas pelo atalho ("Assinatura renovada") e a hora usada nas contas dos dias.
/// É observável para o Início e as Definições se atualizarem quando a app volta ao ecrã.
@Observable
final class SigningState {
    static let shared = SigningState()
    static let renewedUntilKey = "signingRenewedUntil"
    /// Validade de cada renovação com uma conta gratuita.
    static let validity: TimeInterval = 7 * 86_400

    private(set) var renewedUntil: Date?
    private(set) var now = Date.now

    private init() {
        renewedUntil = UserDefaults.standard.object(forKey: Self.renewedUntilKey) as? Date
    }

    /// O SideStore acabou de renovar: a app fica válida por mais 7 dias a partir de agora.
    func recordRenewal(at date: Date = .now) {
        let until = date.addingTimeInterval(Self.validity)
        UserDefaults.standard.set(until, forKey: Self.renewedUntilKey)
        renewedUntil = until
        now = date
    }

    /// Volta a ler a renovação (o atalho pode ter corrido com a app fechada) e a hora atual.
    func refresh() {
        renewedUntil = UserDefaults.standard.object(forKey: Self.renewedUntilKey) as? Date
        now = .now
    }
}

/// Notificação na véspera de a assinatura expirar (opcional, nas Definições).
enum ExpiryReminder {
    static let enabledKey = "expiryReminderEnabled"
    private static let identifier = "sidestore-expiry"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Pede autorização (na primeira vez) e agenda o aviso; devolve se ficou ativo.
    static func enable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        UserDefaults.standard.set(granted, forKey: enabledKey)
        if granted { await reschedule() }
        return granted
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Volta a agendar com a data atual (a data muda sempre que a app é renovada).
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard isEnabled, let expiration = AppSigning.expirationDate else { return }
        // Na véspera, às 10:00 (ou daqui a 1 minuto, se isso já passou e ainda não expirou).
        let calendar = Calendar.current
        let eve = calendar.date(byAdding: .day, value: -1, to: expiration) ?? expiration
        var fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: eve) ?? eve
        if fireDate <= .now {
            guard expiration > .now.addingTimeInterval(3600) else { return }
            fireDate = .now.addingTimeInterval(60)
        }
        let content = UNMutableNotificationContent()
        content.title = "A app Receitas expira em breve"
        content.body = "Abre o SideStore e renova a app para continuares a usá-la. As tuas receitas ficam guardadas."
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) { _ in }
    }
}
