import Foundation
import Testing
import UIKit
@testable import Receitas

@MainActor
struct SystemTests {
    /// Um perfil de instalação tem bytes binários à volta de um plist XML.
    @Test func readsExpirationFromProvisioningProfile() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>AppIDName</key><string>Receitas</string>
        <key>ExpirationDate</key><date>2026-10-01T12:00:00Z</date>
        </dict></plist>
        """
        var data = Data([0x30, 0x82, 0x1F, 0x00, 0x06, 0x09])
        data.append(Data(plist.utf8))
        data.append(Data([0xA0, 0x82, 0x0B, 0x00]))
        let date = try #require(AppSigning.parseExpiration(from: data))
        #expect(date == ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z"))
        #expect(AppSigning.parseExpiration(from: Data("sem plist".utf8)) == nil)
    }

    /// A renovação registada pelo atalho só conta se for mais recente do que o perfil da app.
    @Test func renewalExtendsTheEmbeddedExpiration() {
        let embedded = Date(timeIntervalSince1970: 1_000_000)
        let later = embedded.addingTimeInterval(5 * 86_400)
        let earlier = embedded.addingTimeInterval(-86_400)
        #expect(AppSigning.effectiveExpiration(embedded: embedded, renewedUntil: nil) == embedded)
        #expect(AppSigning.effectiveExpiration(embedded: embedded, renewedUntil: later) == later)
        #expect(AppSigning.effectiveExpiration(embedded: embedded, renewedUntil: earlier) == embedded)
        #expect(AppSigning.effectiveExpiration(embedded: nil, renewedUntil: later) == nil)
    }

    @Test func thumbnailsAreDecodedAtDisplaySize() throws {
        let size = CGSize(width: 1800, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = try #require(big.jpegData(compressionQuality: 0.8))
        let image = try #require(ImageCache.shared.image(for: "teste-\(UUID())", data: data, maxPixelSize: 600))
        #expect(max(image.size.width * image.scale, image.size.height * image.scale) == 600)
    }

    @Test func voiceOverSummaryDescribesTheCard() {
        let recipe = Recipe(title: "Bowl de frango", category: .lunch)
        recipe.calories = 473
        recipe.protein = 43.4
        recipe.isFavorite = true
        recipe.cookedDates = [.now, .now]
        let summary = recipe.accessibilitySummary
        #expect(summary.hasPrefix("Bowl de frango, Almoço, 473 calorias"))
        #expect(summary.contains("favorita"))
        #expect(summary.contains("feita 2 vezes"))
    }
}
