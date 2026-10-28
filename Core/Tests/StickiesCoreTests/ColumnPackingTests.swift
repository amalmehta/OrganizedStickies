import Testing
@testable import StickiesCore

@Suite struct ColumnPackingTests {
    @Test func tallCardsDoNotStackInOneColumn() {
        // A tall card first: the next two short ones go beside it.
        let a = ColumnPacking.assign(ids: ["tall", "s1", "s2", "s3"], heights: [300, 100, 100, 100], columns: 2)
        #expect(a["tall"] == 0)
        #expect(a["s1"] == 1 && a["s2"] == 1 && a["s3"] == 1)
    }

    @Test func removingACardKeepsOthersInPlace() {
        let ids = ["a", "b", "c", "d", "e", "f"]
        let h: [Double] = [120, 200, 120, 160, 120, 120]
        let first = ColumnPacking.assign(ids: ids, heights: h, columns: 3)
        var rest = ids; rest.remove(at: 1)
        var hRest = h; hRest.remove(at: 1)
        let second = ColumnPacking.assign(ids: rest, heights: hRest, columns: 3, keep: first)
        for id in rest { #expect(second[id] == first[id], "\(id) moved column") }
    }

    @Test func newCardsGoToTheShortestColumn() {
        let keep = ["a": 0, "b": 1]
        let a = ColumnPacking.assign(ids: ["new", "a", "b"], heights: [100, 300, 100], columns: 2, keep: keep)
        // "new" is placed first, when both columns are empty: column 0.
        #expect(a["new"] == 0)
        let later = ColumnPacking.assign(ids: ["a", "b", "new"], heights: [300, 100, 100], columns: 2, keep: keep)
        #expect(later["new"] == 1)
    }

    @Test func fewerColumnsReassignsOutOfRangeCards() {
        let a = ColumnPacking.assign(ids: ["a", "b", "c"], heights: [1, 1, 1], columns: 1, keep: ["a": 2, "b": 1])
        #expect(Set(a.values) == [0])
        let cols = ColumnPacking.columns(ids: ["a", "b", "c"], assignment: a, count: 1)
        #expect(cols == [["a", "b", "c"]])
    }

    @Test func columnsKeepReadingOrder() {
        let ids = ["a", "b", "c", "d"]
        let a = ["a": 0, "b": 1, "c": 0, "d": 1]
        #expect(ColumnPacking.columns(ids: ids, assignment: a, count: 2) == [["a", "c"], ["b", "d"]])
    }
}
