import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Cópias de segurança

/// Cópias automáticas, exportar e importar num só sítio. Desativar fica à parte, no fim.
struct BackupSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: Recipe.notDeleted) private var recipes: [Recipe]
    @Query(filter: Food.notDeleted) private var foods: [Food]

    private let autoBackup = AutoBackup.shared
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isChoosingFolder = false
    @State private var confirmDisable = false
    @State private var message: String?

    private var backupFilename: String {
        "Receitas-\(Date.now.formatted(.iso8601.year().month().day()))"
    }

    var body: some View {
        Form {
            AutoBackupSection(onChooseFolder: { isChoosingFolder = true })

            Section {
                Button("Exportar cópia", systemImage: "square.and.arrow.up", action: export)
                    .disabled(recipes.isEmpty && foods.isEmpty)
                Button("Importar cópia", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                if autoBackup.isEnabled, autoBackup.folderName != nil {
                    NavigationLink {
                        AutoBackupRestoreView()
                    } label: {
                        Label("Restaurar uma cópia automática", systemImage: "clock.arrow.circlepath")
                    }
                }
            } header: {
                Text("Ficheiro")
            } footer: {
                Text("Exporta antes de mudar de iPhone. Importar e restaurar só acrescentam o que falta na app.")
            }

            if autoBackup.isEnabled, autoBackup.folderName != nil {
                Section {
                    Button(role: .destructive) {
                        confirmDisable = true
                    } label: {
                        Label("Desativar cópias automáticas", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                    .confirmationDialog("Desativar as cópias automáticas?", isPresented: $confirmDisable, titleVisibility: .visible) {
                        Button("Desativar", role: .destructive) {
                            withAnimation(.snappy) { autoBackup.disable() }
                        }
                    } message: {
                        Text("As cópias que já estão na pasta não são apagadas.")
                    }
                }
            }
        }
        .navigationTitle("Cópias de segurança")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: autoBackup.folderName)
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .json, defaultFilename: backupFilename) { result in
            if case .success = result {
                Haptics.success()
                message = "Cópia de segurança exportada."
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .background {
            // Um segundo seletor no mesmo modificador não abre; fica numa vista à parte.
            Color.clear.fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                handleFolder(result)
            }
        }
        .alert("Cópia de segurança", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try RecipeBackup.encode(recipes: recipes, foods: foods))
            isExporting = true
        } catch {
            message = "Não foi possível exportar: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let restored = try RecipeBackup.restore(from: data, into: context)
                if restored.recipes == 0 && restored.foods == 0 {
                    message = "Tudo o que está neste ficheiro já existe na app."
                } else {
                    Haptics.success()
                    let recipesText = Format.recipes(restored.recipes)
                    let foodsText = restored.foods == 1 ? "1 alimento" : "\(restored.foods) alimentos"
                    message = "Importados: \(recipesText) e \(foodsText)."
                }
            } catch {
                message = "Este ficheiro não parece ser uma cópia de segurança válida."
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func handleFolder(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try autoBackup.setFolder(url)
                // O cartão de estado mostra o resultado da primeira cópia; não é preciso um alerta.
                Task {
                    if await autoBackup.run(context: context, force: true) {
                        Haptics.success()
                    } else {
                        Haptics.warning()
                    }
                }
            } catch {
                message = "Não foi possível usar esta pasta: \(error.localizedDescription)"
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

// MARK: - Restaurar uma cópia automática

/// As cópias automáticas da pasta, com a data. Restaurar acrescenta o que falta (nunca apaga nem substitui).
struct AutoBackupRestoreView: View {
    @Environment(\.modelContext) private var context
    private let autoBackup = AutoBackup.shared

    @State private var backups: [AutoBackup.StoredBackup]?
    @State private var loadError: String?
    @State private var restoring: AutoBackup.StoredBackup?
    @State private var working = false
    @State private var message: String?

    var body: some View {
        List {
            if let backups {
                Section {
                    ForEach(backups) { backup in
                        Button {
                            restoring = backup
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.clock")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(backup.date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalizedFirst)
                                        .foregroundStyle(.primary)
                                    Text("\(backup.date.formatted(date: .omitted, time: .shortened)) · \(backup.size.formatted(.byteCount(style: .file)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                if working, restoring == backup {
                                    ProgressView()
                                }
                            }
                        }
                        .tint(.primary)
                        .disabled(working)
                    }
                } footer: {
                    if !backups.isEmpty {
                        Text("Restaurar acrescenta as receitas e os alimentos que faltam na app. O que já tens fica como está.")
                    }
                }
            }
        }
        .overlay {
            if let loadError {
                ContentUnavailableView("Não foi possível ler a pasta", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if backups == nil {
                ProgressView()
            } else if backups?.isEmpty == true {
                ContentUnavailableView("Ainda sem cópias", systemImage: "doc.badge.clock",
                                       description: Text("A primeira cópia automática aparece aqui."))
            }
        }
        .navigationTitle("Cópias automáticas")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .confirmationDialog(
            "Restaurar esta cópia?",
            isPresented: Binding(get: { restoring != nil && !working }, set: { if !$0 && !working { restoring = nil } }),
            titleVisibility: .visible,
            presenting: restoring
        ) { backup in
            Button("Acrescentar o que falta") { Task { await restore(backup) } }
        } message: { backup in
            Text("Cópia de \(backup.date.formatted(date: .long, time: .shortened)). Nada do que tens na app é apagado nem substituído.")
        }
        .alert("Restaurar", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func load() async {
        switch await autoBackup.storedBackups() {
        case .success(let list): backups = list
        case .failure(let error): loadError = error.message
        }
    }

    private func restore(_ backup: AutoBackup.StoredBackup) async {
        working = true
        defer {
            working = false
            restoring = nil
        }
        switch await autoBackup.readBackup(backup) {
        case .success(let data):
            do {
                let restored = try RecipeBackup.restore(from: data, into: context)
                if restored.recipes == 0 && restored.foods == 0 {
                    message = "A app já tem tudo o que está nesta cópia."
                } else {
                    Haptics.success()
                    let foodsText = restored.foods == 1 ? "1 alimento" : "\(restored.foods) alimentos"
                    message = "Recuperados: \(Format.recipes(restored.recipes)) e \(foodsText)."
                }
            } catch {
                message = "Esta cópia não pôde ser lida."
            }
        case .failure(let error):
            message = error.message
        }
    }
}

// MARK: - Leitura de embalagens

struct PackageReadingSettingsView: View {
    var body: some View {
        Form {
            GeminiKeySection()
        }
        .navigationTitle("Leitura de embalagens")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SideStore

/// Validade da assinatura e aviso na véspera.
struct SideStoreSettingsView: View {
    @AppStorage(ExpiryReminder.enabledKey) private var expiryReminder = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                statusCard
            }
            .listSectionSpacing(.compact)

            if AppSigning.expirationDate != nil {
                Section {
                    Toggle(isOn: Binding(
                        get: { expiryReminder },
                        set: { isOn in
                            if isOn {
                                Task {
                                    if !(await ExpiryReminder.enable()) {
                                        message = "Para receberes o aviso, permite as notificações da app Receitas nos Ajustes do iPhone."
                                    }
                                }
                            } else {
                                ExpiryReminder.disable()
                            }
                        }
                    )) {
                        Label("Avisar na véspera", systemImage: "bell.badge")
                    }
                    Button("Abrir SideStore", systemImage: "arrow.up.forward.app") { AppSigning.openSideStore() }
                } footer: {
                    Text("Com uma conta gratuita, renova a cada 7 dias. Se expirar, as receitas ficam guardadas.\n\nO SideStore renova sem reinstalar a app: para esta data acompanhar as renovações, o teu atalho deve correr a ação \"Assinatura renovada\" da app Receitas logo a seguir a renovar.")
                }
            }
        }
        .navigationTitle("SideStore")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notificações", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var statusCard: some View {
        let card: (symbol: String, color: Color, title: String, subtitle: String) = {
            guard let expiration = AppSigning.expirationDate else {
                return ("hammer.fill", .gray, "Instalação de desenvolvimento", "Esta instalação não tem data de validade.")
            }
            let date = expiration.formatted(.dateTime.day().month(.wide))
            if AppSigning.isExpiringSoon {
                return ("exclamationmark.triangle.fill", .orange, "Expira \(AppSigning.expiryText)", "Renova no SideStore até \(date).")
            }
            return ("checkmark.seal.fill", .green, "Válida até \(date)", "A app expira \(AppSigning.expiryText).")
        }()
        return SettingsStatusCard(symbol: card.symbol, color: card.color, title: card.title, subtitle: card.subtitle)
    }
}
