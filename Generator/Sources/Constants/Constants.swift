public enum Constants {
  public static let verbose: Character = "v"
  public static let executableName = "arrow"
  public static let isPackageFlag = "is-package"
  public static let packageSourcesPathArgument = "package-path"
  public static let targetNameArgument = "target-name"
  public static let extensionPathArgument = "ext-path"
  public static let projRootArgument = "proj-root"
  public static let registryNameArgument = "registry-name"
  public static let externalPathArgument = "external-path"
  public static let generateCommand = "generate"
  public static let generatedFileName = "dependencies.generated.swift"
  /// Build settings read as fallbacks for the options above.
  public static let registryNameSetting = "ARROW_REGISTRY_NAME"
  public static let extPathSetting = "ARROW_EXT_PATH"
  public static let packagePathsSetting = "ARROW_PACKAGE_PATHS"
  public static let externalPathsSetting = "ARROW_EXTERNAL_PATHS"
  /// ⚠️ SYNC: Keep in sync with Arrow package [Arrow/Sources/Arrow/Named]
  public static let namedProperty = "Named"
  /// ⚠️ SYNC: Keep in sync with Arrow package [Arrow/Sources/ArrowMacros/NameMacro]
  public static let nameMacro = "Name"
  /// ⚠️ SYNC: Keep in sync with Arrow package [ArrowMacros product]
  public static let macrosModule = "ArrowMacros"
}
