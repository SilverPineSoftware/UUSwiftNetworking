// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "UUSwiftNetworking",
	platforms: [
		.iOS(.v10),
		.macOS(.v10_15)
	],

	products: [
		.library(
			name: "UUSwiftNetworking",
			targets: ["UUSwiftNetworking"]),
	],

	dependencies: [
		.package(
			url: "https://github.com/SilverPineSoftware/UUSwiftCore.git",
			from: "1.1.2"
		)
	],

	targets: [
		.target(
			name: "UUSwiftNetworking",
			dependencies: ["UUSwiftCore"],
			path: "UUSwiftNetworking",
			exclude: ["Info.plist"])
	],
	swiftLanguageVersions: [
		.v4_2,
		.v5
	]
)
