import Foundation
import ArrowCore
import ConsoleKit

let console: Console = Terminal()
var input = CommandInput(arguments: CommandLine.arguments)
var context = CommandContext(console: console, input: input)
var commands = Commands(enableAutocomplete: true)
commands.use(DependancyContanierGenerator(),
             as: DependancyContanierGenerator.name,
             isDefault: false)

do {
    let group = commands.group(help: "A Swift command-line tool resolve, generate and add dependancies to container")
    try console.run(group, input: input)
}
catch {
    console.error("\(error)")
    exit(1)
}
