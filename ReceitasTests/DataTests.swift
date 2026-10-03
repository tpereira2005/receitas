import Foundation
import SwiftData
import Testing
@testable import Receitas

@MainActor
struct DataTests {
    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: DataStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Uma base de dados criada com o esquema antigo (V1) tem de abrir com o atual (V2) sem perder nada.
    @Test func migrationFromV1KeepsData() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "migracao-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "teste.store")
        let recipeID = UUID()

        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: v1, configurations: ModelConfiguration(schema: v1, url: url))
            let context = ModelContext(container)
            let recipe = SchemaV1.Recipe(title: "Panquecas")
            recipe.id = recipeID
            recipe.servings = 3
            recipe.isFavorite = true
            recipe.calories = 310
            context.insert(recipe)
            let food = SchemaV1.Food(name: "Ovo")
            food.unitWeight = 60
            context.insert(food)
            try context.save()
        }

        let container = try ModelContainer(
            for: DataStore.schema,
            migrationPlan: ReceitasMigrationPlan.self,
            configurations: ModelConfiguration(schema: DataStore.schema, url: url)
        )
        let context = ModelContext(container)
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.count == 1)
        let recipe = try #require(recipes.first)
        #expect(recipe.id == recipeID)
        #expect(recipe.title == "Panquecas")
        #expect(recipe.servings == 3)
        #expect(recipe.isFavorite)
        #expect(recipe.calories == 310)
        #expect(recipe.isSample == false)
        #expect(recipe.cookedDates.isEmpty)
        #expect(recipe.photoFocusX == 0.5)
        let foods = try context.fetch(FetchDescriptor<Food>())
        #expect(foods.first?.unitWeight == 60)
        #expect(foods.first?.portions.isEmpty == true)
        #expect(foods.first?.tablespoonWeight == nil)
    }

    /// Uma base de dados da versão 1.3 (esquema V2) abre com o V3 sem perder nada.
    @Test func migrationFromV2KeepsData() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "migracao-v2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "teste.store")

        do {
            let v2 = Schema(versionedSchema: SchemaV2.self)
            let container = try ModelContainer(for: v2, configurations: ModelConfiguration(schema: v2, url: url))
            let context = ModelContext(container)
            let recipe = SchemaV2.Recipe(title: "Gelado Oreo")
            recipe.servings = 2
            recipe.photoFocusX = 0.3
            recipe.cookedDates = [Date(timeIntervalSince1970: 1_700_000_000)]
            context.insert(recipe)
            let food = SchemaV2.Food(name: "Oreo")
            food.tablespoonWeight = 9
            context.insert(food)
            try context.save()
        }

        let container = try ModelContainer(
            for: DataStore.schema,
            migrationPlan: ReceitasMigrationPlan.self,
            configurations: ModelConfiguration(schema: DataStore.schema, url: url)
        )
        let context = ModelContext(container)
        let recipe = try #require(try context.fetch(FetchDescriptor<Recipe>()).first)
        #expect(recipe.title == "Gelado Oreo" && recipe.servings == 2 && recipe.photoFocusX == 0.3)
        #expect(recipe.cookedDates.count == 1)
        #expect(recipe.waitMinutes == 0 && recipe.servingName.isEmpty && recipe.photoZoom == 1)
        #expect(recipe.deletedAt == nil && recipe.frozenAt == nil)
        let food = try #require(try context.fetch(FetchDescriptor<Food>()).first)
        #expect(food.tablespoonWeight == 9 && food.deletedAt == nil)
    }

    /// Versão 6: os gelados já instalados passam a ter 24 h no congelador e "doses".
    @Test func migrationV6AddsWaitAndServingName() throws {
        let context = ModelContext(try memoryContainer())
        let biscoff = Recipe(title: "Gelado Biscoff", category: .iceCream)
        biscoff.notes = "Rende 2 doses."
        let cake = Recipe(title: "Cookie Dough Cake", category: .snack)
        let mine = Recipe(title: "A minha receita")
        let custom = Recipe(title: "Gelado Oreo", category: .iceCream)
        custom.waitMinutes = 600
        custom.waitKind = .freezer
        [biscoff, cake, mine, custom].forEach(context.insert)

        DataMigration.migrateToV6(context)

        #expect(biscoff.waitMinutes == 1440 && biscoff.waitKind == .freezer)
        #expect(biscoff.servingNoun == "dose" && biscoff.servingsText == "1 dose")
        #expect(biscoff.notes.isEmpty)
        #expect(cake.cookMinutes == 30 && cake.waitMinutes == 120 && cake.waitKind == .fridge)
        #expect(mine.waitMinutes == 0 && mine.servingNoun == "porção")
        // O que o utilizador já tinha preenchido fica como estava.
        #expect(custom.waitMinutes == 600)
    }

    @Test func backupRoundTripKeepsEverything() throws {
        let source = ModelContext(try memoryContainer())
        let food = Food(name: "Whey", category: .supplements)
        food.per100 = NutritionFacts(calories: 380, protein: 75)
        food.portions = [FoodPortion(name: "1 scoop", grams: 30)]
        food.tablespoonWeight = 8
        source.insert(food)
        let recipe = Recipe(title: "Batido", category: .drink)
        recipe.ingredients = [Ingredient(food: food, amount: 30, unit: .gram)]
        recipe.steps = [RecipeStep(text: "Misturar")]
        recipe.cookedDates = [Date(timeIntervalSince1970: 1_700_000_000)]
        recipe.isSample = true
        recipe.photoFocusY = 0.3
        NutritionCalculator.update(recipe, foods: [:])
        source.insert(recipe)
        try source.save()

        let data = try RecipeBackup.encode(recipes: [recipe], foods: [food])
        let target = ModelContext(try memoryContainer())
        let result = try RecipeBackup.restore(from: data, into: target)
        #expect(result.recipes == 1)
        #expect(result.foods == 1)

        let restored = try #require(try target.fetch(FetchDescriptor<Recipe>()).first)
        #expect(restored.title == "Batido")
        #expect(restored.ingredients.count == 1)
        #expect(restored.steps.first?.text == "Misturar")
        #expect(restored.cookedDates.count == 1)
        #expect(restored.isSample)
        #expect(restored.photoFocusY == 0.3)
        #expect(abs(restored.protein - 22.5) < 0.001)
        let restoredFood = try #require(try target.fetch(FetchDescriptor<Food>()).first)
        #expect(restoredFood.portions.first?.grams == 30)
        #expect(restoredFood.tablespoonWeight == 8)

        // Importar a mesma cópia outra vez não duplica nada.
        let again = try RecipeBackup.restore(from: data, into: target)
        #expect(again.recipes == 0 && again.foods == 0)
    }

    @Test func migrationMarksOldSamples() throws {
        let context = ModelContext(try memoryContainer())
        let old = Recipe(title: "Bowl de frango teriyaki")
        let mine = Recipe(title: "A minha receita")
        context.insert(old)
        context.insert(mine)
        DataMigration.migrateToV4(context)
        #expect(old.isSample)
        #expect(!mine.isSample)
    }

    /// Instalação nova: o conteúdo de origem entra todo, com imagens, e os ingredientes ligados aos alimentos.
    @Test func baseContentInstallsEverythingLinked() throws {
        let content = try #require(BaseContent.load())
        let context = ModelContext(try memoryContainer())
        let foodCount = BaseContent.insertMissingFoods(into: context)
        let result = BaseContent.insertMissingRecipes(into: context)
        #expect(foodCount == content.foods?.count)
        #expect(result.recipes == content.recipes.count && result.foods == 0)

        // As imagens e as fotografias do ficheiro entram todas (há receitas e alimentos ainda sem imagem).
        let foods = try context.fetch(FetchDescriptor<Food>())
        let foodsWithImage = Set((content.foods ?? []).filter { $0.imageData != nil }.map(\.name))
        #expect(foods.filter { $0.imageData != nil }.count == foodsWithImage.count)
        let foodIDs = Set(foods.map(\.id))
        let recipesWithPhoto = Set(content.recipes.filter { $0.photo != nil }.map(\.title))
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        for recipe in recipes {
            #expect(!recipe.isSample)
            if recipesWithPhoto.contains(recipe.title) {
                #expect(recipe.photoData != nil && recipe.thumbnailData != nil, "\(recipe.title)")
            }
            #expect(recipe.calories > 0, "\(recipe.title)")
            let unlinked = recipe.ingredients.filter { $0.foodID.map { !foodIDs.contains($0) } ?? true }.map(\.name)
            #expect(unlinked.isEmpty, "\(recipe.title): \(unlinked)")
        }
        #expect(recipes.contains { $0.title == "Gelado Biscoff" })

        // Correr outra vez não duplica nada.
        #expect(BaseContent.insertMissingRecipes(into: context).recipes == 0)
        #expect(BaseContent.insertMissingFoods(into: context) == 0)
    }

    /// Atualização (versão 5): entram só as receitas que faltam e só os alimentos de que precisam;
    /// um alimento com o mesmo nome é reaproveitado.
    @Test func migrationV5AddsOnlyMissingRecipesAndFoods() throws {
        let context = ModelContext(try memoryContainer())
        let milk = Food(name: "Leite magro", category: .dairy)
        milk.measureBase = .milliliters
        milk.per100 = NutritionFacts(calories: 34, protein: 3.4, carbs: 4.9)
        context.insert(milk)
        context.insert(Recipe(title: "Cookie Dough Cake", category: .snack))
        try context.save()

        DataMigration.migrateToV5(context)

        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.filter { $0.title == "Cookie Dough Cake" }.count == 1)
        let oreo = try #require(recipes.first { $0.title == "Gelado Oreo" })
        #expect(oreo.ingredients.contains { $0.foodID == milk.id })
        let foods = try context.fetch(FetchDescriptor<Food>())
        let names = Set(foods.map(\.name))
        #expect(foods.filter { $0.name == "Leite magro" }.count == 1)
        #expect(names.contains("Goma xantana"))
        // O Cookie Dough Cake já existia: os alimentos só dele não são acrescentados.
        #expect(!names.contains("Select Protein Powder Gourmet Vanilla"))
    }

    /// Versão 8: entram só as papas e as panquecas, com os alimentos novos;
    /// uma receita de origem apagada de vez não volta.
    @Test func migrationV8AddsOnlyTheNewRecipes() throws {
        let context = ModelContext(try memoryContainer())
        let oats = Food(name: "Flocos de aveia", category: .grains)
        context.insert(oats)
        context.insert(Recipe(title: "Panquecas de aveia", category: .breakfast))
        try context.save()

        DataMigration.migrateToV8(context)

        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(Set(recipes.map(\.title)) == ["Papas de aveia", "Panquecas de aveia"])
        let papas = try #require(recipes.first { $0.title == "Papas de aveia" })
        #expect(papas.ingredients.contains { $0.foodID == oats.id })
        #expect(papas.waitKind == .rest && papas.waitMinutes == 2)
        let names = try context.fetch(FetchDescriptor<Food>()).map(\.name)
        #expect(names.filter { $0 == "Flocos de aveia" }.count == 1)
        #expect(names.contains("Xarope de Ácer Zero"))
        // As panquecas já existiam: a farinha de aveia, só delas, não entra.
        #expect(!names.contains("Farinha de aveia"))
    }

    /// Versão 9: o adoçante entra nas panquecas uma só vez, a seguir ao fermento, e as calorias são recalculadas.
    @Test func migrationV9AddsSweetenerToPancakes() throws {
        let context = ModelContext(try memoryContainer())
        BaseContent.insertMissingFoods(into: context)
        let foods = try context.fetch(FetchDescriptor<Food>())
        let sweetener = try #require(foods.first { $0.name == "Stevia + Eritritol 1:1" })
        let yeast = try #require(foods.first { $0.name == "Fermento em pó" })
        let pancakes = Recipe(title: "Panquecas de aveia", category: .breakfast)
        pancakes.ingredients = [
            Ingredient(name: yeast.name, amount: 4, unit: "g", foodID: yeast.id, snapshot: FoodSnapshot(food: yeast)),
            Ingredient(name: "Sal", amount: 0.5, unit: "g"),
        ]
        context.insert(pancakes)
        try context.save()

        DataMigration.migrateToV9(context)
        DataMigration.migrateToV9(context)

        #expect(pancakes.ingredients.map(\.name) == ["Fermento em pó", sweetener.name, "Sal"])
        #expect(pancakes.ingredients[1].amount == 15 && pancakes.ingredients[1].foodID == sweetener.id)
        #expect(pancakes.carbs > 15)
    }
}
