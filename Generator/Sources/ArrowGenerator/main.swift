import ArgumentParser
import ArrowGeneratorCore
import Constants

/// Root command for the Arrow Generator CLI tool.
///
/// This command-line tool generates dependency injection registration code
/// for the Arrow DI framework. It parses Swift files to find dependency modules,
/// validates the dependency graph, and generates registration code in topological order.
///
/// Available subcommands:
/// - `generate`: Generates dependency registration code
struct Arrow: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "arrow",
    abstract: "A Swift command-line tool to resolve, generate and add dependencies to container",
    version: Constants.version,
    subcommands: [DependencyRegistrationGenerator.self]
  )
}

Arrow.main()
