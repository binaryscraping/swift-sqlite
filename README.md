# `swift-sqlite`

The simplest SQLite wrapper for Swift possible.

## Usage

```swift
let sqlite = try Sqlite(path: "/path/to/db.sqlite")

try sqlite.execute(
  """
      CREATE TABLE IF NOT EXISTS "tasks" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        "inserted_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "description" TEXT NOT NULL,
        "is_complete" BOOLEAN NOT NULL DEFAULT FALSE
      );
  """)
  
try sqlite.run(
  """
      INSERT INTO "tasks" (
          "description"
      ) VALUES (
          ?
      )
  """,
  .text("Write tests for swift-sqlite library.")
)
```
