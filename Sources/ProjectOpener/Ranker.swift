import Foundation

/// Pure ranking logic, kept separate from `AppModel` so it can be exercised
/// headlessly via `ProjectOpener --match <query>`.
enum Ranker {
    struct Hit {
        let project: Project
        let score: Int
        /// Indices into `project.name` to highlight.
        let matches: [Int]
    }

    /// Scores every project against `query`, best first.
    ///
    /// A hit on the folder name outranks a hit that only works against the
    /// wider path, so typing `bulbul` beats an incidental path match — but
    /// `sarj` still finds `office/sarj/bulbul`.
    static func rank(
        projects: [Project],
        query: String,
        pinned: Set<String> = [],
        recents: [String] = []
    ) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var hits: [Hit] = []
        for project in projects {
            var best: (score: Int, matches: [Int])?

            if let m = Fuzzy.match(query: trimmed, candidate: project.name) {
                best = (m.score + 40, m.indices)
            }
            if let m = Fuzzy.match(query: trimmed, candidate: project.relativePath) {
                // The name is the trailing component of relativePath, so indices
                // at or past this offset can be re-mapped onto the name.
                let offset = project.relativePath.count - project.name.count
                let mapped = m.indices.compactMap { $0 >= offset ? $0 - offset : nil }
                let candidate = (m.score - 30, mapped.count == m.indices.count ? mapped : [])
                if best == nil || candidate.0 > best!.score { best = candidate }
            }

            guard let found = best else { continue }
            var score = found.score
            if pinned.contains(project.path) { score += 25 }
            if let idx = recents.firstIndex(of: project.path) {
                score += max(0, 20 - idx * 2)
            }
            hits.append(Hit(project: project, score: score, matches: found.matches))
        }

        hits.sort {
            $0.score == $1.score
                ? $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
                : $0.score > $1.score
        }
        return hits
    }
}
