// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Sqlite",
  platforms: [
    .iOS(.v9),
    .macOS(.v10_10),
  ],
  products: [
    .library(
      name: "Sqlite",
      targets: ["Sqlite"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Sqlite",
      dependencies: [
        .target(name: "Csqlite3"),
      ]
    ),
    .testTarget(
      name: "SqliteTests",
      dependencies: ["Sqlite"]
    ),
    .systemLibrary(
      name: "Csqlite3",
      providers: [
        .apt(["libsqlite3-dev"]),
        .brew(["sqlite3"]),
      ]
    ),
  ]
)
