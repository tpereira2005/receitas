import Foundation
import SwiftData

/// Conteúdo que vem com a app: alimentos (com imagens) e receitas (com fotografias).
/// Está em `Resources/ConteudoBase.json`, no mesmo formato das cópias de segurança:
/// para mudar o conteúdo de origem basta substituir esse ficheiro por uma cópia exportada na app.
enum BaseContent {
    static let resourceName = "ConteudoBase"

    /// Lê o ficheiro incluído na app. `nil` se faltar ou estiver danificado.
    static func load(bundle: Bundle = .main) -> RecipeBackup? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecipeBackup.self, from: data)
    }

    /// Títulos das receitas de origem.
    static var recipeTitles: [String] { load()?.recipes.map(\.title) ?? [] }

    struct Result {
        var recipes = 0
        var foods = 0
    }

    /// Insere as receitas de origem que ainda não existem (compara pelo título) e os alimentos de que precisam.
    /// Um alimento que já existe com o mesmo nome é reaproveitado; os que nenhuma receita nova usa não entram.
    /// Com `only`, considera só essas receitas (as que uma versão acrescentou), para não trazer de volta
    /// receitas de origem que o utilizador já apagou de vez.
    @MainActor
    @discardableResult
    static func insertMissingRecipes(into context: ModelContext, from content: RecipeBackup? = load(),
                                     only onlyTitles: Set<String>? = nil) -> Result {
        guard let content else { return Result() }
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        let titles = Set(recipes.map(\.title.searchNormalized))
        let ids = Set(recipes.map(\.id))
        let wanted = onlyTitles.map { Set($0.map(\.searchNormalized)) }
        let missing = content.recipes.filter { dto in
            let title = dto.title.searchNormalized
            return !titles.contains(title) && !ids.contains(dto.id) && (wanted?.contains(title) ?? true)
        }
        guard !missing.isEmpty else { return Result() }

        let needed = Set(missing.flatMap { $0.ingredients.compactMap(\.foodID) })
        var result = Result()
        let foodIDs = insertFoods(content.foods ?? [], into: context, only: needed, result: &result)

        for dto in missing {
            let recipe = dto.makeRecipe()
            recipe.ingredients = recipe.ingredients.map { ingredient in
                var ingredient = ingredient
                if let id = ingredient.foodID { ingredient.foodID = foodIDs[id] ?? id }
                return ingredient
            }
            recipe.cookedDates = []
            context.insert(recipe)
            result.recipes += 1
        }
        try? context.save()
        return result
    }

    /// Leva às receitas de origem que já existem os campos novos da versão 1.4 (tempo de espera,
    /// nome da porção, confeção), sem mexer no que o utilizador já tenha preenchido.
    /// Tira também a nota "Rende 2 doses.", que passou a estar no nome da porção.
    @MainActor
    @discardableResult
    static func applyNewFields(into context: ModelContext, from content: RecipeBackup? = load()) -> Int {
        guard let content else { return 0 }
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        var byTitle: [String: RecipeDTO] = [:]
        for dto in content.recipes { byTitle[dto.title.searchNormalized] = dto }
        var changed = 0
        for recipe in recipes {
            guard let dto = byTitle[recipe.title.searchNormalized] else { continue }
            var touched = false
            if recipe.waitMinutes == 0, let wait = dto.waitMinutes, wait > 0 {
                recipe.waitMinutes = wait
                recipe.waitKindRaw = dto.waitKind ?? ""
                touched = true
            }
            if recipe.servingName.isEmpty, let name = dto.servingName, !name.isEmpty {
                recipe.servingName = name
                touched = true
            }
            if recipe.cookMinutes == 0, dto.cookMinutes > 0 {
                recipe.cookMinutes = dto.cookMinutes
                touched = true
            }
            if recipe.notes.trimmed == "Rende 2 doses." {
                recipe.notes = ""
                touched = true
            }
            if touched { changed += 1 }
        }
        try? context.save()
        return changed
    }

    /// Insere os alimentos de origem que faltam (compara pelo nome), com as imagens. Devolve quantos entraram.
    @MainActor
    @discardableResult
    static func insertMissingFoods(into context: ModelContext, from content: RecipeBackup? = load()) -> Int {
        guard let content else { return 0 }
        var result = Result()
        insertFoods(content.foods ?? [], into: context, only: nil, result: &result)
        try? context.save()
        return result.foods
    }

    /// Insere os alimentos que faltam e devolve, para cada alimento do ficheiro, o id do alimento a usar
    /// (o que já existia com o mesmo nome, ou o novo).
    @MainActor
    @discardableResult
    private static func insertFoods(_ foods: [FoodDTO], into context: ModelContext, only ids: Set<UUID>?,
                                    result: inout Result) -> [UUID: UUID] {
        let existing = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        var byName: [String: Food] = [:]
        for food in existing { byName[food.name.searchNormalized] = food }
        let existingIDs = Set(existing.map(\.id))

        var mapping: [UUID: UUID] = [:]
        for dto in foods where ids?.contains(dto.id) ?? true {
            if let match = byName[dto.name.searchNormalized] {
                mapping[dto.id] = match.id
            } else if existingIDs.contains(dto.id) {
                // O mesmo alimento com outro nome (mudado pelo utilizador): fica o do utilizador.
                mapping[dto.id] = dto.id
            } else {
                let food = dto.makeFood()
                context.insert(food)
                byName[food.name.searchNormalized] = food
                mapping[dto.id] = food.id
                result.foods += 1
            }
        }
        return mapping
    }
}
