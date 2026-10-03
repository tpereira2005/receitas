import AlarmKit
import SwiftUI

/// Definições → Temporizadores: se tocam como alarme (AlarmKit) ou só com notificação.
struct TimersSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var state = TimerAlarms.state

    /// Valor na linha das Definições.
    static var shortStatus: String {
        switch TimerAlarms.state {
        case .authorized: "Alarme"
        case .denied: "Notificação"
        default: "Por ativar"
        }
    }

    var body: some View {
        Form {
            Section {
                statusCard
            }
            .listSectionSpacing(.compact)

            switch state {
            case .notDetermined:
                Section {
                    Button("Ativar alarmes", systemImage: "alarm") {
                        Task {
                            _ = await TimerAlarms.authorize()
                            state = TimerAlarms.state
                        }
                    }
                }
            case .denied:
                Section {
                    Button("Abrir os Ajustes", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } footer: {
                    Text("Nos Ajustes da app Receitas, ativa os Alarmes e Temporizadores.")
                }
            default:
                EmptyView()
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tocar na contagem do ecrã bloqueado abre a receita. Quando o alarme toca, \"Mais 1 min\" dá mais um minuto.")
                    Text("Se as Live Activities estiverem desligadas nos Ajustes, o alarme toca na mesma, só sem a contagem.")
                    Text("O aviso do congelador continua a ser uma notificação normal.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            } header: {
                Text("Como funciona")
            }
        }
        .navigationTitle("Temporizadores")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { state = TimerAlarms.state }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state = TimerAlarms.state }
        }
    }

    private var statusCard: some View {
        let card: (symbol: String, color: Color, title: String, subtitle: String) = switch state {
        case .authorized:
            ("alarm.fill", .orange, "Tocam como um alarme",
             "Mesmo em silêncio ou num modo de foco, com a contagem no ecrã bloqueado e na Dynamic Island.")
        case .denied:
            ("bell.fill", .gray, "Só com notificação",
             "Sem autorização para alarmes, os temporizadores avisam com uma notificação, que não toca em silêncio.")
        default:
            ("alarm", .gray, "Alarmes por ativar",
             "Na primeira vez que iniciares um temporizador, a app pede autorização. Também podes ativar já.")
        }
        return SettingsStatusCard(symbol: card.symbol, color: card.color, title: card.title, subtitle: card.subtitle)
    }
}

#if DEBUG
/// Capturas do CI: desenha a Live Activity como no ecrã bloqueado (o simulador não a fotografa).
struct LiveActivityPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.16), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                // Dynamic Island pequena: a contagem não deve deixar espaço vazio à direita.
                HStack(spacing: 8) {
                    Image(systemName: "timer").foregroundStyle(.orange)
                    Spacer(minLength: 120)
                    CookingTimerCompactCountdown(display: .countdown(end: .now.addingTimeInterval(20)))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 14)
                .frame(height: 37)
                .background(.black, in: Capsule())
                .fixedSize()
                Text("9:41")
                    .font(.system(size: 88, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                Spacer()
                card(.countdown(end: .now.addingTimeInterval(272)), label: "Passo 8 · 3 min")
                card(.paused(remaining: 95), label: "Passo 3 · 7 min")
                card(.ringing, label: "Passo 5 · 2 min")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 40)
        }
        .environment(\.colorScheme, .dark)
    }

    private func card(_ display: CookingTimerDisplay, label: String) -> some View {
        CookingTimerLockScreenView(label: label, recipeTitle: "Panquecas de aveia", alarmID: UUID(), display: display)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
#endif
