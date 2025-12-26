import SwiftUI
import Arrow

struct HomeView: View {
  @State private var viewModel: HomeViewModel

  init(viewModel: HomeViewModel) {
    self.viewModel = viewModel
  }

  var body: some View {
    VStack(spacing: 20) {
      Text(viewModel.greeting)
        .font(.title)
        .padding()

      Text("Counter: \(viewModel.counter)")
        .font(.headline)

      HStack(spacing: 16) {
        Button("Increment") {
          viewModel.incrementCounter()
        }
        .buttonStyle(.borderedProminent)

        Button("Reset") {
          viewModel.resetCounter()
        }
        .buttonStyle(.bordered)
      }

      TextField("Update greeting", text: $viewModel.greeting)
        .textFieldStyle(.roundedBorder)
        .padding(.horizontal)
        .onChange(of: viewModel.greeting) { oldValue, newValue in
          viewModel.updateGreeting(newValue)
        }
    }
    .padding()
  }
}
