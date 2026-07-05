// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacBookPet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacBookPet", targets: ["MacBookPet"])
    ],
    targets: [
        .executableTarget(name: "MacBookPet"),
        .testTarget(name: "MacBookPetTests", dependencies: ["MacBookPet"])
    ]
)
