import Foundation

struct Todo: Identifiable, Decodable, Sendable {
  var id: Int
  var name: String
}
