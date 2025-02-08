import Foundation

public final class Container: Registerable {
    public static let shared: Registerable = Container()
    private var dependencies = [String: Any]()
    private let lock = NSLock()

    private init() {}

    public func register<Dependency>(
        _ type: Dependency.Type,
        name: String?,
        objectScope: DependencyScope,
        factory: @escaping (Registerable) -> Dependency
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

    public func resolve<Dependency>(_ type: Dependency.Type, name: String? = nil) -> Dependency {
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
}

public enum DependencyScope {
    case singleton
    case transient
}

public protocol Registerable {
    func resolve<Dependency>(_ type: Dependency.Type, name: String?) -> Dependency
    func register<Dependency>(_ type: Dependency.Type,
                              name: String?,
                              objectScope: DependencyScope,
                              factory: @escaping (Container) -> Dependency)
    func register()
}

extension Registerable {
    public func resolve<Dependency>(_ type: Dependency.Type, name: String? = nil) -> Dependency {
        resolve(type, name: name)
    }
    
    public func register<Dependency>(
        _ type: Dependency.Type,
        name: String? = nil,
        objectScope: DependencyScope = .transient,
        factory: @escaping (Container) -> Dependency
    ) {
        register(type, name: name, objectScope: objectScope, factory: factory)
    }
    
    public func register() {}
}
