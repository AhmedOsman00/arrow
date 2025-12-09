import ArrowGeneratorCore
import ArgumentParser

struct Arrow: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "arrow",
        abstract: "A Swift command-line tool to resolve, generate and add dependencies to container",
        subcommands: [DependencyRegistrationGenerator.self]
    )
}

Arrow.main()
