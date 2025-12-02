import ArrowGeneratorCore
import Foundation
import ConsoleKit

let console: Console = Terminal()
var input = CommandInput(arguments: CommandLine.arguments)
var context = CommandContext(console: console, input: input)
var commands = Commands(enableAutocomplete: true)
commands.use(DependencyRegistrationGenerator(), as: DependencyRegistrationGenerator.name, isDefault: false)

do {
    let group = commands.group(help: "A Swift command-line tool to resolve, generate and add dependencies to container")
    try console.run(group, input: input)
} catch {
    console.error("\(error)")
    exit(1)
}
