import Foundation

#if os(Linux)
  import Csqlite3
#else
  import SQLite3
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLite {
  private let queue = DispatchQueue(label: "co.binaryscraping.sqlite")
  public private(set) var handle: OpaquePointer?

  /// Initialize an ``SQLite`` connection to a database at specified `path`.
  /// - Parameter path: path to the `.sqlite` database file.
  public init(path: String) throws {
    try validate(
      sqlite3_open_v2(
        path,
        &handle,
        SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
        nil
      )
    )
  }

  /// Initialize a in memory ``SQLite`` connection.
  public convenience init() throws {
    try self.init(path: "")
  }

  deinit {
    sqlite3_close_v2(self.handle)
  }

  public func execute(_ sql: String) throws {
    try queue.sync {
      _ = try self.validate(
        sqlite3_exec(self.handle, sql, nil, nil, nil)
      )
    }
  }

  @discardableResult
  public func execute(_ sql: String, _ bindings: [Datatype]) throws -> [Row] {
    try queue.sync {
      var stmt: OpaquePointer?
      try self.validate(sqlite3_prepare_v2(self.handle, sql, -1, &stmt, nil))
      defer { sqlite3_finalize(stmt) }
      for (idx, binding) in zip(Int32(1)..., bindings) {
        switch binding {
        case .null:
          try self.validate(sqlite3_bind_null(stmt, idx))
        case let .integer(value):
          try self.validate(sqlite3_bind_int64(stmt, idx, value))
        case let .real(value):
          try self.validate(sqlite3_bind_double(stmt, idx, value))
        case let .text(value):
          try self.validate(sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT))
        case let .blob(value):
          try value.withUnsafeBytes {
            _ = try self.validate(
              sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
            )
          }
        }
      }
      let cols = sqlite3_column_count(stmt)
      var rows: [[Datatype]] = []
      while try self.validate(sqlite3_step(stmt)) == SQLITE_ROW {
        rows.append(
          try (0 ..< cols).map { idx -> Datatype in
            switch sqlite3_column_type(stmt, idx) {
            case SQLITE_BLOB:
              if let bytes = sqlite3_column_blob(stmt, idx) {
                let count = Int(sqlite3_column_bytes(stmt, idx))
                return .blob(Data(bytes: bytes, count: count))
              }
              return .blob(Data())
            case SQLITE_FLOAT:
              return .real(sqlite3_column_double(stmt, idx))
            case SQLITE_INTEGER:
              return .integer(sqlite3_column_int64(stmt, idx))
            case SQLITE_NULL:
              return .null
            case SQLITE_TEXT:
              return .text(String(cString: sqlite3_column_text(stmt, idx)))
            default:
              throw Error(description: "fatal")
            }
          }
        )
      }
      return rows
    }
  }

  @discardableResult
  public func execute(_ sql: String, _ bindings: Datatype...) throws -> [Row] {
    try execute(sql, bindings)
  }

  public var lastInsertRowId: Int64 {
    queue.sync {
      sqlite3_last_insert_rowid(self.handle)
    }
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE
    else { throw Error(code: code) }
    return code
  }

  public enum Datatype: Equatable {
    case blob(Data)
    case integer(Int64)
    case null
    case real(Double)
    case text(String)
  }

  public typealias Row = [Datatype]

  public struct Error: Swift.Error, Equatable {
    public var code: Int32?
    public var description: String
  }
}

extension SQLite.Error {
  init(code: Int32) {
    self.code = code
    description = String(cString: sqlite3_errstr(code))
  }
}

extension SQLite.Datatype {
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
