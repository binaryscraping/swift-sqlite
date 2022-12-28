import Foundation

extension SQLite {
  public typealias Row = [DataType]

  public enum DataType: Equatable, Hashable {
    case blob(Data)
    case integer(Int64)
    case null
    case real(Double)
    case text(String)

    public var blobValue: Data? {
      guard case let .blob(value) = self else {
        return nil
      }

      return value
    }

    public var integerValue: Int64? {
      guard case let .integer(value) = self else {
        return nil
      }

      return value
    }

    public var realValue: Double? {
      guard case let .real(value) = self else {
        return nil
      }

      return value
    }

    public var textValue: String? {
      guard case let .text(value) = self else {
        return nil
      }

      return value
    }

    public var isNull: Bool { self == .null }
  }
}
