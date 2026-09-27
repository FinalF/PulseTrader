import Foundation

struct Stock: Identifiable, Codable, Equatable, Hashable {
    var id: String { symbol }
    let symbol: String
    var displayName: String?
}
