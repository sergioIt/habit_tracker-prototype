// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "habit-tracker-prototype",
    targets: [
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3"
        ),
        .executableTarget(
            name: "habit-tracker-prototype",
            dependencies: ["CSQLite"],
            path: "Sources/HabitTracker"
        ),
        .testTarget(
            name: "HabitTrackerTests",
            dependencies: ["habit-tracker-prototype"],
            path: "Tests/HabitTrackerTests"
        )
    ]
)
