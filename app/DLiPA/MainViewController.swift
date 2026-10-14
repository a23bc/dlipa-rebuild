import UIKit

/// Minimal shell implementing the original DLiPA workflow: sign in, search,
/// download. Built programmatically so there is no storyboard to keep in sync.
final class MainViewController: UIViewController {

    private let client = AppStoreClient()
    private var signer: SAPSigner?
    private var bag: StoreBag?
    private var account: AppStoreClient.Account?

    private let statusLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let codeField = UITextField()
    private let searchField = UITextField()
    private let signInButton = UIButton(type: .system)
    private let searchButton = UIButton(type: .system)
    private let logView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DLiPA"
        view.backgroundColor = .systemBackground
        buildLayout()
        log("Ready. Apple SAP assets staged to \(AssetStaging.stagedDirectory.path)")
    }

    // MARK: Layout

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "Not signed in"
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center

        emailField.placeholder = "Apple ID email"
        emailField.borderStyle = .roundedRect
        emailField.autocapitalizationType = .none
        emailField.keyboardType = .emailAddress

        passwordField.placeholder = "Password (append 2FA code)"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true

        codeField.placeholder = "2FA code (optional)"
        codeField.borderStyle = .roundedRect
        codeField.keyboardType = .numberPad

        signInButton.setTitle("Sign in", for: .normal)
        signInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)

        searchField.placeholder = "App name, bundle id, or App Store link"
        searchField.borderStyle = .roundedRect
        searchField.autocapitalizationType = .none

        searchButton.setTitle("Search", for: .normal)
        searchButton.addTarget(self, action: #selector(search), for: .touchUpInside)
        searchButton.isEnabled = false

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.layer.borderWidth = 1
        logView.layer.borderColor = UIColor.separator.cgColor

        for view in [statusLabel, emailField, passwordField, codeField,
                     signInButton, searchField, searchButton, logView] {
            stack.addArrangedSubview(view)
        }

        self.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            logView.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    // MARK: Actions

    @objc private func signIn() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            log("Email and password are required.")
            return
        }

        Task { await doSignIn(email: email, password: password,
                             authCode: codeField.text ?? "") }
    }

    @objc private func search() {
        guard let term = searchField.text, !term.isEmpty else { return }
        Task { await doSearch(term: term) }
    }

    // MARK: Work

    private func doSignIn(email: String, password: String, authCode: String) async {
        let hardware = HardwareIdentity.stable()
        log("Device GUID: \(hardware.guid)")

        do {
            let fetched = try await client.fetchBag(guid: hardware.guid)
            bag = fetched
            log("Bag: sign-sap-setup=\(fetched.signSapSetup ?? "none")")

            guard fetched.hasSAPConfiguration,
                  let setup = fetched.signSapSetup,
                  let cert = fetched.signSapSetupCert,
                  let authenticate = fetched.authenticateAccount else {
                log("Bag did not advertise the SAP endpoints; cannot sign in.")
                return
            }

            let newSigner = try SAPSigner(setupURL: setup,
                                         certURL: cert,
                                         version: fetched.signSapVersion,
                                         hardware: hardware)
            self.signer = newSigner
            log("SAP handshake complete; requests will be signed.")

            let newAccount = try await client.authenticate(
                email: email, password: password, authCode: authCode,
                guid: hardware.guid, endpoint: authenticate, signer: newSigner)
            account = newAccount

            statusLabel.text = "Signed in as \(newAccount.email)"
            searchButton.isEnabled = true
            log("Authenticated. DSID \(newAccount.dsid), storefront \(newAccount.storefront)")
        } catch let error as StoreError {
            log("Sign-in failed: \(error.localizedDescription)")
        } catch {
            log("Sign-in failed: \(error.localizedDescription)")
        }
    }

    private func doSearch(term: String) async {
        log("Searching for \(term)...")
        // iTunes search needs no signature; it is the public catalog API.
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string:
                "https://itunes.apple.com/search?entity=software,iPadSoftware&media=software&limit=25&term=\(encoded)")
        else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []
            log("Found \(results.count) result(s).")

            for item in results.prefix(10) {
                let name = item["trackName"] as? String ?? "?"
                let id = item["trackId"] as? Int ?? 0
                log("  \(name)  id=\(id)")
            }
        } catch {
            log("Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: Logging

    private func log(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(),
                                                 dateStyle: .none,
                                                 timeStyle: .medium)
        DispatchQueue.main.async {
            self.logView.text += "[\(stamp)] \(message)\n"
            let bottom = NSMakeRange(self.logView.text.count - 1, 1)
            self.logView.scrollRangeToVisible(bottom)
        }
    }
}
