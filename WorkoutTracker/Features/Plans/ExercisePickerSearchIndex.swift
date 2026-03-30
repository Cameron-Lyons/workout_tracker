import Foundation

struct ExercisePickerSearchIndex {
    private struct Entry {
        var item: ExerciseCatalogItem
        var normalizedSearchText: String
    }

    private let entries: [Entry]

    init(catalog: [ExerciseCatalogItem]) {
        entries = catalog.map { item in
            Entry(
                item: item,
                normalizedSearchText: ([item.name] + item.aliases)
                    .map(Self.normalize)
                    .joined(separator: "\n")
            )
        }
    }

    func filter(query: String) -> [ExerciseCatalogItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = Self.normalize(trimmedQuery)
        guard !normalizedQuery.isEmpty else {
            return entries.map(\.item)
        }

        return entries.compactMap { entry in
            entry.normalizedSearchText.contains(normalizedQuery) ? entry.item : nil
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
