extension String {
  func capitalizeFirstLetter() -> String {
    guard let first = first else { return self }
    return first.uppercased() + dropFirst()
  }
}
