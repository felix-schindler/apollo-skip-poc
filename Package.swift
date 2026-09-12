// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "apollo-test",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TanukiApp", type: .dynamic, targets: ["TanukiApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.8"),
        .package(url: "https://github.com/skiptools/skip-fuse-ui.git", from: "1.18.2"),
        .package(url: "https://github.com/apollographql/apollo-ios", from: "2.4.0"),
        .package(path: "./GitLabAPI")
    ],
    targets: [
        .target(name: "TanukiApp", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "Apollo", package: "apollo-ios"),
            .product(name: "ApolloAPI", package: "apollo-ios"),
            .product(name: "ApolloSQLite", package: "apollo-ios"),
            .product(name: "GitLabAPI", package: "GitLabAPI")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
