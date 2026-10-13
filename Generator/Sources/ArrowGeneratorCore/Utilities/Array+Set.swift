extension Array where Element: Hashable {
  func asSet() -> Set<Element> {
    Set(self)
  }
}
