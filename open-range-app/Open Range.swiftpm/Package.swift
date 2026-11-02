// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Open Range",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Open Range",
            targets: ["AppModule"],
            bundleIdentifier: "academy.lifequestions.openrange",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .bicycle),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .bluetoothAlways(purposeString: "Open Range connects to your Cowboy bike over Bluetooth to change its motor settings."),
                .locationWhenInUse(purposeString: "Open Range uses GPS to show how fast you're riding.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
