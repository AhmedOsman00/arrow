import Foundation

final class Container {
    static let shared = Container()
    private var dependencies = [String: Any]()
    private let lock = NSLock()

    private init() {}

    func register<Dependency>(
        _ type: Dependency.Type,
        _ name: String? = nil,
        _ objectScope: DependencyScope = .transient,
        _ factory: @escaping (Container) -> Dependency
    ) {
        let name = name ?? "\(type)"
        lock.lock()
        defer { lock.unlock() }

        guard dependencies[name] == nil else {
            fatalError("Dependency \(name) is already registered.")
        }

        switch objectScope {
        case .singleton:
            dependencies[name] = factory(Self.shared)
        case .transient:
            dependencies[name] = {
                factory(Self.shared)
            }
        }
    }

    func resolve<Dependency>(_ type: Dependency.Type, _ name: String? = nil) -> Dependency {
        let name = name ?? "\(type)"

        if let dependency = dependencies[name] as? Dependency {
            return dependency
        }

        if let dependency = dependencies[name] as? () -> Dependency {
            return dependency()
        }

        fatalError("Dependency not found for type \(type)")
    }

    func resolved<Dependency>() -> Dependency {
        return resolve(Dependency.self)
    }

    enum DependencyScope {
        case singleton
        case transient
    }
}
