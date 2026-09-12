// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

nonisolated public protocol SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == GitLabAPI.SchemaMetadata {}

nonisolated public protocol InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == GitLabAPI.SchemaMetadata {}

nonisolated public protocol MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == GitLabAPI.SchemaMetadata {}

nonisolated public protocol MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == GitLabAPI.SchemaMetadata {}

nonisolated public enum SchemaMetadata: ApolloAPI.SchemaMetadata {
  public static let configuration: any ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

  private static let objectTypeMap: [String: ApolloAPI.Object] = [
    "AddOnUser": GitLabAPI.Objects.AddOnUser,
    "AlertManagementAlert": GitLabAPI.Objects.AlertManagementAlert,
    "AutocompletedUser": GitLabAPI.Objects.AutocompletedUser,
    "BoardEpic": GitLabAPI.Objects.BoardEpic,
    "Commit": GitLabAPI.Objects.Commit,
    "CountableVulnerability": GitLabAPI.Objects.CountableVulnerability,
    "CurrentUser": GitLabAPI.Objects.CurrentUser,
    "Design": GitLabAPI.Objects.Design,
    "DesignAtVersion": GitLabAPI.Objects.DesignAtVersion,
    "Epic": GitLabAPI.Objects.Epic,
    "EpicIssue": GitLabAPI.Objects.EpicIssue,
    "Group": GitLabAPI.Objects.Group,
    "GroupMinimalAccess": GitLabAPI.Objects.GroupMinimalAccess,
    "Issue": GitLabAPI.Objects.Issue,
    "Key": GitLabAPI.Objects.Key,
    "MergeRequest": GitLabAPI.Objects.MergeRequest,
    "MergeRequestAssignee": GitLabAPI.Objects.MergeRequestAssignee,
    "MergeRequestAuthor": GitLabAPI.Objects.MergeRequestAuthor,
    "MergeRequestParticipant": GitLabAPI.Objects.MergeRequestParticipant,
    "MergeRequestReviewer": GitLabAPI.Objects.MergeRequestReviewer,
    "Namespace": GitLabAPI.Objects.Namespace,
    "Project": GitLabAPI.Objects.Project,
    "ProjectComplianceViolation": GitLabAPI.Objects.ProjectComplianceViolation,
    "ProjectMinimalAccess": GitLabAPI.Objects.ProjectMinimalAccess,
    "Query": GitLabAPI.Objects.Query,
    "Snippet": GitLabAPI.Objects.Snippet,
    "UserCore": GitLabAPI.Objects.UserCore,
    "Vulnerability": GitLabAPI.Objects.Vulnerability,
    "WikiPage": GitLabAPI.Objects.WikiPage,
    "WorkItem": GitLabAPI.Objects.WorkItem,
    "WorkItemWidgetAssignees": GitLabAPI.Objects.WorkItemWidgetAssignees,
    "WorkItemWidgetAwardEmoji": GitLabAPI.Objects.WorkItemWidgetAwardEmoji,
    "WorkItemWidgetColor": GitLabAPI.Objects.WorkItemWidgetColor,
    "WorkItemWidgetCrmContacts": GitLabAPI.Objects.WorkItemWidgetCrmContacts,
    "WorkItemWidgetCurrentUserTodos": GitLabAPI.Objects.WorkItemWidgetCurrentUserTodos,
    "WorkItemWidgetCustomFields": GitLabAPI.Objects.WorkItemWidgetCustomFields,
    "WorkItemWidgetDescription": GitLabAPI.Objects.WorkItemWidgetDescription,
    "WorkItemWidgetDesigns": GitLabAPI.Objects.WorkItemWidgetDesigns,
    "WorkItemWidgetDevelopment": GitLabAPI.Objects.WorkItemWidgetDevelopment,
    "WorkItemWidgetEmailParticipants": GitLabAPI.Objects.WorkItemWidgetEmailParticipants,
    "WorkItemWidgetErrorTracking": GitLabAPI.Objects.WorkItemWidgetErrorTracking,
    "WorkItemWidgetHealthStatus": GitLabAPI.Objects.WorkItemWidgetHealthStatus,
    "WorkItemWidgetHierarchy": GitLabAPI.Objects.WorkItemWidgetHierarchy,
    "WorkItemWidgetIteration": GitLabAPI.Objects.WorkItemWidgetIteration,
    "WorkItemWidgetLabels": GitLabAPI.Objects.WorkItemWidgetLabels,
    "WorkItemWidgetLinkedItems": GitLabAPI.Objects.WorkItemWidgetLinkedItems,
    "WorkItemWidgetLinkedResources": GitLabAPI.Objects.WorkItemWidgetLinkedResources,
    "WorkItemWidgetMilestone": GitLabAPI.Objects.WorkItemWidgetMilestone,
    "WorkItemWidgetNotes": GitLabAPI.Objects.WorkItemWidgetNotes,
    "WorkItemWidgetNotifications": GitLabAPI.Objects.WorkItemWidgetNotifications,
    "WorkItemWidgetParticipants": GitLabAPI.Objects.WorkItemWidgetParticipants,
    "WorkItemWidgetProgress": GitLabAPI.Objects.WorkItemWidgetProgress,
    "WorkItemWidgetRequirementLegacy": GitLabAPI.Objects.WorkItemWidgetRequirementLegacy,
    "WorkItemWidgetStartAndDueDate": GitLabAPI.Objects.WorkItemWidgetStartAndDueDate,
    "WorkItemWidgetStatus": GitLabAPI.Objects.WorkItemWidgetStatus,
    "WorkItemWidgetTestReports": GitLabAPI.Objects.WorkItemWidgetTestReports,
    "WorkItemWidgetTimeTracking": GitLabAPI.Objects.WorkItemWidgetTimeTracking,
    "WorkItemWidgetVerificationStatus": GitLabAPI.Objects.WorkItemWidgetVerificationStatus,
    "WorkItemWidgetVulnerabilities": GitLabAPI.Objects.WorkItemWidgetVulnerabilities,
    "WorkItemWidgetWeight": GitLabAPI.Objects.WorkItemWidgetWeight
  ]

  @_spi(Execution) public static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
    objectTypeMap[typename]
  }
}

nonisolated public enum Objects {}
nonisolated public enum Interfaces {}
nonisolated public enum Unions {}
