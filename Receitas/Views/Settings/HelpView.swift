import SwiftUI

/// Um tema de "Como funciona": título, ícone e algumas frases curtas.
private struct HelpTopic: Identifiable {
    let symbol: String
    let color: Color
    let title: String
    let points: [String]
    var id: String { title }

    static let all: [HelpTopic] = [
        HelpTopic(symbol: "fork.knife", color: .green, title: "Receitas e calorias", points: [
            "Cada ingrediente vem da biblioteca de alimentos, por isso as calorias e os macros são calculados sozinhos, por dose ou da receita toda.",
            "No editor escolhes as doses, o nome das porções (dose, fatia…) e os tempos de preparação, confeção e espera.",
            "Na receita, muda o número de doses para ajustar os ingredientes. O peso aparece ao lado das medidas.",
        ]),
        HelpTopic(symbol: "basket.fill", color: .orange, title: "Alimentos e embalagens", points: [
            "No separador Alimentos, toca em + para criar um alimento ou ler uma embalagem.",
            "Ler embalagem: fotografa o rótulo e o Gemini (com a chave, nas Definições) ou o próprio iPhone tiram os valores; o Open Food Facts completa o que faltar. Revês tudo antes de guardar.",
            "Porções com nome (\"1 scoop = 30 g\") e o peso das colheres deixam-te usar essas medidas nas receitas.",
            "Mudar um alimento nunca altera as receitas sem perguntar.",
        ]),
        HelpTopic(symbol: "play.circle.fill", color: .blue, title: "Modo cozinhar e temporizadores", points: [
            "Na receita, toca em Cozinhar: um passo de cada vez, em letra grande, com os ingredientes desse passo.",
            "Quando um passo diz um tempo (\"forno durante 30 minutos\"), aparece ▶ 30 min. O temporizador avisa com uma notificação e fica à vista no Início e na receita.",
            "O ecrã não se apaga enquanto cozinhas, e os passos que marcas ficam guardados 12 horas.",
        ]),
        HelpTopic(symbol: "snowflake", color: .cyan, title: "Congelador e esperas", points: [
            "O tempo de espera (congelador, frigorífico ou repouso) aparece à parte e não conta para \"Até 20 min\".",
            "Nos gelados, toca em \"Congelei agora\": a app avisa quando a base está pronta a processar e mostra-a em \"No congelador\", no Início.",
        ]),
        HelpTopic(symbol: "line.3.horizontal.decrease.circle.fill", color: .indigo, title: "Organizar e encontrar", points: [
            "Categorias, coleções (alta proteína, até 400 kcal, até 20 min, favoritas), etiquetas e \"já fizeste?\" filtram as receitas, em Receitas e na Pesquisa.",
            "\"Fiz esta receita\" guarda o histórico e enche \"Feitas recentemente\", no Início.",
            "As receitas aparecem na pesquisa do iPhone (Spotlight) e há ações para a Siri e os Atalhos.",
        ]),
        HelpTopic(symbol: "externaldrive.fill", color: .teal, title: "Cópias de segurança", points: [
            "Nas Definições, ativa as cópias automáticas: uma por dia, numa pasta à escolha, com as fotografias.",
            "Também podes exportar e importar em JSON, ou restaurar uma cópia automática (só acrescenta, nunca substitui).",
            "O que apagas fica 30 dias em Apagadas recentemente, para poderes recuperar.",
        ]),
        HelpTopic(symbol: "clock.arrow.circlepath", color: .gray, title: "SideStore", points: [
            "Com uma conta gratuita, a app tem de ser renovada no SideStore a cada 7 dias. Se expirar, as receitas ficam guardadas.",
            "Numa automação dos Atalhos, põe \"Refresh All\" do SideStore e, logo a seguir, \"Assinatura renovada\" da app Receitas, para a data na app ficar certa.",
            "Em Definições → SideStore podes pedir um aviso na véspera de expirar.",
        ]),
    ]
}

/// "Como funciona", nas Definições: um guia curto de cada parte da app.
struct HowItWorksView: View {
    @State private var expanded: Set<String> = [HelpTopic.all[0].id]
    @State private var showingWelcome = false

    var body: some View {
        Form {
            Section {
                Button {
                    showingWelcome = true
                } label: {
                    SettingsRow(title: "Ver as boas-vindas", symbol: "hand.wave.fill", color: .pink)
                }
                .tint(.primary)
            }

            ForEach(HelpTopic.all) { topic in
                Section {
                    DisclosureGroup(isExpanded: binding(for: topic)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(topic.points, id: \.self) { point in
                                Text(point)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        // HStack em vez de Label: dentro de um Form, o Label ganharia o estilo das linhas.
                        HStack(spacing: 14) {
                            SettingsIcon(symbol: topic.symbol, color: topic.color)
                            Text(topic.title)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .listSectionSpacing(.compact)
        }
        .navigationTitle("Como funciona")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWelcome) {
            WelcomeView()
        }
    }

    private func binding(for topic: HelpTopic) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(topic.id) },
            set: { isOpen in
                if isOpen { expanded.insert(topic.id) } else { expanded.remove(topic.id) }
            }
        )
    }
}

/// Boas-vindas: aparecem na primeira vez que a app é aberta, numa instalação nova,
/// e podem ser vistas de novo em Definições → Como funciona.
struct WelcomeView: View {
    static let seenKey = "welcomeSeen"

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Page {
        let symbol: String?
        let color: Color
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(symbol: nil, color: .green, title: "Bem-vindo às Receitas",
             text: "As tuas receitas fit num só sítio, com as calorias e os macros de cada dose calculados sozinhos."),
        Page(symbol: "basket.fill", color: .orange, title: "Primeiro, os alimentos",
             text: "Guarda os alimentos com os valores do rótulo, ou lê a embalagem com a câmara. As receitas usam-nos para fazer as contas."),
        Page(symbol: "play.circle.fill", color: .blue, title: "Cozinhar passo a passo",
             text: "O modo cozinhar mostra um passo de cada vez, com temporizadores tirados do texto. Nos gelados, \"Congelei agora\" avisa quando estão prontos."),
        Page(symbol: "externaldrive.fill", color: .teal, title: "Os teus dados a salvo",
             text: "Ativa as cópias de segurança automáticas nas Definições. O que apagas fica 30 dias em Apagadas recentemente. Em Definições → Como funciona tens o resto."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .toolbar {
                if !isLast {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Saltar") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if isLast {
                        dismiss()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(isLast ? "Começar" : "Seguinte")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    private func pageView(_ page: Page) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Group {
                    if let symbol = page.symbol {
                        SettingsIcon(symbol: symbol, color: page.color, size: 96)
                    } else {
                        Image("app.mark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.top, 48)

                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.text)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            // Espaço para os pontos das páginas não taparem o texto.
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity)
        }
    }
}
