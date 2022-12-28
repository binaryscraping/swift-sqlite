import Foundation

#if os(Linux)
  import Csqlite3
#else
  import SQLite3
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLite {
  private let queue = DispatchQueue(label: "co.binaryscraping.sqlite")
  private var handle: OpaquePointer?

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
    sqlite3_close_v2(handle)
  }

  public func execute(_ sql: String) throws {
    try queue.sync {
      _ = try self.validate(
        sqlite3_exec(handle, sql, nil, nil, nil)
      )
    }
  }

  @discardableResult
  public func execute(_ sql: String, _ bindings: [DataType]) throws -> [Row] {
    try queue.sync {
      var stmt: OpaquePointer?
      try validate(sqlite3_prepare_v2(handle, sql, -1, &stmt, nil))
      defer { sqlite3_finalize(stmt) }
      for (idx, binding) in zip(Int32(1)..., bindings) {
        switch binding {
        case .null:
          try validate(sqlite3_bind_null(stmt, idx))
        case let .integer(value):
          try validate(sqlite3_bind_int64(stmt, idx, value))
        case let .real(value):
          try validate(sqlite3_bind_double(stmt, idx, value))
        case let .text(value):
          try validate(sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT))
        case let .blob(value):
          try value.withUnsafeBytes {
            _ = try validate(
              sqlite3_bind_blob(stmt, idx, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
            )
          }
        }
      }
      let cols = sqlite3_column_count(stmt)
      var rows: [[DataType]] = []
      while try validate(sqlite3_step(stmt)) == SQLITE_ROW {
        rows.append(
          (0 ..< cols).map { idx -> DataType in
            let columnType = sqlite3_column_type(stmt, idx)
            switch columnType {
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
              fatalError("Unsupported column type: \(columnType)")
            }
          }
        )
      }
      return rows
    }
  }

  @discardableResult
  public func execute(_ sql: String, _ bindings: DataType...) throws -> [Row] {
    try execute(sql, bindings)
  }

  public var lastInsertRowId: Int64 {
    queue.sync {
      sqlite3_last_insert_rowid(handle)
    }
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE
    else { throw Error(code: code) }
    return code
  }

  public struct Error: Swift.Error, Equatable {
    public var code: Int32?
    public var description: String
    init(code: Int32) {
      self.code = code
      description = String(cString: sqlite3_errstr(code))
    }
  }
}
