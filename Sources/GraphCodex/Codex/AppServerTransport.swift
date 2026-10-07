import Foundation

protocol CodexTransport: Sendable {
    func request(method: String, params: [String: Any]) async throws -> [String: Any]
}
