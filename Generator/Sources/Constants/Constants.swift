// ⚠️ SYNC: Keep in sync with:
// - arrow-generator-plugin/ArrowPlugin.swift
public enum Constants {
    public static let verbose: Character = "v"
    public static let executableName = "arrow"
    public static let isPackageFlag = "is-package"
    public static let packageSourcesPathArgument = "package-path"
    public static let targetNameArgument = "target-name"
    public static let extensionPathArgument = "ext-path"
    public static let projRootArgument = "proj-root"
    public static let generateCommand = "generate"
    public static let generatedFileName = "dependencies.generated.swift"
    /// ⚠️ SYNC: Keep in sync with Arrow package [Arrow/Sources/Arrow/Named]
    public static let namedProperty = "Named"
    /// ⚠️ SYNC: Keep in sync with Arrow package [Arrow/Sources/ArrowMacros/Name]
    public static let nameMacro = "Name"
}
