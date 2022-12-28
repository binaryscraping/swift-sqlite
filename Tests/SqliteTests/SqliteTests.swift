import XCTest

@testable import Sqlite

final class SqliteTests: XCTestCase {
  func test_Sqlite_CreateTable_InsertAndQueryData() throws {
    let sqlite = try SQLite()

    try sqlite.execute(
      """
          CREATE TABLE IF NOT EXISTS "logs" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
            "inserted_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            "level" INTEGER NOT NULL,
            "msg" TEXT
          );
      """
    )

    try Log.create(in: sqlite, level: .warning, msg: "This is a warning message")
    try Log.create(in: sqlite, level: .error, msg: "This is an error message")

    var allLogs = try Log.fetchAll(in: sqlite)

    XCTAssertEqual(allLogs.count, 2)

    XCTAssertEqual(allLogs[0].level, .warning)
    XCTAssertEqual(allLogs[0].msg, "This is a warning message")

    XCTAssertEqual(allLogs[1].level, .error)
    XCTAssertEqual(allLogs[1].msg, "This is an error message")

    try sqlite.execute(
      """
        DELETE FROM "logs" WHERE "id" = ?;
      """,
      .integer(allLogs[0].id)
    )

    allLogs = try Log.fetchAll(in: sqlite)
    XCTAssertEqual(allLogs.count, 1)
    XCTAssertEqual(allLogs[0].level, .error)
    XCTAssertEqual(allLogs[0].msg, "This is an error message")
  }
}

struct Log {
  let id: Int64
  let insertedAt: Date
  let level: Level
  let msg: String

  enum Level: Int {
    case warning, error
  }

  static func create(in sqlite: SQLite, level: Level, msg: String) throws {
    try sqlite.execute(
      """
          INSERT INTO "logs" (
              "level", "msg"
          )
          VALUES (
              ?, ?
          );
      """,
      .integer(Int64(level.rawValue)),
      .text(msg)
    )
  }

  static func fetchAll(in sqlite: SQLite) throws -> [Log] {
    try sqlite.execute(
      """
      SELECT
          "id", "inserted_at", "level", "msg"
      FROM
          "logs"
      """
    )
    .map { row in
      Log(
        id: row[0].integerValue ?? 0,
        insertedAt: row[1].realValue.flatMap(Date.init(timeIntervalSince1970:)) ?? Date(),
        level: row[2].integerValue.map { Int($0) }.flatMap(Level.init(rawValue:)) ?? .warning,
        msg: row[3].textValue ?? ""
      )
    }
  }
}
