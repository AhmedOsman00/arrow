import Constants

/// Options read from `ARROW_*` build settings, which Xcode exports to Run Script phases.
///
/// This keeps the script a plain `arrow generate` while each target or configuration
/// sets its own values. Command-line options take precedence over these.
struct BuildSettings: Equatable {
  let registryName: String?
  let extPath: String?
  let packagePaths: [String]
  let externalPaths: [String]

  init(environment: [String: String]) {
    func value(_ key: String) -> String? {
      environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }
    registryName = value(Constants.registryNameSetting)
    extPath = value(Constants.extPathSetting)
    packagePaths = Self.list(value(Constants.packagePathsSetting) ?? "")
    externalPaths = Self.list(value(Constants.externalPathsSetting) ?? "")
  }

  /// Splits a list build setting the way Xcode exports it: space-separated,
  /// with quotes or backslashes around paths that contain spaces.
  static func list(_ value: String) -> [String] {
    var items = [String]()
    var current = ""
    var hasItem = false
    var quote: Character?
    var isEscaped = false

    for character in value {
      if isEscaped {
        current.append(character)
        isEscaped = false
      } else if character == "\\" {
        isEscaped = true
        hasItem = true
      } else if let open = quote {
        if character == open { quote = nil } else { current.append(character) }
      } else if character == "\"" || character == "'" {
        quote = character
        hasItem = true
      } else if character.isWhitespace {
        if hasItem { items.append(current) }
        current = ""
        hasItem = false
      } else {
        current.append(character)
        hasItem = true
      }
    }
    if hasItem { items.append(current) }
    return items
  }
}
