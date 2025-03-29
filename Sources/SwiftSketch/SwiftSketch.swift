//
//  SwiftSketch.swift
//  SwiftSketch
//
//  Created by Chung Yun Lee on 28/3/2025.
//

import ArgumentParser
import Foundation

@main
struct SwiftSketch: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "swift-sketch",
        abstract: "A tool for quickly scaffolding Swift projects and packages",
        discussion: """
        Swift Sketch helps you create Swift packages and projects with sensible defaults
        and modern architecture patterns. Generate single or modular packages with
        SwiftUI or UIKit support, and even create XCode projects automatically.
        
        Examples:
          swift-sketch create MyPackage --colors "#FF0000=Red,#00FF00=Green,#0000FF=Blue"
          swift-sketch create MyApp --modular --generate-project --project-tool tuist
          swift-sketch create MyFramework --ios-version 17.0
          swift-sketch create MySDK --modular --module-prefix "ABC" --ios-version 16.2
        """,
        version: "1.0.0",
        subcommands: [Create.self, Template.self],
        defaultSubcommand: Create.self
    )
}

// MARK: - Create Subcommand
extension SwiftSketch {
    struct Create: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Create a new Swift package or project"
        )
        
        @Argument(help: "The name of the Swift Package to generate")
        var name: String

        @Option(name: .customLong("colors"), help: "Comma-separated list of colors in format #HEX=Name")
        var colors: String?

        @Option(name: [.customShort("o"), .customLong("output")], help: "Output directory for the package")
        var output: String = FileManager.default.currentDirectoryPath

        @Flag(name: .customLong("generate-project"), help: "Generate an Xcode project alongside the Swift Package")
        var generateXcodeProject: Bool = false
        
        @Option(name: .customLong("project-tool"), help: "Project generation tool (tuist, xcodegen, or none)")
        var projectTool: String = "tuist"
        
        @Flag(name: .customLong("modular"), help: "Generate a modular architecture with App, Core, UI, and Util modules")
        var modular: Bool = false
        
        @Option(name: .customLong("org"), help: "Organization identifier (e.g., com.company)")
        var organization: String = "com.yourorganization"
        
        @Option(name: .customLong("xcode-version"), help: "Xcode version to use (e.g., 16.2)")
        var xcodeVersion: String = getDefaultXcodeVersion()
        
        @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Show verbose output during generation")
        var verbose: Bool = false
        
        @Option(name: .customLong("module-prefix"), help: "Prefix for module names in modular architecture (e.g., 'ABC' makes Core become ABCCore)")
        var modulePrefix: String?
        
        @Option(name: .customLong("ios-version"), help: "Minimum iOS version (e.g., 16.0, 16.1, 17.0)")
        var iosVersion: String = "16.0"

        func run() throws {
            if verbose {
                print("Generating Swift package '\(name)'...")
                print("Output directory: \(output)")
                if modular {
                    print("Using modular architecture")
                    if let prefix = modulePrefix {
                        print("With module prefix: \(prefix)")
                    }
                }
                print("iOS version: \(iosVersion)")
            }
            
            let packageDir = URL(fileURLWithPath: output).appendingPathComponent(name)
            
            // Create the base directory
            try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
            
            // First step: Generate the package architecture (modular or single)
            if modular {
                try generateModularArchitecture(at: packageDir)
            } else {
                // Traditional single-module SPM package
                try initializeSwiftPackage(at: packageDir)
                
                // Generate colors as XCAssets for single-module package
                let parsedColors = parseColors(colors)
                if !parsedColors.isEmpty {
                    if verbose {
                        print("Generating \(parsedColors.count) colors...")
                    }
                    try generateColorAssets(at: packageDir, colors: parsedColors)
                    try generateColorSwiftFile(at: packageDir, colors: parsedColors)
                }
            }
            
            // Second step: Generate project files if requested
            if generateXcodeProject {
                if verbose {
                    print("Generating Xcode project using \(projectTool)...")
                }
                
                if modular {
                    // Generate project files for modular architecture
                    switch projectTool.lowercased() {
                    case "tuist":
                        try generateTuistProjectForModular(at: packageDir)
                    case "xcodegen":
                        try generateXcodeGenProjectForModular(at: packageDir)
                    case "none":
                        break
                    default:
                        throw ValidationError("Unknown project tool: \(projectTool). Supported options are: tuist, xcodegen, none")
                    }
                } else {
                    // Generate project files for single module architecture
                    switch projectTool.lowercased() {
                    case "tuist":
                        try generateSimpleTuistProject(at: packageDir)
                    case "xcodegen":
                        try generateXcodeGenProject(at: packageDir)
                    case "none":
                        break
                    default:
                        throw ValidationError("Unknown project tool: \(projectTool). Supported options are: tuist, xcodegen, none")
                    }
                }
            }
            
            printSuccess(packageDir: packageDir)
        }
        
        private func printSuccess(packageDir: URL) {
            print("✅ Swift Package '\(name)' generated at \(packageDir.path)")
            if generateXcodeProject && projectTool.lowercased() != "none" {
                print("🔨 Xcode project generation prepared using \(projectTool)")
                print("\nTo generate the project:")
                if projectTool.lowercased() == "tuist" {
                    print("  cd \(packageDir.path)")
                    print("  tuist generate")
                } else if projectTool.lowercased() == "xcodegen" {
                    print("  cd \(packageDir.path)")
                    print("  xcodegen generate")
                }
            }
            
            if modular {
                // Get the module names with prefix if provided
                let coreModuleName = modulePrefix != nil ? "\(modulePrefix!)Core" : "Core"
                let uiModuleName = modulePrefix != nil ? "\(modulePrefix!)UI" : "UI"
                let utilModuleName = modulePrefix != nil ? "\(modulePrefix!)Util" : "Util"
                
                print("\n📦 Modular architecture with local Swift Packages:")
                print("- Main app with SwiftUI starter code")
                print("- Packages/\(coreModuleName): Business logic module")
                print("- Packages/\(uiModuleName): User interface components with color assets")
                print("- Packages/\(utilModuleName): Utilities and helpers")
                
                if modulePrefix != nil {
                    print("\nModule prefix '\(modulePrefix!)' applied to all package names")
                }
                
                print("\niOS version set to: \(iosVersion.hasPrefix("v") ? iosVersion : "v\(iosVersion)")")
            }
        }

        // Generate modular architecture independent of project tool
        private func generateModularArchitecture(at url: URL) throws {
            // Apply module prefix to package names if provided
            let coreModuleName = modulePrefix != nil ? "\(modulePrefix!)Core" : "Core"
            let uiModuleName = modulePrefix != nil ? "\(modulePrefix!)UI" : "UI"
            let utilModuleName = modulePrefix != nil ? "\(modulePrefix!)Util" : "Util"
            
            // Create main app structure
            let sourcesDir = url.appendingPathComponent("Sources")
            try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
            
            let resourcesDir = url.appendingPathComponent("Resources")
            try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            
            let testsDir = url.appendingPathComponent("Tests")
            try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)
            
            // Create App file with modern SwiftUI approach
            let appSwift = """
            import SwiftUI
            import \(coreModuleName)
            import \(uiModuleName)
            import \(utilModuleName)

            @main
            struct \(name)App: App {
                var body: some Scene {
                    WindowGroup {
                        ContentView()
                    }
                }
            }
            """
            
            // Create ContentView
            let contentViewSwift = """
            import SwiftUI
            import \(uiModuleName)

            struct ContentView: View {
                var body: some View {
                    VStack(spacing: 20) {
                        Text("Welcome to \(name)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                        
                        // Example of using colors from UI package
                        VStack(spacing: 16) {
                            Text("UI Module Colors")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                colorSample(Color.uiColors.red, name: "Red")
                                colorSample(Color.uiColors.green, name: "Green")
                                colorSample(Color.uiColors.blue, name: "Blue")
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 4))
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                }
                
                @ViewBuilder
                func colorSample(_ color: Color, name: String) -> some View {
                    VStack {
                        Circle()
                            .fill(color)
                            .frame(width: 60, height: 60)
                            .shadow(radius: 2)
                        
                        Text(name)
                            .font(.caption)
                    }
                }
            }

            #Preview {
                ContentView()
            }
            """
            
            try appSwift.write(to: sourcesDir.appendingPathComponent("\(name)App.swift"), atomically: true, encoding: .utf8)
            try contentViewSwift.write(to: sourcesDir.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
            
            // Create a LaunchScreen.storyboard
            let launchScreenStoryboard = """
            <?xml version="1.0" encoding="UTF-8"?>
            <document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21507" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
                <device id="retina6_12" orientation="portrait" appearance="light"/>
                <dependencies>
                    <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21505"/>
                    <capability name="Safe area layout guides" minToolsVersion="9.0"/>
                    <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
                </dependencies>
                <scenes>
                    <!--View Controller-->
                    <scene sceneID="EHf-IW-A2E">
                        <objects>
                            <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                                <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                                    <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                                    <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                                    <subviews>
                                        <label opaque="NO" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="\(name)" textAlignment="natural" lineBreakMode="tailTruncation" baselineAdjustment="alignBaselines" adjustsFontSizeToFit="NO" translatesAutoresizingMaskIntoConstraints="NO" id="OZG-Ky-L6h">
                                            <rect key="frame" x="140.66666666666666" y="415.66666666666669" width="112" height="21"/>
                                            <fontDescription key="fontDescription" type="system" pointSize="17"/>
                                            <nil key="textColor"/>
                                            <nil key="highlightedColor"/>
                                        </label>
                                    </subviews>
                                    <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                                    <color key="backgroundColor" white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
                                    <constraints>
                                        <constraint firstItem="OZG-Ky-L6h" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="LbE-LQ-l4e"/>
                                        <constraint firstItem="OZG-Ky-L6h" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="qr4-eA-nS9"/>
                                    </constraints>
                                </view>
                            </viewController>
                            <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userInteractionEnabled="NO" contentMode="scaleToFill" sceneMemberID="firstResponder"/>
                        </objects>
                        <point key="canvasLocation" x="53" y="375"/>
                    </scene>
                </scenes>
            </document>
            """
            
            try launchScreenStoryboard.write(to: resourcesDir.appendingPathComponent("LaunchScreen.storyboard"), atomically: true, encoding: .utf8)
            
            // Create a basic test file
            let testSwift = """
            import XCTest
            @testable import \(name)

            final class \(name)Tests: XCTestCase {
                func testExample() {
                    XCTAssertTrue(true)
                }
            }
            """
            
            try testSwift.write(to: testsDir.appendingPathComponent("\(name)Tests.swift"), atomically: true, encoding: .utf8)
            
            // Create packages directory for local Swift packages
            let packagesDir = url.appendingPathComponent("Packages")
            try FileManager.default.createDirectory(at: packagesDir, withIntermediateDirectories: true)
            
            // Create Core, UI, and Util packages with prefixes if provided
            try createSwiftPackage(at: packagesDir.appendingPathComponent(coreModuleName),
                                  name: coreModuleName,
                                  dependencies: [utilModuleName])
            
            try createSwiftPackage(at: packagesDir.appendingPathComponent(utilModuleName),
                                  name: utilModuleName,
                                  dependencies: [])
            
            try createSwiftPackage(at: packagesDir.appendingPathComponent(uiModuleName),
                                  name: uiModuleName,
                                  dependencies: [utilModuleName])
            
            // Generate color assets in UI package resources
            let parsedColors = parseColors(colors)
            if !parsedColors.isEmpty {
                let uiResourcesDir = packagesDir.appendingPathComponent("\(uiModuleName)/Sources/\(uiModuleName)/Resources")
                try FileManager.default.createDirectory(at: uiResourcesDir, withIntermediateDirectories: true)
                
                let colorsDir = uiResourcesDir.appendingPathComponent("Colors.xcassets")
                try FileManager.default.createDirectory(at: colorsDir, withIntermediateDirectories: true)
                
                // Generate the color assets in the UI package
                try generateColorsInDirectory(at: colorsDir, colors: parsedColors)
                
                // Generate color extension file in UI package
                try generateColorSwiftFile(at: packagesDir.appendingPathComponent(uiModuleName),
                                          moduleName: uiModuleName,
                                          colors: parsedColors)
            }
        }
        
        // Generate Tuist project files for modular architecture
        func generateTuistProjectForModular(at url: URL) throws {
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedIosVersion = normalizedIosVersion(iosVersion)
            
            // Apply module prefix to package names if provided
            let coreModuleName = modulePrefix != nil ? "\(modulePrefix!)Core" : "Core"
            let uiModuleName = modulePrefix != nil ? "\(modulePrefix!)UI" : "UI"
            let utilModuleName = modulePrefix != nil ? "\(modulePrefix!)Util" : "Util"
            
            // Create the Project.swift file for Tuist at root (single project with local packages)
            let projectSwift = """
            import ProjectDescription

            let project = Project(
                name: "\(name)",
                organizationName: "\(organization.split(separator: ".").last ?? "YourOrganization")",
                options: .options(
                    automaticSchemesOptions: .disabled,
                    disableBundleAccessors: false,
                    disableSynthesizedResourceAccessors: false
                ),
                packages: [
                    .local(path: "./Packages/\(coreModuleName)"),
                    .local(path: "./Packages/\(uiModuleName)"),
                    .local(path: "./Packages/\(utilModuleName)")
                ],
                settings: .settings(
                    base: [:],
                    configurations: [
                        .debug(name: "Debug"),
                        .release(name: "Release")
                    ]
                ),
                targets: [
                    .target(
                        name: "\(name)",
                        destinations: .iOS,
                        product: .app,
                        bundleId: "\(organization).\(name)",
                        deploymentTargets: .iOS("\(normalizedIosVersion)"),
                        infoPlist: .extendingDefault(with: [
                            "UILaunchStoryboardName": "LaunchScreen"
                        ]),
                        sources: ["Sources/**"],
                        resources: ["Resources/**"],
                        dependencies: [
                            .package(product: "\(coreModuleName)"),
                            .package(product: "\(uiModuleName)"),
                            .package(product: "\(utilModuleName)")
                        ]
                    ),
                    .target(
                        name: "\(name)Tests",
                        destinations: .iOS,
                        product: .unitTests,
                        bundleId: "\(organization).\(name)Tests",
                        deploymentTargets: .iOS("\(normalizedIosVersion)"),
                        infoPlist: .default,
                        sources: ["Tests/**"],
                        dependencies: [
                            .target(name: "\(name)")
                        ]
                    )
                ]
            )
            """
            
            let projectSwiftURL = url.appendingPathComponent("Project.swift")
            try projectSwift.write(to: projectSwiftURL, atomically: true, encoding: .utf8)
            
            // Create the Tuist.swift file at root
            let tuistSwift = """
            import ProjectDescription

            let config = Config(
                compatibleXcodeVersions: ["\(xcodeVersion)"],
                plugins: []
            )
            """
            
            let tuistSwiftURL = url.appendingPathComponent("Tuist.swift")
            try tuistSwift.write(to: tuistSwiftURL, atomically: true, encoding: .utf8)
        }
        
        // Generate XcodeGen project files for modular architecture
        func generateXcodeGenProjectForModular(at url: URL) throws {
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedIosVersion = iosVersion.hasPrefix("v") ? String(iosVersion.dropFirst()) : iosVersion
            
            // Apply module prefix to package names if provided
            let coreModuleName = modulePrefix != nil ? "\(modulePrefix!)Core" : "Core"
            let uiModuleName = modulePrefix != nil ? "\(modulePrefix!)UI" : "UI"
            let utilModuleName = modulePrefix != nil ? "\(modulePrefix!)Util" : "Util"
            
            // Create the project.yml file for XcodeGen
            let projectYML = """
            name: \(name)
            options:
              deploymentTarget:
                iOS: \(normalizedIosVersion)
              xcodeVersion: \(xcodeVersion)
              
            packages:
              \(coreModuleName):
                path: ./Packages/\(coreModuleName)
              \(uiModuleName):
                path: ./Packages/\(uiModuleName)
              \(utilModuleName):
                path: ./Packages/\(utilModuleName)
                
            targets:
              \(name):
                type: application
                platform: iOS
                deploymentTarget: \(normalizedIosVersion)
                sources: 
                  - Sources
                resources:
                  - Resources
                dependencies:
                  - package: \(coreModuleName)
                  - package: \(uiModuleName)
                  - package: \(utilModuleName)
                info:
                  path: Info.plist
                  properties:
                    UILaunchStoryboardName: LaunchScreen
                    CFBundleDisplayName: \(name)
                    CFBundleIdentifier: \(organization).\(name)
                settings:
                  base:
                    PRODUCT_BUNDLE_IDENTIFIER: \(organization).\(name)
                    PRODUCT_NAME: \(name)
                    INFOPLIST_FILE: Info.plist
              
              \(name)Tests:
                type: bundle.unit-test
                platform: iOS
                deploymentTarget: \(normalizedIosVersion)
                sources: 
                  - Tests
                dependencies:
                  - target: \(name)
                settings:
                  base:
                    PRODUCT_BUNDLE_IDENTIFIER: \(organization).\(name)Tests
                    PRODUCT_NAME: \(name)Tests
            """
            
            let projectYMLURL = url.appendingPathComponent("project.yml")
            try projectYML.write(to: projectYMLURL, atomically: true, encoding: .utf8)
            
            // Create a basic Info.plist file
            let infoPlist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleDevelopmentRegion</key>
                <string>$(DEVELOPMENT_LANGUAGE)</string>
                <key>CFBundleExecutable</key>
                <string>$(EXECUTABLE_NAME)</string>
                <key>CFBundleIdentifier</key>
                <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
                <key>CFBundleInfoDictionaryVersion</key>
                <string>6.0</string>
                <key>CFBundleName</key>
                <string>$(PRODUCT_NAME)</string>
                <key>CFBundlePackageType</key>
                <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
                <key>CFBundleShortVersionString</key>
                <string>1.0</string>
                <key>CFBundleVersion</key>
                <string>1</string>
                <key>LSRequiresIPhoneOS</key>
                <true/>
                <key>UILaunchStoryboardName</key>
                <string>LaunchScreen</string>
                <key>UIRequiredDeviceCapabilities</key>
                <array>
                    <string>armv7</string>
                </array>
                <key>UISupportedInterfaceOrientations</key>
                <array>
                    <string>UIInterfaceOrientationPortrait</string>
                    <string>UIInterfaceOrientationLandscapeLeft</string>
                    <string>UIInterfaceOrientationLandscapeRight</string>
                </array>
                <key>UISupportedInterfaceOrientations~ipad</key>
                <array>
                    <string>UIInterfaceOrientationPortrait</string>
                    <string>UIInterfaceOrientationPortraitUpsideDown</string>
                    <string>UIInterfaceOrientationLandscapeLeft</string>
                    <string>UIInterfaceOrientationLandscapeRight</string>
                </array>
            </dict>
            </plist>
            """
            
            let infoPlistURL = url.appendingPathComponent("Info.plist")
            try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        }

        // All the methods from SwiftPackageGenerator go here...
        func initializeSwiftPackage(at url: URL) throws {
            let fm = FileManager.default
            try fm.createDirectory(at: url, withIntermediateDirectories: true)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = ["package", "init", "--type", "library", "--name", name]
            process.currentDirectoryURL = url

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(decoding: errorData, as: UTF8.self)
                throw ValidationError("Failed to initialize package: \(errorMessage)")
            }

            try customizePackageSwift(at: url)
        }

        func customizePackageSwift(at url: URL) throws {
            let packageSwiftURL = url.appendingPathComponent("Package.swift")
            var content = try String(contentsOf: packageSwiftURL, encoding: .utf8)
            
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedIosVersion = normalizedIosVersion(iosVersion)
            
            // Add platforms after the name parameter with the specified iOS version
            if let nameRange = content.range(of: "name: \"\(name)\"") {
                let insertionPoint = content.index(after: nameRange.upperBound)
                content.insert(contentsOf: "\n    platforms: [.iOS(\"\(normalizedIosVersion)\")],", at: insertionPoint)
            }
            
            try content.write(to: packageSwiftURL, atomically: true, encoding: .utf8)
        }
        
        func normalizedIosVersion(_ version: String) -> String {
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedVersion = version.hasPrefix("v") ? String(version.dropFirst()) : version
            return normalizedVersion
        }
        
        func generateSimpleTuistProject(at url: URL) throws {
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedIosVersion = iosVersion.hasPrefix("v") ? String(iosVersion.dropFirst()) : iosVersion
            
            // Create simplified Tuist project file at the root
            let projectSwift = """
            import ProjectDescription

            let project = Project(
                name: "\(name)",
                organizationName: "\(organization.split(separator: ".").last ?? "YourOrganization")",
                options: .options(
                    automaticSchemesOptions: .disabled,
                    disableBundleAccessors: false,
                    disableSynthesizedResourceAccessors: false
                ),
                targets: [
                    .target(
                        name: "\(name)",
                        destinations: .iOS,
                        product: .framework,
                        bundleId: "\(organization).\(name)",
                        deploymentTargets: .iOS("\(normalizedIosVersion)"),
                        infoPlist: .default,
                        sources: ["Sources/\(name)/**"],
                        resources: ["Sources/\(name)/Resources/**"],
                        dependencies: []
                    ),
                    .target(
                        name: "\(name)Tests",
                        destinations: .iOS,
                        product: .unitTests,
                        bundleId: "\(organization).\(name)Tests",
                        deploymentTargets: .iOS("\(normalizedIosVersion)"),
                        infoPlist: .default,
                        sources: ["Tests/\(name)Tests/**"],
                        dependencies: [
                            .target(name: "\(name)")
                        ]
                    )
                ]
            )
            """
            
            let projectSwiftURL = url.appendingPathComponent("Project.swift")
            try projectSwift.write(to: projectSwiftURL, atomically: true, encoding: .utf8)
            
            // Create a Tuist.swift file at the root
            let tuistSwift = """
            import ProjectDescription

            let config = Config(
                compatibleXcodeVersions: ["\(xcodeVersion)"],
                plugins: []
            )
            """
            
            let tuistSwiftURL = url.appendingPathComponent("Tuist.swift")
            try tuistSwift.write(to: tuistSwiftURL, atomically: true, encoding: .utf8)
        }

        func generateXcodeGenProject(at url: URL) throws {
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedIosVersion = iosVersion.hasPrefix("v") ? String(iosVersion.dropFirst()) : iosVersion
            
            let projectYML = """
            name: \(name)
            options:
              deploymentTarget:
                iOS: \(normalizedIosVersion)
            targets:
              \(name):
                type: framework
                platform: iOS
                sources:
                  - Sources/\(name)
                scheme:
                  testTargets:
                    - \(name)Tests
              \(name)Tests:
                type: bundle.unit-test
                platform: iOS
                sources:
                  - Tests/\(name)Tests
                dependencies:
                  - target: \(name)
            """
            
            let ymlURL = url.appendingPathComponent("project.yml")
            try projectYML.write(to: ymlURL, atomically: true, encoding: .utf8)
        }

        func parseColors(_ colors: String?) -> [(hex: String, name: String)] {
            guard let colors = colors else { return [] }
            return colors.split(separator: ",").map { color in
                let parts = color.trimmingCharacters(in: .whitespaces).split(separator: "=")
                guard parts.count == 2 else { fatalError("Invalid color format: \(color)") }
                let hex = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let name = String(parts[1]).trimmingCharacters(in: .whitespaces)
                return (hex: hex, name: name)
            }
        }
        
        func hexToComponents(_ hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
            var hexSanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
            
            if hexSanitized.count == 3 {
                let r = String(hexSanitized[hexSanitized.startIndex])
                let g = String(hexSanitized[hexSanitized.index(hexSanitized.startIndex, offsetBy: 1)])
                let b = String(hexSanitized[hexSanitized.index(hexSanitized.startIndex, offsetBy: 2)])
                hexSanitized = r + r + g + g + b + b
            }
            
            var rgb: UInt64 = 0
            Scanner(string: hexSanitized).scanHexInt64(&rgb)
            
            let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat(rgb & 0x0000FF) / 255.0
            
            return (red, green, blue)
        }
        
        func generateColorAssets(at url: URL, colors: [(hex: String, name: String)]) throws {
            // Create the Resources directory if it doesn't exist
            let resourcesDir = url.appendingPathComponent("Sources/\(name)/Resources")
            let colorsDir = resourcesDir.appendingPathComponent("Colors.xcassets")
            try FileManager.default.createDirectory(at: colorsDir, withIntermediateDirectories: true)
            
            // Generate colors in the directory
            try generateColorsInDirectory(at: colorsDir, colors: colors)
        }
        
        func generateColorsInDirectory(at colorsDir: URL, colors: [(hex: String, name: String)]) throws {
            // Create Contents.json for the asset catalog
            let catalogContents = """
            {
              "info" : {
                "author" : "xcode",
                "version" : 1
              }
            }
            """
            try catalogContents.write(to: colorsDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
            
            // Create each color set
            for color in colors {
                let colorSetDir = colorsDir.appendingPathComponent("\(color.name).colorset")
                try FileManager.default.createDirectory(at: colorSetDir, withIntermediateDirectories: true)
                
                let components = hexToComponents(color.hex)
                
                let colorContents = """
                {
                  "colors" : [
                    {
                      "color" : {
                        "color-space" : "srgb",
                        "components" : {
                          "alpha" : "1.000",
                          "blue" : "\(components.blue)",
                          "green" : "\(components.green)",
                          "red" : "\(components.red)"
                        }
                      },
                      "idiom" : "universal"
                    }
                  ],
                  "info" : {
                    "author" : "xcode",
                    "version" : 1
                  }
                }
                """
                
                try colorContents.write(to: colorSetDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
            }
        }
        
        func generateColorSwiftFile(at url: URL, colors: [(hex: String, name: String)]) throws {
            try generateColorSwiftFile(at: url, moduleName: name, colors: colors)
        }
        
        func generateColorSwiftFile(at url: URL, moduleName: String, colors: [(hex: String, name: String)]) throws {
            let sourceDir = url.appendingPathComponent("Sources/\(moduleName)")
            let colorFile = sourceDir.appendingPathComponent("Colors.swift")

            // Start with UIKit and SwiftUI imports
            var colorContent = """
            import UIKit
            import SwiftUI

            // Generated with Swift Sketch
            
            public extension UIColor {
                // Access colors from XCAssets
                static var \(moduleName.lowercased())Colors: \(moduleName)Colors.Type {
                    return \(moduleName)Colors.self
                }
            }

            // UIKit color extensions
            public enum \(moduleName)Colors {
            
            """
            
            // Add each color with direct asset access
            for color in colors {
                let properName = color.name.prefix(1).lowercased() + color.name.dropFirst()
                colorContent += """
                    public static var \(properName): UIColor {
                        return UIColor(named: "\(color.name)", in: .module, compatibleWith: nil)!
                    }
                
                """
            }
            
            // Add SwiftUI Color extensions
            colorContent += """
            }
            
            // SwiftUI Color extensions
            public extension Color {
                // Access colors from XCAssets
                static var \(moduleName.lowercased())Colors: \(moduleName)SwiftUIColors.Type {
                    return \(moduleName)SwiftUIColors.self
                }
            }
            
            public enum \(moduleName)SwiftUIColors {
            
            """
            
            for color in colors {
                let properName = color.name.prefix(1).lowercased() + color.name.dropFirst()
                colorContent += """
                    public static var \(properName): Color {
                        return Color("\(color.name)", bundle: .module)
                    }
                
                """
            }
            
            colorContent += "}"
            
            try colorContent.write(to: colorFile, atomically: true, encoding: .utf8)
        }
        
        func createSwiftPackage(at url: URL, name: String, dependencies: [String]) throws {
            // Normalize iOS version format (strip 'v' prefix if present)
            let normalizedIosVersion = normalizedIosVersion(iosVersion)
            
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            
            // Create Package.swift
            var dependenciesStr = ""
            var targetDependenciesStr = ""
            
            if !dependencies.isEmpty {
                dependenciesStr = dependencies.map { ".package(path: \"../" + $0 + "\")" }.joined(separator: ",\n        ")
                targetDependenciesStr = dependencies.map { ".product(name: \"" + $0 + "\", package: \"" + $0 + "\")" }.joined(separator: ",\n                ")
            }
            
            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

            let package = Package(
                name: "\(name)",
                platforms: [.iOS("\(normalizedIosVersion)")],
                products: [
                    .library(
                        name: "\(name)",
                        targets: ["\(name)"]
                    ),
                ],
                dependencies: [
                    \(dependenciesStr)
                ],
                targets: [
                    .target(
                        name: "\(name)",
                        dependencies: [
                            \(targetDependenciesStr)
                        ],
                        resources: [.process("Resources")]
                    ),
                    .testTarget(
                        name: "\(name)Tests",
                        dependencies: ["\(name)"]
                    ),
                ]
            )
            """
            
            try packageSwift.write(to: url.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
            
            // Create basic directory structure
            let sourcesDir = url.appendingPathComponent("Sources/\(name)")
            try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
            
            let resourcesDir = sourcesDir.appendingPathComponent("Resources")
            try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            
            let testsDir = url.appendingPathComponent("Tests/\(name)Tests")
            try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)
            
            // Create a basic implementation file
            let implementationSwift = """
            import Foundation
            \(dependencies.map { "import " + $0 }.joined(separator: "\n"))

            public struct \(name) {
                public static func hello() -> String {
                    return "Hello from \(name) module!"
                }
                
                public init() {}
            }
            """
            
            try implementationSwift.write(to: sourcesDir.appendingPathComponent("\(name).swift"), atomically: true, encoding: .utf8)
            
            // Create a basic test file
            let testSwift = """
            import XCTest
            @testable import \(name)

            final class \(name)Tests: XCTestCase {
                func testExample() {
                    XCTAssertEqual(\(name).hello(), "Hello from \(name) module!")
                }
            }
            """
            
            try testSwift.write(to: testsDir.appendingPathComponent("\(name)Tests.swift"), atomically: true, encoding: .utf8)
        }
    }
}

extension SwiftSketch {
    // MARK: - Template Subcommand
    struct Template: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "List and apply predefined project templates"
        )
        
        enum TemplateType: String, ExpressibleByArgument {
            case basic = "basic"
            case mvvm = "mvvm"
            case viper = "viper"
            case clean = "clean"
            
            static var allCases: [TemplateType] {
                return [.basic, .mvvm, .viper, .clean]
            }
        }
        
        @Argument(help: "The type of template to create")
        var templateType: TemplateType = .basic
        
        @Argument(help: "Name for the generated package/project")
        var name: String
        
        @Option(name: [.customShort("o"), .customLong("output")], help: "Output directory")
        var output: String = FileManager.default.currentDirectoryPath
        
        @Option(name: .customLong("org"), help: "Organization identifier (e.g., com.company)")
        var organization: String = "com.yourorganization"
        
        func run() throws {
            let packageDir = URL(fileURLWithPath: output).appendingPathComponent(name)
            
            print("⚙️ Generating \(templateType.rawValue) template for '\(name)'...")
            
            // Create directory structure
            try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
            
            switch templateType {
            case .basic:
                let createCommand = Create(
                    name: _name,
                    output: output,
                    organization: organization
                )

                try createCommand.run()
                
            case .mvvm:
                try generateMVVMTemplate(at: packageDir)
                
            case .viper:
                try generateViperTemplate(at: packageDir)
                
            case .clean:
                try generateCleanArchitectureTemplate(at: packageDir)
            }
            
            print("✅ Template '\(templateType.rawValue)' generated successfully at \(packageDir.path)")
        }
        
        func generateMVVMTemplate(at url: URL) throws {
            // Implementation for MVVM template
            // This is where you'd add the MVVM structure
            print("MVVM template structure would be generated here")
        }
        
        func generateViperTemplate(at url: URL) throws {
            // Implementation for VIPER template
            print("VIPER template structure would be generated here")
        }
        
        func generateCleanArchitectureTemplate(at url: URL) throws {
            // Implementation for Clean Architecture template
            print("Clean Architecture template structure would be generated here")
        }
    }
}

// Helper function to get the default Xcode version
func getDefaultXcodeVersion() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    process.arguments = ["-version"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            // Parse version from output like "Xcode 16.2\nBuild version 16B2255"
            let firstLine = output.split(separator: "\n").first ?? ""
            let versionPart = firstLine.split(separator: " ").last ?? "16.0"
            return String(versionPart)
        }
    } catch {
        // Default fallback if xcodebuild fails
    }
    
    return "16.0" // Default fallback
}
