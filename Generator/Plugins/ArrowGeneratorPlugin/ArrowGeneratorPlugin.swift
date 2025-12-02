import PackagePlugin
import Foundation

// ⚠️ SYNC: Keep in sync with:
// - Sources/Constants/Constants.swift
// - Package.swift
private enum PluginConstants {
    static let executableTargetName = "ArrowGenerator"
    static let isPackageFlag = "is-package"
    static let packageNameArgument = "package-name"
    static let packageSourcesPathArgument = "package-sources-path"
    static let generateCommand = "generate"
    static let generatedFileName = "dependencies.generated.swift"
}

@main
struct ArrowGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Only run for source module targets
        guard let target = target as? SourceModuleTarget else {
            return []
        }

        let arrowTool = try context.tool(named: PluginConstants.executableTargetName)
        let packageName = context.package.displayName
        let outputPath = target.directoryURL.appending(path: PluginConstants.generatedFileName)
        let inputFiles = target.sourceFiles(withSuffix: ".swift").map { $0.url }

        let arguments = [
            PluginConstants.generateCommand,
            "--\(PluginConstants.isPackageFlag)",
            "--\(PluginConstants.packageNameArgument)", packageName,
            "--\(PluginConstants.packageSourcesPathArgument)", target.directoryURL.path(),
        ]

        let command = Command.buildCommand(
            displayName: "Generating dependency container for \(packageName)",
            executable: arrowTool.url,
            arguments: arguments,
            environment: [:],
            inputFiles: inputFiles,
            outputFiles: [outputPath]
        )

        return [command]
    }
}
