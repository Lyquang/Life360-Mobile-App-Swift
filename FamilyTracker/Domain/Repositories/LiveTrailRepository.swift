import Foundation

protocol LiveTrailRepository {
    func snapshot(userId: String, date: String, limit: Int) async throws -> LiveTrailSnapshot
    func catchUp(userId: String, date: String, afterSeq: Int, revision: Int,
                 limit: Int) async throws -> LiveTrailSnapshot
}
