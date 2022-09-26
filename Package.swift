// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CosyncStorageSwift",
    platforms: [
           .iOS(.v12) 
       ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CosyncStorageSwift",
            targets: ["CosyncStorageSwift"]),
        .library(
            name: "AssetPicker",
            targets: ["AssetPicker"]),
        .library(
            name: "CameraPhotoManager",
            targets: ["CameraPhotoManager"]),
       
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url:"https://github.com/realm/realm-swift.git", from: "10.30.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CosyncStorageSwift",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "Realm", package: "realm-swift")],
            path: "Sources/CosyncStorageSwift"),
        .target(
            name: "AssetPicker",
            path: "Sources/Asset"),
        
        .target(
            name: "CameraPhotoManager",
            path: "Sources/CameraPhoto"), 
        
        .testTarget(
            name: "CosyncStorageSwiftTests",
            dependencies: ["CosyncStorageSwift"]),
    ]
)
