import SwiftUI

/// Temporizadores a correr, em cápsulas com a contagem: no modo cozinhar, no fundo da receita e no Início.
/// Tocar numa cápsula (no Início) abre a receita; o X para o temporizador.
struct ActiveTimersBar: View {
    /// Só os desta receita (`nil` = todos).
    var recipeID: UUID?
    /// Mostra o nome da receita (no Início, onde podem estar várias).
    var showsRecipe = false
    var onOpen: ((UUID) -> Void)?

    private let timers = CookingTimers.shared

    private var visible: [CookingTimers.ActiveTimer] {
        guard let recipeID else { return timers.timers }
        return timers.timers.filter { $0.recipeID == recipeID }
    }

    var body: some View {
        if !visible.isEmpty {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visible) { timer in
                            capsule(timer, now: context.date)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .scrollClipDisabled()
            }
            .sensoryFeedback(.warning, trigger: visible.count)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func capsule(_ timer: CookingTimers.ActiveTimer, now: Date) -> some View {
        let remaining = timer.remaining(at: now)
        return HStack(spacing: 10) {
            Button {
                if let id = timer.recipeID { onOpen?(id) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: timer.isPaused ? "pause.fill" : remaining > 0 ? "timer" : "bell.fill")
                        .foregroundStyle(remaining > 0 ? Color.orange : Color.red)
                        .symbolEffect(.bounce, options: .repeating, isActive: remaining == 0)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(remaining > 0 ? CookingTimers.clock(remaining) : "Terminou")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.primary)
                        Text((timer.isPaused ? "Em pausa · " : "") + (showsRecipe ? "\(timer.recipeTitle) · \(timer.label)" : timer.label))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onOpen == nil)

            Button("Parar", systemImage: "xmark") {
                withAnimation(.snappy) { timers.cancel(timer) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Temporizador \(timer.label), \(remaining > 0 ? "faltam \(CookingTimers.clock(remaining))" : "terminou")")
    }
}

/// Botão de temporizador num passo ("▶ 30 min"); enquanto conta, mostra o tempo que falta.
struct StepTimerButton: View {
    let duration: StepAnalysis.Duration
    let stepID: UUID
    let stepNumber: Int
    let recipe: Recipe
    /// Maior, no modo cozinhar.
    var large = false

    private var font: Font { large ? .headline : .subheadline.weight(.semibold) }

    private let timers = CookingTimers.shared

    var body: some View {
        if let running = timers.timer(forStep: stepID, duration: duration) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = running.remaining(at: context.date)
                Button {
                    withAnimation(.snappy) { timers.cancel(running) }
                } label: {
                    Label(remaining > 0 ? CookingTimers.clock(remaining) : "Terminou",
                          systemImage: remaining > 0 ? "stop.fill" : "bell.fill")
                        .font(font.monospacedDigit())
                        .padding(.vertical, large ? 4 : 0)
                }
                .buttonStyle(.glassProminent)
                .tint(remaining > 0 ? .orange : .red)
                .accessibilityLabel(remaining > 0 ? "Parar temporizador, faltam \(CookingTimers.clock(remaining))" : "Parar temporizador")
            }
        } else {
            Button {
                withAnimation(.snappy) {
                    timers.start(duration, label: "Passo \(stepNumber) · \(duration.label)", recipeTitle: recipe.title,
                                 recipeID: recipe.id, stepID: stepID)
                }
            } label: {
                Label(large ? "Iniciar \(duration.label)" : duration.label, systemImage: large ? "timer" : "play.fill")
                    .font(font)
                    .padding(.vertical, large ? 4 : 0)
            }
            .buttonStyle(.glass)
            .tint(.orange)
            .accessibilityLabel("Iniciar temporizador de \(duration.label)")
        }
    }
}
