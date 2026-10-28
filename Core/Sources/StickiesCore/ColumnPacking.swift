import Foundation

/// Places cards of different heights into columns, like notes pinned to a
/// board: each card goes to whichever column is shortest so far. Cards keep
/// the column they were given (`keep`) so that moving one card out doesn't
/// shuffle every card after it into a different column.
public enum ColumnPacking {
    /// - Parameters:
    ///   - ids: cards in reading order.
    ///   - heights: estimated height of each card, same order.
    ///   - columns: how many columns fit.
    ///   - keep: columns given out earlier; used when still in range.
    /// - Returns: the column of every card.
    public static func assign<ID: Hashable>(ids: [ID], heights: [Double], columns: Int, keep: [ID: Int] = [:]) -> [ID: Int] {
        let n = max(1, columns)
        var filled = [Double](repeating: 0, count: n)
        var out: [ID: Int] = [:]
        out.reserveCapacity(ids.count)
        for (id, h) in zip(ids, heights) {
            let c: Int
            if let kept = keep[id], kept < n {
                c = kept
            } else {
                c = filled.indices.min { filled[$0] < filled[$1] }!
            }
            out[id] = c
            filled[c] += h
        }
        return out
    }

    /// The cards of each column, top to bottom, in reading order.
    public static func columns<ID: Hashable>(ids: [ID], assignment: [ID: Int], count: Int) -> [[ID]] {
        var cols = [[ID]](repeating: [], count: max(1, count))
        for id in ids { cols[min(assignment[id] ?? 0, cols.count - 1)].append(id) }
        return cols
    }
}
