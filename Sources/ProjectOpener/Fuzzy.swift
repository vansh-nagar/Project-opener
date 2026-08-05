import Foundation

/// Subsequence fuzzy matcher in the fzf/Sublime style.
///
/// Every query character must appear in order in the candidate. Among all valid
/// alignments we pick the highest scoring one, rewarding matches that land on
/// word boundaries and run consecutively. Returns the matched indices too, so
/// the UI can highlight them.
enum Fuzzy {
    private static let matchScore = 16
    private static let consecutiveBonus = 18
    private static let gapPenalty = 2
    private static let neg = Int.min / 4

    struct Result {
        let score: Int
        let indices: [Int]
    }

    static func match(query: String, candidate: String) -> Result? {
        let q = Array(query.lowercased())
        guard !q.isEmpty else { return Result(score: 0, indices: []) }

        let orig = Array(candidate)
        let c = Array(candidate.lowercased())
        let n = c.count
        let m = q.count
        guard m <= n else { return nil }

        // dp[i][j] = best score for matching q[0...i] with q[i] landing on c[j].
        var dp = Array(repeating: Array(repeating: neg, count: n), count: m)
        var parent = Array(repeating: Array(repeating: -1, count: n), count: m)

        for j in 0..<n where c[j] == q[0] {
            // Slight preference for matches near the start of the string.
            dp[0][j] = matchScore + boundaryBonus(orig, c, j) - min(j, 12)
        }

        if m > 1 {
            for i in 1..<m {
                for j in i..<n where c[j] == q[i] {
                    var best = neg
                    var bestK = -1
                    for k in (i - 1)..<j where dp[i - 1][k] > neg {
                        var s = dp[i - 1][k] + matchScore + boundaryBonus(orig, c, j)
                        if k == j - 1 {
                            s += consecutiveBonus
                        } else {
                            s -= (j - k - 1) * gapPenalty
                        }
                        if s > best {
                            best = s
                            bestK = k
                        }
                    }
                    if bestK >= 0 {
                        dp[i][j] = best
                        parent[i][j] = bestK
                    }
                }
            }
        }

        var best = neg
        var bestJ = -1
        for j in 0..<n where dp[m - 1][j] > best {
            best = dp[m - 1][j]
            bestJ = j
        }
        guard bestJ >= 0 else { return nil }

        var indices: [Int] = []
        var i = m - 1
        var j = bestJ
        while i >= 0 {
            indices.append(j)
            let p = parent[i][j]
            i -= 1
            if i < 0 { break }
            j = p
        }

        return Result(score: best, indices: indices.reversed())
    }

    /// Matches that begin a word are worth far more than matches mid-word.
    private static func boundaryBonus(_ orig: [Character], _ lower: [Character], _ j: Int) -> Int {
        if j == 0 { return 24 }
        let prev = lower[j - 1]
        if prev == "/" || prev == "-" || prev == "_" || prev == " " || prev == "." { return 20 }
        if orig[j].isUppercase && orig[j - 1].isLowercase { return 16 }
        return 0
    }
}
