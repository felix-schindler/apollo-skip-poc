// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI
@_spi(Execution) @_spi(Unsafe) import ApolloAPI

nonisolated public struct CurrentUserQuery: GraphQLQuery {
  public static let operationName: String = "CurrentUser"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query CurrentUser { currentUser { __typename username } }"#
    ))

  public init() {}

  nonisolated public struct Data: GitLabAPI.SelectionSet {
    @_spi(Unsafe) public let __data: DataDict
    @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

    @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { GitLabAPI.Objects.Query }
    @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
      .field("currentUser", CurrentUser?.self),
    ] }
    @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
      CurrentUserQuery.Data.self
    ] }

    /// Get information about current user.
    public var currentUser: CurrentUser? { __data["currentUser"] }

    /// CurrentUser
    ///
    /// Parent Type: `CurrentUser`
    nonisolated public struct CurrentUser: GitLabAPI.SelectionSet {
      @_spi(Unsafe) public let __data: DataDict
      @_spi(Unsafe) public init(_dataDict: DataDict) { __data = _dataDict }

      @_spi(Execution) public static var __parentType: any ApolloAPI.ParentType { GitLabAPI.Objects.CurrentUser }
      @_spi(Execution) public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("username", String.self),
      ] }
      @_spi(Execution) public static var __fulfilledFragments: [any ApolloAPI.SelectionSet.Type] { [
        CurrentUserQuery.Data.CurrentUser.self
      ] }

      /// Username of the user. Unique within the instance of GitLab.
      public var username: String { __data["username"] }
    }
  }
}
