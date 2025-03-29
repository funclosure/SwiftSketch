# Swift Sketch

A modern Swift code and project scaffolding tool that helps you quickly create structured Swift packages and projects with sensible defaults.

## Features

- Generate Swift Packages with standard structure
- Add pre-defined color assets with Swift extensions for both UIKit and SwiftUI
- Generate modular architectures with Core, UI, and Util packages
- Automatic project generation using Tuist or XcodeGen
- Various templates for common architecture patterns

## Installation

### Brew

```bash
brew install swift-sketch
```

### Manual

1. Clone this repository
2. Build using Swift Package Manager
   ```bash
   swift build -c release
   ```
3. Install the binary
   ```bash
   cp .build/release/swift-sketch /usr/local/bin/swift-sketch
   ```

## Quick Start

Create a basic Swift package:

```bash
swift-sketch create MyPackage
```

Create a modular project with Tuist:

```bash
swift-sketch create MyApp --modular --project
```

Add color assets:

```bash
swift-sketch create MyApp --colors "#FF0000=Red,#00FF00=Green,#0000FF=Blue"
```

## Command Reference

### Create Command

```bash
USAGE: swift-sketch create <n> [--colors <colors>] [--output <o>] [--project] [--project-tool <project-tool>] [--modular] [--org <org>] [--xcode-version <xcode-version>] [--verbose]

ARGUMENTS:
  <n>                  The name of the Swift Package to generate

OPTIONS:
  --colors <colors>       Comma-separated list of colors in format #HEX=Name
  -o, --output <o>   Output directory for the package (default: current directory)
  --project               Generate an Xcode project alongside the Swift Package
  --project-tool <project-tool>
                          Project generation tool (tuist, xcodegen, or none) (default: tuist)
  --modular               Generate a modular architecture with App, Core, UI, and Util modules
  --org <org>             Organization identifier (e.g., com.company) (default: com.yourorganization)
  --xcode-version <xcode-version>
                          Xcode version to use (e.g., 16.2)
  -v, --verbose           Show verbose output during generation
  -h, --help              Show help information
```

### Template Command

```bash
USAGE: swift-sketch template [<template-type>] <n> [--output <o>] [--org <org>]

ARGUMENTS:
  <template-type>         The type of template to create (basic, mvvm, viper, clean) (default: basic)
  <n>                  Name for the generated package/project

OPTIONS:
  -o, --output <o>   Output directory (default: current directory)
  --org <org>             Organization identifier (e.g., com.company) (default: com.yourorganization)
  -h, --help              Show help information
```

## Templates

Swift Sketch comes with several pre-defined templates:

- `basic`: Standard Swift Package with unit tests
- `mvvm`: Model-View-ViewModel architecture
- `viper`: View-Interactor-Presenter-Entity-Router architecture
- `clean`: Clean Architecture with Use Cases, Repositories, and Entities

## Examples

### Creating a Modular App

```bash
swift-sketch create MyAwesomeApp --modular --project --colors "#FF5733=Primary,#33FF57=Secondary,#5733FF=Accent"
```

This creates:
- A main application target
- Core, UI, and Util Swift Package modules
- Color assets in the UI module
- Tuist configuration for project generation

### Creating an MVVM Template

```bash
swift-sketch template mvvm MyMVVMApp --org com.mycompany
```

## License

MIT License
