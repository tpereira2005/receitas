import AppIntents
import CoreSpotlight
import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers

/// Pedidos vindos de fora da app (Spotlight, Atalhos, Siri) para abrir uma receita.
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// Receita a abrir no Início assim que possível.
    var pendingRecipeID: UUID?

    func open(_ id: UUID) {
        pendingRecipeID = id
    }

    /// `receitas://receita/<id>` (Live Activity dos temporizadores).
    nonisolated static func recipeID(from url: URL) -> UUID? {
        guard url.scheme == "receitas", url.host() == "receita" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}

// MARK: - Spotlight

/// Põe as receitas na pesquisa do iPhone (Spotlight). Tocar num resultado abre a receita na app.
enum SpotlightIndex {
    static let domain = "receitas"
    private static let indexedKey = "spotlightIndexedIDs"

    static func update(with recipes: [Recipe]) {
        guard !ScreenshotMode.flag("screenshots") else { return }
        let items = recipes.map(item(for:))
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }

        // Tira do Spotlight as receitas que já não existem.
        let current = Set(recipes.map(\.id.uuidString))
        let previous = Set(UserDefaults.standard.stringArray(forKey: indexedKey) ?? [])
        let removed = Array(previous.subtracting(current))
        if !removed.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: removed) { _ in }
        }
        UserDefaults.standard.set(Array(current), forKey: indexedKey)
    }

    private static func item(for recipe: Recipe) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = recipe.title
        var details = [recipe.category.title]
        if recipe.calories > 0 { details.append("\(Int(recipe.calories.rounded())) kcal") }
        if recipe.protein > 0 { details.append("\(recipe.protein.cleanString) g proteína") }
        if let time = recipe.timeText { details.append(time) }
        attributes.contentDescription = details.joined(separator: " · ")
        attributes.keywords = [recipe.category.title] + recipe.tags + recipe.ingredients.map(\.name)
        attributes.thumbnailData = recipe.thumbnailData
        return CSSearchableItem(uniqueIdentifier: recipe.id.uuidString, domainIdentifier: domain, attributeSet: attributes)
    }

    /// Identificador da receita num resultado do Spotlight.
    static func recipeID(from activity: NSUserActivity) -> UUID? {
        (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init(uuidString:))
    }
}

// MARK: - Atalhos e Siri
//
// As intenções ficam isoladas no MainActor (o padrão da app): o `@Parameter` cria uma propriedade
// mutável que não pode ser `nonisolated`. A entidade e a pesquisa não têm wrappers e ficam `nonisolated`.

/// Uma receita, como aparece nos Atalhos e na Siri.
nonisolated struct RecipeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Receita"
    static let defaultQuery = RecipeEntityQuery()

    let id: UUID
    let title: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
}

nonisolated struct RecipeEntityQuery: EntityStringQuery {
    @MainActor
    private func recipes() -> [Recipe] {
        guard let container = try? DataStore.shared.get() else { return [] }
        let descriptor = FetchDescriptor<Recipe>(predicate: Recipe.notDeleted, sortBy: [SortDescriptor(\.title)])
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private func entity(_ recipe: Recipe) -> RecipeEntity {
        var subtitle = recipe.category.title
        if recipe.calories > 0 { subtitle += " · \(Int(recipe.calories.rounded())) kcal" }
        return RecipeEntity(id: recipe.id, title: recipe.title, subtitle: subtitle)
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [RecipeEntity] {
        let wanted = Set(identifiers)
        return recipes().filter { wanted.contains($0.id) }.map(entity)
    }

    @MainActor
    func entities(matching string: String) async throws -> [RecipeEntity] {
        recipes().filter { $0.matches(query: string) }.map(entity)
    }

    /// Sugestões: favoritas primeiro e depois as feitas mais recentemente.
    @MainActor
    func suggestedEntities() async throws -> [RecipeEntity] {
        let all = recipes()
        let favorites = all.filter(\.isFavorite)
        let rest = RecipeSort.recentlyCooked.sorted(all.filter { !$0.isFavorite })
        return (favorites + rest).prefix(20).map(entity)
    }
}

/// "Abrir receita": abre a app na receita escolhida.
struct OpenRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Abrir receita"
    static let description = IntentDescription("Abre uma receita na app Receitas.")
    static let openAppWhenRun = true

    @Parameter(title: "Receita")
    var recipe: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.open(recipe.id)
        return .result()
    }
}

/// "Fiz esta receita": regista que a receita foi feita hoje, sem abrir a app.
struct MarkCookedIntent: AppIntent {
    static let title: LocalizedStringResource = "Fiz esta receita"
    static let description = IntentDescription("Regista que fizeste uma receita hoje.")

    @Parameter(title: "Receita")
    var recipe: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = try? DataStore.shared.get() else {
            return .result(dialog: "Não foi possível abrir as receitas.")
        }
        let id = recipe.id
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == id })
        guard let found = try? container.mainContext.fetch(descriptor).first else {
            return .result(dialog: "Não encontrei essa receita.")
        }
        found.cookedDates.append(.now)
        try? container.mainContext.save()
        let times = found.timesCooked
        return .result(dialog: "Registado. Já fizeste \(found.title) \(times == 1 ? "1 vez" : "\(times) vezes").")
    }
}

/// "Assinatura renovada": para pôr no atalho logo a seguir ao "Refresh All" do SideStore.
/// O SideStore renova sem reinstalar a app, por isso a app não vê a data nova sozinha.
struct SigningRenewedIntent: AppIntent {
    static let title: LocalizedStringResource = "Assinatura renovada"
    static let description = IntentDescription("Regista que o SideStore acabou de renovar a app Receitas, para a data de validade ficar certa.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Date> & ProvidesDialog {
        SigningState.shared.recordRenewal()
        await ExpiryReminder.reschedule()
        let until = SigningState.shared.renewedUntil ?? .now
        let date = until.formatted(.dateTime.day().month(.wide))
        return .result(value: until, dialog: "A app Receitas é válida até \(date).")
    }
}

struct ReceitasShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecipeIntent(),
            phrases: [
                "Abrir \(\.$recipe) em \(.applicationName)",
                "Abrir receita em \(.applicationName)",
            ],
            shortTitle: "Abrir receita",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: MarkCookedIntent(),
            phrases: [
                "Fiz \(\.$recipe) em \(.applicationName)",
                "Registar receita feita em \(.applicationName)",
            ],
            shortTitle: "Fiz esta receita",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: SigningRenewedIntent(),
            phrases: ["Assinatura renovada em \(.applicationName)"],
            shortTitle: "Assinatura renovada",
            systemImageName: "checkmark.seal"
        )
    }
}
