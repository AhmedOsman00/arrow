@propertyWrapper
struct Autowire<T> {
    var name: String?
    // save the value

    var wrappedValue: T? {
        Container.shared.resolve(T.self, name: name)
    }

    init(name: String? = nil) {
        self.name = name
    }
}

typealias Presenter = Autowire
typealias ViewModel = Autowire
