import Apollo
import GitLabAPI
import SwiftUI

struct ContentView: View {
    @AppStorage("token") var token = ""
    @State var user: Result<CurrentUserQuery.Data.CurrentUser?, any Error>? = nil
    @State var loadTask: Task<Void, Never>? = nil
    @State var isLoading = false

    var isTokenEmpty: Bool {
        token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadUser() async -> Void {
        do {
            let res = try await Network.shared.apollo.fetch(
                query: CurrentUserQuery(),
                cachePolicy: .networkOnly
            )
            // The request may have been cancelled while awaiting the network.
            // Don't publish a stale result in that case.
            try Task.checkCancellation()
            self.user = .success(res.data?.currentUser)
        } catch is CancellationError {
            // Superseded by a newer refresh or view dismissal: leave state alone.
        } catch {
            if Task.isCancelled { return }
            self.user = .failure(error)
        }
    }

    /// Cancels any in-flight request and starts a new one.
    func refresh() {
        guard !isTokenEmpty else { return }
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            await loadUser()
            // A cancelled (superseded) task must not clear the spinner
            // belonging to the newer task.
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    var body: some View {
        Form {
            TextField("PAT", text: $token)
                .autocorrectionDisabled()
                .disableAutoCapitalization()
                .onSubmit { refresh() }
            Button("Refresh", systemImage: "checkmark") {
                refresh()
            }
            .disabled(isTokenEmpty || isLoading)

            if isLoading {
                ProgressView()
            } else if let user {
                switch user {
                case .success(let u):
                    if let u {
                        Text(u.username)
                    } else {
                        Text("No user")
                    }
                case .failure(let failure):
                    Text(failure.localizedDescription)
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // Reload a persisted token once; manual refreshes after that.
            if user == nil && !isTokenEmpty {
                refresh()
            }
        }
        .onDisappear(perform: cancel)
        .onChange(of: token) { _, newValue in
            // A cleared token invalidates any previous result.
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cancel()
                user = nil
            }
        }
    }
}

/// `textInputAutocapitalization` only exists on iOS, so `swift build` on macOS
/// fails when it is used directly. This keeps it on iOS and is a no-op elsewhere.
extension View {
    @ViewBuilder
    func disableAutoCapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
