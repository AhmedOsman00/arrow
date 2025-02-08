public protocol Default {
    init()
}

public protocol TransientScope: Default {}
public protocol SingletonScope: Default {}
