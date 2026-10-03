import SwiftUI
import SwiftData

/// Páginas das Definições.
enum SettingsPage: String, Hashable {
    case backups = "copias"
    case packageReading = "gemini"
    case tags = "etiquetas"
    case sideStore = "sidestore"
    case trash = "apagadas"
    case restore = "restaurar"
    case help = "ajuda"
    case timers = "temporizadores"
}

/// Página principal das Definições: um resumo da app e uma linha por área, com o estado à direita.
/// O detalhe de cada área fica numa página própria.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: Recipe.notDeleted) private var recipes: [Recipe]
    @Query(filter: Food.notDeleted) private var foods: [Food]
    @Query(filter: #Predicate<Recipe> { $0.deletedAt != nil }) private var deletedRecipes: [Recipe]
    @Query(filter: #Predicate<Food> { $0.deletedAt != nil }) private var deletedFoods: [Food]
    @AppStorage(TagLibrary.catalogKey) private var tagCatalog = ""

    /// Capturas do CI: abre logo numa das páginas.
    @State private var path: [SettingsPage] = ScreenshotMode.string("screenshotSettingsPage")
        .flatMap(SettingsPage.init(rawValue:)).map { [$0] } ?? []
    @State private var geminiActive = GeminiKeySection.currentKey() != nil
    private let backup = AutoBackup.shared

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    header
                }

                if AppSigning.isExpiringSoon {
                    Section {
                        expiryBanner
                    }
                }

                Section("Dados") {
                    NavigationLink(value: SettingsPage.backups) {
                        SettingsRow(title: "Cópias de segurança", symbol: "externaldrive.fill", color: .blue,
                                    value: backupValue.text, valueColor: backupValue.color)
                    }
                    NavigationLink(value: SettingsPage.packageReading) {
                        SettingsRow(title: "Leitura de embalagens", symbol: "sparkles", color: .purple,
                                    value: geminiActive ? "Gemini" : "Básica")
                    }
                    NavigationLink(value: SettingsPage.trash) {
                        SettingsRow(title: "Apagadas recentemente", symbol: "trash.fill", color: .red,
                                    value: deletedCount == 0 ? nil : "\(deletedCount)")
                    }
                }

                Section("Biblioteca") {
                    NavigationLink(value: SettingsPage.tags) {
                        SettingsRow(title: "Etiquetas", symbol: "tag.fill", color: .orange,
                                    value: "\(TagLibrary.all(in: recipes, catalog: TagLibrary.decodeCatalog(tagCatalog)).count)")
                    }
                }

                Section("App") {
                    NavigationLink(value: SettingsPage.timers) {
                        SettingsRow(title: "Temporizadores", symbol: "timer", color: .orange,
                                    value: TimersSettingsView.shortStatus)
                    }
                    NavigationLink(value: SettingsPage.sideStore) {
                        SettingsRow(title: "SideStore", symbol: "clock.arrow.circlepath", color: .gray,
                                    value: sideStoreValue,
                                    valueColor: AppSigning.isExpiringSoon ? .orange : .secondary)
                    }
                    NavigationLink(value: SettingsPage.help) {
                        SettingsRow(title: "Como funciona", symbol: "questionmark.circle.fill", color: .pink)
                    }
                    if let url = URL(string: "https://github.com/tpereira2005/receitas/blob/main/docs/versoes.md") {
                        Link(destination: url) {
                            SettingsRow(title: "Histórico de versões", symbol: "list.bullet.rectangle.fill", color: .brown)
                        }
                        // Sem isto, o título ficava com a cor de destaque, como um botão.
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Definições")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") { dismiss() }
                }
            }
            .navigationDestination(for: SettingsPage.self) { page in
                switch page {
                case .backups: BackupSettingsView()
                case .packageReading: PackageReadingSettingsView()
                case .tags: TagManagerView()
                case .sideStore: SideStoreSettingsView()
                case .trash: RecentlyDeletedView()
                case .restore: AutoBackupRestoreView()
                case .help: HowItWorksView()
                case .timers: TimersSettingsView()
                }
            }
            // Ao voltar da página da leitura de embalagens, a chave pode ter mudado.
            .onAppear { geminiActive = GeminiKeySection.currentKey() != nil }
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 16) {
            Image("app.mark")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Receitas")
                    .font(.title2.weight(.bold))
                // Numa só linha: primeiro tal como está, depois com letra um pouco menor e,
                // se ainda não couber, com "fav." (só com texto muito grande passa a duas linhas).
                ViewThatFits(in: .horizontal) {
                    Text(summary).font(.subheadline).lineLimit(1)
                    Text(summary).font(.footnote).lineLimit(1)
                    Text(summary(short: true)).font(.footnote).lineLimit(1)
                    Text(summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
                Text("Versão \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var summary: String { summary(short: false) }

    private func summary(short: Bool) -> String {
        let favorites = recipes.filter(\.isFavorite).count
        var parts = [Format.recipes(recipes.count)]
        if favorites > 0 {
            parts.append(short ? "\(favorites) fav." : favorites == 1 ? "1 favorita" : "\(favorites) favoritas")
        }
        parts.append(foods.count == 1 ? "1 alimento" : "\(foods.count) alimentos")
        return parts.joined(separator: " · ")
    }

    private var deletedCount: Int { deletedRecipes.count + deletedFoods.count }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Aviso do SideStore

    private var expiryBanner: some View {
        HStack(spacing: 14) {
            SettingsIcon(symbol: "exclamationmark.triangle.fill", color: .orange, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Renova no SideStore")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("A app expira \(AppSigning.expiryText).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Abrir") { AppSigning.openSideStore() }
                .buttonStyle(.glassProminent)
                .tint(.orange)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Estados

    private var backupValue: (text: String, color: Color) {
        guard backup.isEnabled, backup.folderName != nil else { return ("Desativadas", .secondary) }
        if backup.isRunning { return ("A copiar…", .secondary) }
        if backup.lastError != nil { return ("Com erro", .orange) }
        return ("Ativas", .secondary)
    }

    private var sideStoreValue: String {
        switch AppSigning.daysLeft {
        case nil: "Sem data"
        case 0?: "Expira hoje"
        case 1?: "Expira amanhã"
        case let days?: "Faltam \(days) dias"
        }
    }
}
