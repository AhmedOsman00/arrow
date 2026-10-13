import SwiftUI

struct CounterDetailView: View {
  var viewModel: HomeViewModel

  var body: some View {
    VStack(spacing: 12) {
      Text("Counter Details")
        .font(.headline)

      Text("Current value: \(viewModel.counter)")
        .font(.body)

      if viewModel.counter > 0 {
        Text("Status: Positive")
          .foregroundStyle(.green)
      } else {
        Text("Status: Zero")
          .foregroundStyle(.gray)
      }

      Button("Double Counter") {
        viewModel.incrementCounter()
        viewModel.incrementCounter()
      }
      .buttonStyle(.borderedProminent)
      .tint(.orange)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
}
