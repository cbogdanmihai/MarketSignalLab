import Foundation

enum UniverseLoader {
    static func load() throws -> [AssetConfig] {
        guard let url = Bundle.main.url(
            forResource: "assets",
            withExtension: "json"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(
            [AssetConfig].self,
            from: data
        )
    }
}
