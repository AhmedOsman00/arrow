import PackagePlugin
import Foundation

@main
struct BuildScriptPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        return []
    }
}
