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
        signInButton.isEnabled = false

        // Staging the assets takes a while on a cold start. Report
        // progress and only allow sign-in once the bridge can sign.
        var lastBucket = -1
        AssetStaging.stageIfNeeded(progress: { fraction in
            let percent = Int((fraction * 100).rounded())
            let bucket = percent / 10
            if bucket != lastBucket {
                lastBucket = bucket
                print("[assets] " + String(percent) + "%")
            }
        }) { error in
            if let error {
                self.log("Assets failed to stage: " + error.localizedDescription)
            } else {
                let size = ByteCountFormatter.string(
                    fromByteCount: Int64(AssetStaging.totalBytes), countStyle: .file)
                self.log(NSLocalizedString("assets_ready", comment: "Assets staged")
                         + " (" + size + ")")
            }
            self.signInButton.isEnabled = true
        }
        log("Staging signing assets...")
    }

    // MARK: Layout

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = NSLocalizedString("ap_signin_first", comment: "Status shown before sign-in")
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center

        emailField.placeholder = NSLocalizedString("alert_signin_with_appleid", comment: "Apple ID field")
        emailField.borderStyle = .roundedRect
        emailField.autocapitalizationType = .none
        emailField.keyboardType = .emailAddress

        passwordField.placeholder = NSLocalizedString("alert_password_placeholder", comment: "Password field")
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true

        codeField.placeholder = NSLocalizedString("alert_2f_auth_placeholder", comment: "2FA code field")
        codeField.borderStyle = .roundedRect
        codeField.keyboardType = .numberPad

        signInButton.setTitle(NSLocalizedString("alert_sign_in", comment: "Sign in button"), for: .normal)
        signInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)

        searchField.placeholder = NSLocalizedString("search_placeholder", comment: "Search field")
        searchField.borderStyle = .roundedRect
        searchField.autocapitalizationType = .none

        searchButton.setTitle(NSLocalizedString("search_title", comment: "Search button"), for: .normal)
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
            log(NSLocalizedString("ap_email_password_required", comment: "Validation error"))
            return
        }

        guard AssetStaging.isReady else {
            log("Waiting for the signing assets to finish staging...")
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
            // The alert text is short and localised; the detail goes to the log.
            log("Sign-in failed: \(error.localizedDescription) [\(error.detail)]")
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
