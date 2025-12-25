import UIKit

final class MoreViewController: UIViewController {
    let viewModel: MoreViewModel
    let coordinator: MoreCoordinatorProtocol

    // MARK: - UI Elements

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "More Feature - DI Demo"
        label.font = .boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let resultTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = false
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private lazy var factoryInfoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Show Factory Info", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(factoryInfoTapped), for: .touchUpInside)
        return button
    }()

    private lazy var fetchLocalButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Fetch Local Data", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(fetchLocalTapped), for: .touchUpInside)
        return button
    }()

    private lazy var fetchRemoteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Fetch Remote Data", for: .normal)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(fetchRemoteTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Initialization

    init(viewModel: MoreViewModel, coordinator: MoreCoordinatorProtocol) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(titleLabel)
        view.addSubview(resultTextView)
        view.addSubview(factoryInfoButton)
        view.addSubview(fetchLocalButton)
        view.addSubview(fetchRemoteButton)

        NSLayoutConstraint.activate([
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Result TextView
            resultTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            resultTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultTextView.heightAnchor.constraint(equalToConstant: 200),

            // Factory Info Button
            factoryInfoButton.topAnchor.constraint(equalTo: resultTextView.bottomAnchor, constant: 20),
            factoryInfoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            factoryInfoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            factoryInfoButton.heightAnchor.constraint(equalToConstant: 50),

            // Fetch Local Button
            fetchLocalButton.topAnchor.constraint(equalTo: factoryInfoButton.bottomAnchor, constant: 16),
            fetchLocalButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fetchLocalButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            fetchLocalButton.heightAnchor.constraint(equalToConstant: 50),

            // Fetch Remote Button
            fetchRemoteButton.topAnchor.constraint(equalTo: fetchLocalButton.bottomAnchor, constant: 16),
            fetchRemoteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fetchRemoteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            fetchRemoteButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Actions (calling ViewModel methods)

    @objc private func factoryInfoTapped() {
        let info = viewModel.getFactoryInfo()
        resultTextView.text = info
        coordinator.navigate(to: "FactoryInfo")
    }

    @objc private func fetchLocalTapped() {
        Task {
            do {
                let data = try await viewModel.fetchLocalData()
                await MainActor.run {
                    resultTextView.text = data
                }
                coordinator.navigate(to: "LocalData")
            } catch {
                await MainActor.run {
                    resultTextView.text = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func fetchRemoteTapped() {
        Task {
            do {
                let data = try await viewModel.fetchRemoteData()
                await MainActor.run {
                    resultTextView.text = data
                }
                coordinator.navigate(to: "RemoteData")
            } catch {
                await MainActor.run {
                    resultTextView.text = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
