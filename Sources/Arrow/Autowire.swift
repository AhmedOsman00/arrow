@propertyWrapper
public struct Autowire<T> {
    var name: String?
    // save the value

    public var wrappedValue: T? {
        Container.shared.resolve(T.self, name: name)
    }

    public init(name: String? = nil) {
        self.name = name
    }
}

public typealias Presenter = Autowire
public typealias ViewModel = Autowire
