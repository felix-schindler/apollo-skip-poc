import Apollo
import ApolloAPI
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Reads the GitLab personal access token from the same `UserDefaults` key
/// that `ContentView`'s `@AppStorage("token")` writes to, so the interceptor
/// always uses the current token without needing an `ObservableObject`.
enum TokenStore {
    static let key = "token"

    static var token: String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }
}

final class Network: Sendable {
    static let shared = Network()

    let apollo: ApolloClient

    private init() {
        // In-memory cache: no file-system paths, works on iOS and Android.
        let store = ApolloStore(cache: InMemoryNormalizedCache())
        let transport = RequestChainNetworkTransport(
            urlSession: URLSession.shared,
            interceptorProvider: NetworkInterceptorProvider(),
            store: store,
            endpointURL: URL(string: "https://gitlab.com/api/graphql")!
        )
        self.apollo = ApolloClient(networkTransport: transport, store: store)
    }
}

struct AuthorizationInterceptor: GraphQLInterceptor {
    func intercept<Request: GraphQLRequest>(
        request: Request,
        next: NextInterceptorFunction<Request>
    ) async throws -> InterceptorResultStream<Request> {
        var req = request
        let token = TokenStore.token
        if !token.isEmpty {
            req.addHeader(name: "Authorization", value: "Bearer \(token)")
        }
        return await next(req)
    }
}

struct NetworkInterceptorProvider: InterceptorProvider {
    func graphQLInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any GraphQLInterceptor] {
        // Auth first, then the defaults (retry + persisted queries).
        // Cache, HTTP and parsing interceptors fall through to the
        // `InterceptorProvider` default implementations.
        [
            AuthorizationInterceptor(),
            MaxRetryInterceptor(),
            AutomaticPersistedQueryInterceptor(),
        ]
    }
}
