import CoreSpotlight
import UserNotifications
import SwiftUI
import SwiftData

@main
struct ReceitasApp: App {
    private let container: Result<ModelContainer, Error>

    init() {
        container = DataStore.shared
        // Temporizadores e esperas avisam também com a app aberta.
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                DataErrorView(error: error)
            }
        }
    }
}

enum AppTab: String, Hashable {
    case home, recipes, foods, search
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didSeedSamples") private var didSeedSamples = false
    @AppStorage("dataVersion") private var dataVersion = 0
    @AppStorage(WelcomeView.seenKey) private var welcomeSeen = false
    @State private var showingWelcome = false
    private let router = AppRouter.shared

    @State private var selectedTab = AppTab(rawValue: ScreenshotMode.string("tab") ?? "") ?? .home
    @State private var searchText = ScreenshotMode.string("screenshotSearch") ?? ""

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Início", systemImage: "house", value: AppTab.home) {
                HomeView()
            }
            Tab("Receitas", systemImage: "fork.knife", value: AppTab.recipes) {
                RecipesView()
            }
            Tab("Alimentos", systemImage: "basket", value: AppTab.foods) {
                FoodsView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView(searchText: $searchText)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            prepareData()
            updateSystemIntegration()
            await ExpiryReminder.reschedule()
            await AutoBackup.shared.runIfDue(context: context)
        }
        // Alarmes dos temporizadores: parar, mais 1 min e pausar fora da app.
        .task { await CookingTimers.shared.observeAlarms() }
        .onOpenURL { url in
            if let id = AppRouter.recipeID(from: url) { router.open(id) }
        }
        #if DEBUG
        .overlay {
            if ScreenshotMode.flag("screenshotLiveActivity") { LiveActivityPreview() }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Pode ter havido uma renovação pelo atalho enquanto a app estava fechada.
                SigningState.shared.refresh()
                Task { await ExpiryReminder.reschedule() }
            }
            if phase == .background {
                updateSystemIntegration()
                Task { await AutoBackup.shared.runIfDue(context: context) }
            }
        }
        // Tocar numa receita no Spotlight abre-a no Início.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = SpotlightIndex.recipeID(from: activity) { router.open(id) }
        }
        .onChange(of: router.pendingRecipeID) { _, id in
            if id != nil { selectedTab = .home }
        }
        .sheet(isPresented: $showingWelcome) {
            welcomeSeen = true
        } content: {
            WelcomeView()
        }
    }

    /// Spotlight e parâmetros dos Atalhos/Siri com as receitas atuais.
    private func updateSystemIntegration() {
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>(predicate: Recipe.notDeleted))) ?? []
        SpotlightIndex.update(with: recipes)
        ReceitasShortcuts.updateAppShortcutParameters()
    }

    private func prepareData() {
        // Boas-vindas: só numa instalação nova (quem já usava a app não as vê).
        #if DEBUG
        // Nas capturas e nos testes do CI (compilação de desenvolvimento) só aparecem quando pedidas.
        if ScreenshotMode.flag("screenshotWelcome") { showingWelcome = true }
        #else
        if !welcomeSeen {
            if didSeedSamples {
                welcomeSeen = true
            } else {
                showingWelcome = true
            }
        }
        #endif
        if !didSeedSamples {
            didSeedSamples = true
            let count = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
            if count == 0 {
                // Instalação nova: os alimentos e as receitas de origem, com imagens.
                BaseContent.insertMissingFoods(into: context)
                BaseContent.insertMissingRecipes(into: context)
            }
        }
        if dataVersion < DataMigration.currentVersion {
            DataMigration.migrate(context, from: dataVersion)
            dataVersion = DataMigration.currentVersion
        }
        // O que está em "Apagadas recentemente" há mais de 30 dias sai de vez.
        RecentlyDeleted.purge(context)
    }
}

/// Mostrado se a base de dados não abrir (por exemplo, uma migração falhada).
/// Os dados anteriores continuam guardados na cópia de proteção.
struct DataErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Não foi possível abrir as receitas", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Os teus dados não foram apagados: existe uma cópia de proteção feita antes desta atualização. Instala a versão anterior no SideStore ou contacta o suporte da app.\n\n\(error.localizedDescription)")
        }
    }
}

/// Opções usadas apenas pelas capturas de ecrã automáticas do CI (builds de desenvolvimento).
/// Na versão instalada pelo SideStore não têm qualquer efeito.
enum ScreenshotMode {
    static func flag(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }

    static func string(_ key: String) -> String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: key)
        #else
        nil
        #endif
    }
}
