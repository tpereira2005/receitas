import Foundation
import SwiftData

/// Alimentos incluídos de origem, com valores médios por 100 g (ou 100 ml).
/// Servem de ponto de partida: podem ser editados ou apagados na secção Alimentos.
enum FoodLibrary {
    private struct Entry {
        let name: String
        let category: FoodCategory
        var brand = ""
        var base: MeasureBase = .grams
        var unitWeight: Double?
        var portions: [(name: String, grams: Double)] = []
        var tablespoon: Double?
        var teaspoon: Double?
        let facts: NutritionFacts
    }

    private static func entry(
        _ name: String, _ category: FoodCategory, brand: String = "", base: MeasureBase = .grams, unit: Double? = nil,
        portions: [(name: String, grams: Double)] = [], spoons: (tablespoon: Double, teaspoon: Double)? = nil,
        kcal: Double, fat: Double, sat: Double, carbs: Double, sugars: Double, fiber: Double, protein: Double, salt: Double
    ) -> Entry {
        Entry(
            name: name, category: category, brand: brand, base: base, unitWeight: unit, portions: portions,
            tablespoon: spoons?.tablespoon, teaspoon: spoons?.teaspoon,
            facts: NutritionFacts(calories: kcal, protein: protein, carbs: carbs, sugars: sugars,
                                  fat: fat, saturatedFat: sat, fiber: fiber, salt: salt)
        )
    }

    private static let entries: [Entry] = [
        // Carne, peixe e ovos
        entry("Peito de frango", .protein, kcal: 110, fat: 1.5, sat: 0.4, carbs: 0, sugars: 0, fiber: 0, protein: 23, salt: 0.15),
        entry("Peito de peru", .protein, kcal: 107, fat: 1.5, sat: 0.4, carbs: 0, sugars: 0, fiber: 0, protein: 23, salt: 0.15),
        entry("Carne de vaca picada 5%", .protein, kcal: 125, fat: 5, sat: 2.2, carbs: 0, sugars: 0, fiber: 0, protein: 20, salt: 0.18),
        entry("Lombo de salmão", .protein, unit: 150, kcal: 208, fat: 13, sat: 3.1, carbs: 0, sugars: 0, fiber: 0, protein: 20, salt: 0.15),
        entry("Pescada", .protein, kcal: 78, fat: 0.8, sat: 0.2, carbs: 0, sugars: 0, fiber: 0, protein: 17.5, salt: 0.25),
        entry("Atum ao natural", .protein, kcal: 108, fat: 1, sat: 0.3, carbs: 0, sugars: 0, fiber: 0, protein: 25, salt: 0.9),
        entry("Camarão", .protein, kcal: 85, fat: 0.9, sat: 0.2, carbs: 0, sugars: 0, fiber: 0, protein: 19, salt: 0.6),
        entry("Ovo", .protein, unit: 60, kcal: 143, fat: 9.5, sat: 3.1, carbs: 0.7, sugars: 0.4, fiber: 0, protein: 12.6, salt: 0.36),
        entry("Claras de ovo", .protein, kcal: 52, fat: 0.2, sat: 0, carbs: 0.7, sugars: 0.7, fiber: 0, protein: 11, salt: 0.4),
        entry("Tofu firme", .protein, kcal: 144, fat: 8.7, sat: 1.3, carbs: 2, sugars: 0.6, fiber: 2, protein: 15, salt: 0.02),

        // Laticínios e bebidas vegetais
        entry("Iogurte grego natural magro", .dairy, kcal: 57, fat: 0.4, sat: 0.1, carbs: 3.6, sugars: 3.6, fiber: 0, protein: 10, salt: 0.1),
        entry("Skyr natural", .dairy, kcal: 63, fat: 0.2, sat: 0.1, carbs: 4, sugars: 4, fiber: 0, protein: 11, salt: 0.1),
        entry("Queijo fresco magro", .dairy, kcal: 70, fat: 1, sat: 0.6, carbs: 3.5, sugars: 3.5, fiber: 0, protein: 11, salt: 0.6),
        entry("Queijo cottage", .dairy, kcal: 98, fat: 4.3, sat: 1.7, carbs: 3.4, sugars: 2.7, fiber: 0, protein: 11, salt: 0.9),
        entry("Mozzarella light", .dairy, kcal: 165, fat: 9, sat: 6, carbs: 1.5, sugars: 1, fiber: 0, protein: 20, salt: 0.8),
        entry("Leite magro", .dairy, base: .milliliters, kcal: 34, fat: 0.1, sat: 0.1, carbs: 4.9, sugars: 4.9, fiber: 0, protein: 3.4, salt: 0.1),
        entry("Bebida de amêndoa sem açúcar", .dairy, base: .milliliters, kcal: 13, fat: 1.1, sat: 0.1, carbs: 0, sugars: 0, fiber: 0.3, protein: 0.4, salt: 0.13),

        // Cereais, pão e tubérculos
        entry("Flocos de aveia", .grains, kcal: 372, fat: 7, sat: 1.3, carbs: 58.7, sugars: 0.7, fiber: 10, protein: 13.5, salt: 0.01),
        entry("Arroz basmati", .grains, kcal: 350, fat: 0.9, sat: 0.2, carbs: 77, sugars: 0.2, fiber: 1.3, protein: 8, salt: 0.01),
        entry("Massa integral", .grains, kcal: 350, fat: 2.5, sat: 0.5, carbs: 64, sugars: 3, fiber: 8, protein: 13, salt: 0.01),
        entry("Pão integral", .grains, unit: 30, kcal: 247, fat: 3.4, sat: 0.7, carbs: 41, sugars: 6, fiber: 7, protein: 13, salt: 1.1),
        entry("Tortilha de trigo integral", .grains, unit: 60, kcal: 300, fat: 7, sat: 2.5, carbs: 47, sugars: 2.5, fiber: 6, protein: 9, salt: 1.2),
        entry("Batata-doce", .grains, unit: 200, kcal: 86, fat: 0.1, sat: 0, carbs: 20, sugars: 4.2, fiber: 3, protein: 1.6, salt: 0.14),
        entry("Amido de milho", .grains, kcal: 381, fat: 0.1, sat: 0, carbs: 91, sugars: 0, fiber: 0.9, protein: 0.3, salt: 0.02),

        // Fruta
        entry("Banana", .fruit, unit: 120, kcal: 89, fat: 0.3, sat: 0.1, carbs: 20, sugars: 12.2, fiber: 2.6, protein: 1.1, salt: 0),
        entry("Maçã", .fruit, unit: 150, kcal: 52, fat: 0.2, sat: 0, carbs: 12, sugars: 10, fiber: 2.4, protein: 0.3, salt: 0),
        entry("Morangos", .fruit, kcal: 32, fat: 0.3, sat: 0, carbs: 5.7, sugars: 4.9, fiber: 2, protein: 0.7, salt: 0),
        entry("Mirtilos", .fruit, kcal: 57, fat: 0.3, sat: 0, carbs: 12, sugars: 10, fiber: 2.4, protein: 0.7, salt: 0),
        entry("Frutos vermelhos congelados", .fruit, kcal: 45, fat: 0.3, sat: 0, carbs: 8, sugars: 6, fiber: 4, protein: 1, salt: 0),
        entry("Manga", .fruit, kcal: 60, fat: 0.4, sat: 0.1, carbs: 13.7, sugars: 13.7, fiber: 1.6, protein: 0.8, salt: 0),
        entry("Tâmaras sem caroço", .fruit, unit: 8, kcal: 282, fat: 0.4, sat: 0, carbs: 64, sugars: 63, fiber: 8, protein: 2.5, salt: 0),
        entry("Limão", .fruit, unit: 80, kcal: 29, fat: 0.3, sat: 0, carbs: 3, sugars: 2.5, fiber: 2.8, protein: 1.1, salt: 0),

        // Legumes e verduras
        entry("Brócolos", .vegetables, kcal: 34, fat: 0.4, sat: 0, carbs: 4, sugars: 1.7, fiber: 2.6, protein: 2.8, salt: 0.08),
        entry("Cenoura", .vegetables, unit: 70, kcal: 41, fat: 0.2, sat: 0, carbs: 7, sugars: 4.7, fiber: 2.8, protein: 0.9, salt: 0.17),
        entry("Curgete", .vegetables, unit: 200, kcal: 17, fat: 0.3, sat: 0.1, carbs: 2.2, sugars: 1.7, fiber: 1, protein: 1.2, salt: 0.02),
        entry("Pimento vermelho", .vegetables, unit: 150, kcal: 31, fat: 0.3, sat: 0, carbs: 4.6, sugars: 4.2, fiber: 2.1, protein: 1, salt: 0.01),
        entry("Tomate cherry", .vegetables, kcal: 18, fat: 0.2, sat: 0, carbs: 2.7, sugars: 2.6, fiber: 1.2, protein: 0.9, salt: 0.01),
        entry("Espinafres baby", .vegetables, kcal: 23, fat: 0.4, sat: 0.1, carbs: 1.4, sugars: 0.4, fiber: 2.2, protein: 2.9, salt: 0.2),
        entry("Cebola", .vegetables, unit: 110, kcal: 40, fat: 0.1, sat: 0, carbs: 7.6, sugars: 4.2, fiber: 1.7, protein: 1.1, salt: 0.01),
        entry("Alho", .vegetables, unit: 5, kcal: 149, fat: 0.5, sat: 0.1, carbs: 30, sugars: 1, fiber: 2.1, protein: 6.4, salt: 0.04),
        entry("Abacate", .vegetables, unit: 150, kcal: 160, fat: 14.7, sat: 2.1, carbs: 1.9, sugars: 0.7, fiber: 6.7, protein: 2, salt: 0.02),

        // Gorduras, frutos secos e sementes
        entry("Azeite", .fats, kcal: 884, fat: 100, sat: 14, carbs: 0, sugars: 0, fiber: 0, protein: 0, salt: 0),
        entry("Amêndoas", .fats, kcal: 579, fat: 50, sat: 3.8, carbs: 9.5, sugars: 4.4, fiber: 12.5, protein: 21, salt: 0),
        entry("Nozes", .fats, kcal: 654, fat: 65, sat: 6.1, carbs: 7, sugars: 2.6, fiber: 6.7, protein: 15, salt: 0),
        entry("Manteiga de amendoim", .fats, kcal: 600, fat: 50, sat: 8, carbs: 12, sugars: 5, fiber: 6, protein: 25, salt: 0),
        entry("Sementes de chia", .fats, kcal: 486, fat: 31, sat: 3.3, carbs: 7.7, sugars: 0, fiber: 34, protein: 17, salt: 0.04),
        entry("Sementes de sésamo", .fats, kcal: 573, fat: 50, sat: 7, carbs: 12, sugars: 0.3, fiber: 12, protein: 18, salt: 0.03),
        entry("Chocolate negro 85%", .fats, kcal: 600, fat: 50, sat: 30, carbs: 19, sugars: 13, fiber: 13, protein: 11, salt: 0.02),
        entry("Cacau magro em pó", .fats, brand: "Continente", spoons: (5.3, 1.8), kcal: 327, fat: 11, sat: 7, carbs: 16, sugars: 2, fiber: 34, protein: 24, salt: 0.1),

        // Suplementos
        entry("Proteína whey de baunilha", .supplements, unit: 30, kcal: 380, fat: 6, sat: 3.5, carbs: 8, sugars: 4, fiber: 0, protein: 75, salt: 0.5),
        entry("Proteína whey de chocolate", .supplements, unit: 30, kcal: 375, fat: 6, sat: 3.5, carbs: 10, sugars: 5, fiber: 2, protein: 72, salt: 0.6),

        // Temperos, molhos e doces
        entry("Mel", .condiments, kcal: 304, fat: 0, sat: 0, carbs: 82, sugars: 82, fiber: 0, protein: 0.3, salt: 0),
        entry("Molho de soja reduzido em sal", .condiments, base: .milliliters, kcal: 60, fat: 0, sat: 0, carbs: 5, sugars: 1, fiber: 0, protein: 8, salt: 9),
        entry("Gengibre ralado", .condiments, kcal: 80, fat: 0.8, sat: 0.2, carbs: 18, sugars: 1.7, fiber: 2, protein: 1.8, salt: 0.03),
        entry("Canela", .condiments, kcal: 247, fat: 1.2, sat: 0.3, carbs: 27, sugars: 2, fiber: 53, protein: 4, salt: 0.03),
        entry("Adoçante", .condiments, kcal: 0, fat: 0, sat: 0, carbs: 0, sugars: 0, fiber: 0, protein: 0, salt: 0),
        entry("Sal", .condiments, kcal: 0, fat: 0, sat: 0, carbs: 0, sugars: 0, fiber: 0, protein: 0, salt: 100),
        entry("Pimenta preta", .condiments, kcal: 251, fat: 3.3, sat: 1.4, carbs: 39, sugars: 0.6, fiber: 25, protein: 10, salt: 0.05),
        entry("Orégãos secos", .condiments, kcal: 265, fat: 4.3, sat: 1.6, carbs: 26, sugars: 4, fiber: 42, protein: 9, salt: 0.06),

        // Outros
        entry("Fermento em pó", .other, spoons: (12, 4), kcal: 155, fat: 0.4, sat: 0.3, carbs: 61.5, sugars: 0.1, fiber: 0, protein: 0.4, salt: 0.1),
    ]

    /// Insere os alimentos de origem que ainda não existem (compara pelo nome).
    /// Com `names`, insere só esses (p. ex. os que faltam às receitas base), e não a biblioteca toda.
    @MainActor
    @discardableResult
    static func insertMissingDefaults(in context: ModelContext, only names: Set<String>? = nil) -> [String: Food] {
        let existing = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        var byName: [String: Food] = [:]
        for food in existing { byName[food.name.searchNormalized] = food }
        let wanted = names.map { Set($0.map(\.searchNormalized)) }
        for entry in entries where byName[entry.name.searchNormalized] == nil {
            if let wanted, !wanted.contains(entry.name.searchNormalized) { continue }
            let food = Food(name: entry.name, category: entry.category)
            food.brand = entry.brand
            food.measureBase = entry.base
            food.unitWeight = entry.unitWeight
            food.portions = entry.portions.map { FoodPortion(name: $0.name, grams: $0.grams) }
            food.tablespoonWeight = entry.tablespoon
            food.teaspoonWeight = entry.teaspoon
            food.per100 = entry.facts
            context.insert(food)
            byName[entry.name.searchNormalized] = food
        }
        try? context.save()
        return byName
    }
}

/// Atualizações de dados entre versões da app.
enum DataMigration {
    static let currentVersion = 8

    @MainActor
    static func migrate(_ context: ModelContext, from version: Int) {
        if version < 2 { migrateToV2(context) }
        if version < 3 { migrateToV3(context) }
        if version < 4 { migrateToV4(context) }
        if version < 5 { migrateToV5(context) }
        if version < 6 { migrateToV6(context) }
        if version < 7 { migrateToV7(context) }
        if version < 8 { migrateToV8(context) }
    }

    /// Receitas de origem acrescentadas na versão 8.
    static let v8Recipes: Set<String> = ["Papas de aveia", "Panquecas de aveia"]

    /// Versão 8: papas e panquecas de aveia, com a farinha de aveia e o xarope de ácer.
    /// Só entram se ainda não houver receitas com estes nomes.
    @MainActor
    static func migrateToV8(_ context: ModelContext) {
        BaseContent.insertMissingRecipes(into: context, only: v8Recipes)
    }

    /// Versão 7: o Cookie Dough Cake fica com 2 h de frigorífico, como diz a receita
    /// (os 30 min de repouso depois do forno já são um passo, com temporizador).
    /// Só muda se ainda estiver com os 2 h 30 postos pela versão 6.
    @MainActor
    static func migrateToV7(_ context: ModelContext) {
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        for recipe in recipes where recipe.title == "Cookie Dough Cake" && recipe.waitMinutes == 150 && recipe.waitKind == .fridge {
            recipe.waitMinutes = 120
        }
        try? context.save()
    }

    /// Versão 6 (app 1.4): tempo de espera e nome da porção nas receitas de origem.
    @MainActor
    static func migrateToV6(_ context: ModelContext) {
        BaseContent.applyNewFields(into: context)
    }

    /// Versão 5: conteúdo de origem (gelados da Ninja CREAMi e Cookie Dough Cake).
    /// Só entram as receitas que ainda não existem, com os alimentos de que precisam e que ainda não existam.
    @MainActor
    static func migrateToV5(_ context: ModelContext) {
        BaseContent.insertMissingRecipes(into: context)
    }

    /// Versão 4: marca como exemplo as receitas criadas pela app (identificadas pelo título).
    @MainActor
    static func migrateToV4(_ context: ModelContext) {
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        for recipe in recipes where SampleData.titles.contains(recipe.title) {
            recipe.isSample = true
        }
        try? context.save()
    }

    /// Versão 3: cada ingrediente guarda uma cópia dos valores do alimento (os valores não mudam).
    @MainActor
    static func migrateToV3(_ context: ModelContext) {
        let foodIndex = NutritionCalculator.index((try? context.fetch(FetchDescriptor<Food>())) ?? [])
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        for recipe in recipes {
            let original = recipe.ingredients
            let filled = NutritionCalculator.fillMissingSnapshots(original, foods: foodIndex)
            if filled != original { recipe.ingredients = filled }
        }
        try? context.save()
    }
    static let removedTags: Set<String> = ["Vegetariana", "Vegan", "Sem glúten", "Sem lactose"]

    /// Versão 2: biblioteca de alimentos, cálculo automático e remoção de etiquetas.
    @MainActor
    static func migrateToV2(_ context: ModelContext) {
        let foodCount = (try? context.fetchCount(FetchDescriptor<Food>())) ?? 0
        if foodCount == 0 {
            FoodLibrary.insertMissingDefaults(in: context)
        }
        let foods = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        let foodIndex = NutritionCalculator.index(foods)
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []

        for recipe in recipes {
            if recipe.tags.contains(where: { removedTags.contains($0) }) {
                recipe.tags.removeAll { removedTags.contains($0) }
            }

            var ingredients = recipe.ingredients
            var linkedAny = false
            for index in ingredients.indices where ingredients[index].foodID == nil {
                if let food = FoodMatcher.match(ingredients[index].name, in: foods) {
                    ingredients[index].foodID = food.id
                    ingredients[index].name = food.name
                    linkedAny = true
                }
            }
            if linkedAny {
                recipe.ingredients = ingredients
                NutritionCalculator.update(recipe, foods: foodIndex)
            }
        }
        try? context.save()
    }
}
