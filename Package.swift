// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-picture",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)],
    products: [
        .library(name: "Picture", targets: ["Picture"]),
        .library(name: "Picture CPU", targets: ["Picture CPU"]),
        .library(name: "Picture PNG Integration", targets: ["Picture PNG Integration"]),
        .library(name: "Picture Store", targets: ["Picture Store"]),
        .library(name: "Picture Test Support", targets: ["Picture Test Support"]),
    ],
    traits: [
        .trait(name: "PNG", description: "PNG integration"),
        .trait(name: "Store", description: "Drawn pictures kept in a directory under a key of what decides their pixels"),
        .trait(name: "Threads", description: "Picture CPU draws a frame on several threads"),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-angle.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-direction.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-geometry.git", branch: "main", traits: ["Affine"]),
        .package(url: "https://github.com/swift-compositions/swift-kernel.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-matrix.git", branch: "main", traits: ["Projection", "Quaternion", "Trigonometry"]),
        .package(url: "https://github.com/swift-atoms/swift-mesh.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-noise.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-numeric.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-point.git", branch: "main", traits: ["Affine"]),
        .package(url: "https://github.com/swift-atoms/swift-projection.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-quaternion.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-refraction.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-renderer.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-threefry.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-vector.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-witnesses.git", branch: "main"),
        .package(url: "https://github.com/swift-iec/swift-iec-61966.git", branch: "main"),
        .package(url: "https://github.com/swift-iso/swift-iso-14496-22.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-typesetting.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-raster.git", branch: "main", traits: ["Geometry"]),
        .package(url: "https://github.com/swift-standards/swift-color-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-w3c/swift-w3c-css.git", branch: "main"),
        .package(url: "https://github.com/swift-w3c/swift-w3c-png.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-standards/swift-fips-180-4.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-1950.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Picture",
            dependencies: [
                .product(name: "Angle", package: "swift-angle"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Color Standard", package: "swift-color-standard"),
                .product(name: "Direction", package: "swift-direction"),
                .product(name: "Geometry", package: "swift-geometry"),
                .product(name: "IEC 61966", package: "swift-iec-61966"),
                .product(name: "Matrix", package: "swift-matrix"),
                .product(name: "Mesh", package: "swift-mesh"),
                .product(name: "Noise", package: "swift-noise"),
                .product(name: "Numeric", package: "swift-numeric"),
                .product(name: "Point", package: "swift-point"),
                .product(name: "Projection", package: "swift-projection"),
                .product(name: "Quaternion", package: "swift-quaternion"),
                .product(name: "Raster", package: "swift-raster"),
                .product(name: "Refraction", package: "swift-refraction"),
                .product(name: "Renderer", package: "swift-renderer"),
                .product(name: "Threefry", package: "swift-threefry"),
                .product(name: "Typesetting", package: "swift-typesetting"),
                .product(name: "Vector", package: "swift-vector"),
                .product(name: "W3C CSS Compositing", package: "swift-w3c-css"),
                .product(name: "Witnesses", package: "swift-witnesses"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),
        .target(
            name: "Picture CPU",
            dependencies: [
                .target(name: "Picture"),
                .product(name: "Kernel Thread", package: "swift-kernel", condition: .when(traits: ["Threads"])),
                .product(name: "Numeric", package: "swift-numeric"),
            ]
        ),
        .target(
            name: "Picture PNG Integration",
            dependencies: [
                .target(name: "Picture"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "IEC 61966", package: "swift-iec-61966"),
                .product(name: "W3C PNG", package: "swift-w3c-png", condition: .when(traits: ["PNG"])),
            ]
        ),
        .target(
            name: "Picture Store",
            dependencies: [
                .target(name: "Picture"),
                .target(name: "Picture CPU"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system", condition: .when(traits: ["Store"])),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4", condition: .when(traits: ["Store"])),
                .product(name: "RFC 1950", package: "swift-rfc-1950", condition: .when(traits: ["Store"])),
                .product(
                    name: "Standard Library Extensions",
                    package: "swift-standard-library-extensions",
                    condition: .when(traits: ["Store"])
                ),
            ]
        ),
        .target(
            name: "Picture Test Support",
            dependencies: [
                .target(name: "Picture"),
                .product(name: "Numeric", package: "swift-numeric"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Picture Tests",
            dependencies: [
                .target(name: "Picture"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .target(name: "Picture Test Support"),
                .product(name: "Color Standard", package: "swift-color-standard"),
                .product(name: "ISO 14496-22 Test Support", package: "swift-iso-14496-22"),
                .product(name: "Numeric", package: "swift-numeric"),
            ]
        ),
        .testTarget(
            name: "Picture CPU Tests",
            dependencies: [
                .target(name: "Picture CPU"),
                .product(name: "ISO 14496-22 Test Support", package: "swift-iso-14496-22"),
                .product(name: "Numeric", package: "swift-numeric"),
            ]
        ),
        .testTarget(
            name: "Picture Store Tests",
            dependencies: [
                .target(name: "Picture Store"),
                .target(name: "Picture CPU"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "File System", package: "swift-file-system"),
            ]
        ),
        .testTarget(
            name: "Picture PNG Integration Tests",
            dependencies: [
                .target(name: "Picture PNG Integration"),
                .product(name: "IEC 61966", package: "swift-iec-61966"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
