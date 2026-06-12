// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "UUSwiftNetworking",
	platforms: [
		.iOS(.v15),
		.macOS(.v11)
	],

	products: [
		.library(
			name: "UUSwiftNetworking",
			targets: ["UUSwiftNetworking"]),
	],

	dependencies: [
		.package(
			url: "https://github.com/SilverPineSoftware/UUSwiftCore.git",
            from: "1.5.0"
		),
        .package(
            url: "https://github.com/SilverPineSoftware/UUSwiftTestCore.git",
            from: "0.0.4"
        )
	],

	targets: [
		.target(
			name: "UUSwiftNetworking",
			dependencies: ["UUSwiftCore"],
			path: "Library",
			exclude: ["Info.plist"]),
        
        .testTarget(
            name: "UUSwiftNetworkingTests",
            dependencies: ["UUSwiftTestCore", "UUSwiftCore", "UUSwiftNetworking"],
            path: "LibraryTest",
            resources: [
                .process("TestConfig.json"),
                .process("TestJpeg_0001.JPG")
            ]),
	],
    swiftLanguageModes: [
		.v4_2,
		.v5,
        .v6
	]
)
