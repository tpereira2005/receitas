import AppIntents
import SwiftUI

/// O que a Live Activity de um temporizador mostra. Partilhado com a app para as capturas do CI
/// (o simulador não fotografa o ecrã bloqueado).
nonisolated enum CookingTimerDisplay: Equatable, Sendable {
    case countdown(end: Date)
    case paused(remaining: TimeInterval)
    case ringing

    var isPaused: Bool { if case .paused = self { true } else { false } }
}

/// Contagem: corre sozinha no ecrã bloqueado, sem a app ter de a atualizar.
struct CookingTimerCountdown: View {
    let display: CookingTimerDisplay

    var body: some View {
        switch display {
        case .countdown(let end):
            Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                .monospacedDigit()
        case .paused(let remaining):
            Text(Self.clock(remaining))
                .monospacedDigit()
        case .ringing:
            Text("Terminou")
        }
    }

    /// "4:59" ou "1:02:30".
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

/// Pausar/continuar e parar, ligados ao alarme pelo id.
struct CookingTimerButtons: View {
    let alarmID: UUID
    let display: CookingTimerDisplay

    var body: some View {
        HStack(spacing: 8) {
            if display != .ringing {
                if display.isPaused {
                    Button(intent: ResumeTimerIntent(alarmID: alarmID.uuidString)) {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Continuar")
                } else {
                    Button(intent: PauseTimerIntent(alarmID: alarmID.uuidString)) {
                        Image(systemName: "pause.fill")
                    }
                    .accessibilityLabel("Pausar")
                }
            }
            Button(intent: StopTimerIntent(alarmID: alarmID.uuidString)) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Parar")
        }
        .font(.title3.weight(.semibold))
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(.orange)
    }
}

/// Ecrã bloqueado: passo e receita à esquerda, contagem grande à direita, botões por baixo.
struct CookingTimerLockScreenView: View {
    let label: String
    let recipeTitle: String
    let alarmID: UUID
    let display: CookingTimerDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: display.isPaused ? "pause.circle.fill" : display == .ringing ? "bell.circle.fill" : "timer.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.headline)
                        .lineLimit(1)
                    Text(display.isPaused ? "Em pausa · \(recipeTitle)" : recipeTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                CookingTimerCountdown(display: display)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(display == .ringing ? .red : .orange)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            HStack {
                Spacer()
                CookingTimerButtons(alarmID: alarmID, display: display)
            }
        }
        .padding(16)
    }
}
