import Foundation

/// Consulta a base de dados aberta Open Food Facts pelo código de barras (gratuita, sem conta).
/// Só se envia o código de barras; o resultado nunca é guardado sem o utilizador rever e tocar em "Guardar".
enum OpenFoodFacts {
    nonisolated struct Product: Equatable, Sendable {
        var name: String
        var brand: String
        var facts: PartialFacts
    }

    enum LookupError: Error {
        case notFound
        case unavailable
    }

    static func product(barcode: String) async throws -> Product {
        let digits = barcode.filter(\.isNumber)
        let fields = "product_name,product_name_pt,brands,nutriments,nutrition_data_per"
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json?fields=\(fields)")
        else { throw LookupError.notFound }

        var request = URLRequest(url: url, timeoutInterval: 10)
        // O Open Food Facts pede que cada app se identifique.
        request.setValue("Receitas/1.6 (app pessoal para iOS; github.com/tpereira2005/receitas)", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LookupError.unavailable
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { throw LookupError.notFound }
        guard let product = parse(data) else { throw LookupError.notFound }
        return product
    }

    /// Interpreta a resposta JSON (separado da rede para poder ser testado).
    nonisolated static func parse(_ data: Data) -> Product? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? Int ?? (json["status"] as? String).flatMap(Int.init)) == 1,
              let product = json["product"] as? [String: Any]
        else { return nil }

        let name = [product["product_name_pt"], product["product_name"]]
            .compactMap { ($0 as? String)?.trimmed }
            .first { !$0.isEmpty } ?? ""
        let brand = (product["brands"] as? String)?
            .split(separator: ",").first.map { String($0).trimmed } ?? ""

        var facts = PartialFacts()
        let per = (product["nutrition_data_per"] as? String) ?? ""
        facts.base = per.contains("ml") ? .milliliters : .grams
        if let nutriments = product["nutriments"] as? [String: Any] {
            let keys: [(Nutrient, String)] = [
                (.calories, "energy-kcal_100g"),
                (.fat, "fat_100g"),
                (.saturatedFat, "saturated-fat_100g"),
                (.carbs, "carbohydrates_100g"),
                (.sugars, "sugars_100g"),
                (.fiber, "fiber_100g"),
                (.protein, "proteins_100g"),
                (.salt, "salt_100g"),
            ]
            for (nutrient, key) in keys {
                if let value = number(nutriments[key]) { facts[nutrient] = value }
            }
            if facts[.calories] == nil, let kj = number(nutriments["energy-kj_100g"]) ?? number(nutriments["energy_100g"]) {
                facts[.calories] = (kj / 4.184).rounded()
            }
        }
        guard !name.isEmpty || !facts.isEmpty else { return nil }
        return Product(name: name, brand: brand, facts: facts)
    }

    private nonisolated static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}
