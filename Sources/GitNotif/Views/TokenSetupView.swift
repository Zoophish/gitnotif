import SwiftUI

struct TokenSetupView: View {
    let store: NotificationStore
    @State private var token = ""
    @State private var ghCLIFailed = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Connect to GitHub")
                    .font(.system(size: 14, weight: .semibold))
                Text("The notifications API needs a classic token or an\nOAuth token — fine-grained tokens aren't supported.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 6) {
                Button {
                    Task {
                        if let cliToken = await GHCLI.token() {
                            store.connect(token: cliToken, save: true)
                        } else {
                            ghCLIFailed = true
                        }
                    }
                } label: {
                    Label("Use GitHub CLI token", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)

                Text(ghCLIFailed
                     ? "Couldn't read a token from `gh` — is it installed and logged in?"
                     : "Reads `gh auth token` — best if your org blocks classic PATs.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(ghCLIFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            }

            HStack {
                VStack { Divider() }
                Text("or").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                VStack { Divider() }
            }
            .frame(width: 260)

            SecureField("Paste a token (ghp_… / gho_…)", text: $token)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onSubmit(connect)

            Button("Connect", action: connect)
                .controlSize(.regular)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)

            Link("Create a classic token (notifications scope) ↗",
                 destination: URL(string: "https://github.com/settings/tokens/new?scopes=notifications&description=GitNotif")!)
                .font(.system(size: 11.5))
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func connect() {
        store.connect(token: token)
    }
}
