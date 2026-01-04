import Foundation

// MARK: - Phantom Type Infrastructure

/// A type-safe identifier using phantom types
struct Identifier<Tag>: Hashable, Equatable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String {
        rawValue
    }
}

// MARK: - Phantom Type Tags

enum DependencyTag {}
enum ParameterTag {}

// MARK: - Type Aliases

typealias DependencyID = Identifier<DependencyTag>
typealias ParameterID = Identifier<ParameterTag>
