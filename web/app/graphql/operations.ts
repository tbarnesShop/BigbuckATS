/**
 * Every GraphQL document the web app runs. Each is registered with Rails as a
 * persisted query (pnpm run persist-queries), because browser sessions may only
 * run registered documents. Types come from schema.graphql (pnpm run codegen).
 */

export const ViewerQuery = /* GraphQL */ `
  query Viewer {
    viewer {
      organizationId
      actorType
      roleKey
      permissions
      user {
        id
        name
        email
      }
      agent {
        id
        name
      }
    }
  }
`

export const TodayQuery = /* GraphQL */ `
  query Today {
    viewer {
      user {
        id
        name
      }
    }
    today {
      feedback {
        id
        interviewKey
        startsAt
        interviewerUserIds
        application {
          id
          person {
            displayName
          }
          job {
            title
          }
        }
      }
      reviews {
        id
        person {
          displayName
        }
        job {
          id
          title
        }
      }
      upcoming {
        id
        interviewKey
        startsAt
        interviewerUserIds
        application {
          id
          person {
            displayName
          }
          job {
            title
          }
        }
      }
    }
  }
`

/** Offer rows for Today. Separate from Today so a caller without offer.read still gets the queue. */
export const TodayOffersQuery = /* GraphQL */ `
  query TodayOffers {
    today {
      offersPending {
        id
        application {
          id
          person {
            displayName
          }
          job {
            title
          }
        }
      }
    }
  }
`

/** Active jobs for the pipeline-health card. Separate so a caller without job.read still gets Today. */
export const TodayJobsQuery = /* GraphQL */ `
  query TodayJobs {
    today {
      jobs {
        id
        title
        openings
        activeCount
      }
    }
  }
`

export const InterviewsHubQuery = /* GraphQL */ `
  query InterviewsHub($scope: String) {
    viewer {
      user {
        id
      }
    }
    upcoming: interviews(tab: "upcoming", scope: $scope) {
      ...HubInterview
    }
    schedule: interviews(tab: "schedule", scope: $scope) {
      ...HubInterview
    }
    feedback: interviews(tab: "feedback") {
      ...HubInterview
    }
    mine: interviews(tab: "mine") {
      ...HubInterview
    }
  }
  fragment HubInterview on Interview {
    id
    applicationId
    interviewKey
    status
    startsAt
    interviewerUserIds
    application {
      id
      person {
        displayName
      }
      job {
        title
      }
    }
  }
`

export const OffersHubQuery = /* GraphQL */ `
  query OffersHub($status: String) {
    offers(status: $status) {
      counts {
        status
        count
      }
      nodes {
        id
        status
        updatedAt
        application {
          id
          person {
            displayName
          }
          job {
            title
          }
        }
      }
    }
  }
`

export const JobWorkspaceQuery = /* GraphQL */ `
  query JobWorkspace($id: ID!, $after: String) {
    job(id: $id) {
      id
      title
      status
      openings
      confidential
      codeName
      version
      stages {
        key
        name
        type
      }
      applications(first: 20, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          status
          currentStageKey
          version
          updatedAt
          createdAt
          person {
            id
            displayName
            primaryEmail
          }
          transitions {
            toStageKey
            createdAt
          }
          upcomingInterview {
            interviewKey
            stageKey
            startsAt
          }
        }
      }
    }
  }
`

export const PersonCustomFieldsQuery = /* GraphQL */ `
  query PersonCustomFields($id: ID!) {
    person(id: $id) {
      id
      customFields {
        key
        fieldType
        fieldVersion
        definition {
          label
        }
        ... on CustomFieldTextValue {
          text
        }
        ... on CustomFieldNumberValue {
          number
        }
        ... on CustomFieldDateValue {
          date
        }
        ... on CustomFieldBooleanValue {
          boolean
        }
        ... on CustomFieldOptionValue {
          option
        }
        ... on CustomFieldOptionsValue {
          options
        }
        ... on CustomFieldReferenceValue {
          referenceId
        }
      }
    }
  }
`

export const AgentsQuery = /* GraphQL */ `
  query Agents {
    viewer {
      permissions
      agent {
        id
      }
    }
    agents {
      id
      name
      description
      status
      scopes
      version
      createdAt
    }
  }
`

export const CustomFieldDefinitionsQuery = /* GraphQL */ `
  query CustomFieldDefinitions($entity: String!) {
    customFieldDefinitions(entity: $entity, includeArchived: true) {
      id
      key
      label
      fieldType
      dataClass
      status
      version
      required
      options {
        key
        label
      }
    }
  }
`

export const CreateCustomFieldMutation = /* GraphQL */ `
  mutation CreateCustomField(
    $entity: String!
    $key: String!
    $label: String!
    $fieldType: String!
    $dataClass: String
    $options: [CustomFieldOptionInput!]
  ) {
    createCustomField(
      input: {
        entity: $entity
        key: $key
        label: $label
        fieldType: $fieldType
        dataClass: $dataClass
        options: $options
      }
    ) {
      field {
        id
        key
        version
      }
      userErrors {
        code
        message
      }
    }
  }
`

export const ArchiveCustomFieldMutation = /* GraphQL */ `
  mutation ArchiveCustomField($id: ID!, $restore: Boolean, $expectedVersion: Int) {
    archiveCustomField(input: { id: $id, restore: $restore, expectedVersion: $expectedVersion }) {
      field {
        id
        status
        version
      }
      userErrors {
        code
        message
      }
    }
  }
`

export const SetCustomFieldValueMutation = /* GraphQL */ `
  mutation SetCustomFieldValue(
    $entityType: String!
    $entityId: ID!
    $key: String!
    $value: CustomFieldValueInput!
  ) {
    setCustomFieldValue(input: { entityType: $entityType, entityId: $entityId, key: $key, value: $value }) {
      value {
        key
        fieldVersion
      }
      userErrors {
        code
        message
      }
    }
  }
`

export const MoveApplicationStageMutation = /* GraphQL */ `
  mutation MoveApplicationStage($id: ID!, $to: String!, $expectedVersion: Int) {
    moveApplicationStage(input: { applicationId: $id, toStageKey: $to, expectedVersion: $expectedVersion }) {
      application {
        id
        currentStageKey
        version
      }
      userErrors {
        code
        message
      }
    }
  }
`

/** Every operation, by operation name. */
export const operations = {
  Viewer: ViewerQuery,
  Today: TodayQuery,
  TodayOffers: TodayOffersQuery,
  TodayJobs: TodayJobsQuery,
  InterviewsHub: InterviewsHubQuery,
  OffersHub: OffersHubQuery,
  JobWorkspace: JobWorkspaceQuery,
  PersonCustomFields: PersonCustomFieldsQuery,
  Agents: AgentsQuery,
  CustomFieldDefinitions: CustomFieldDefinitionsQuery,
  CreateCustomField: CreateCustomFieldMutation,
  ArchiveCustomField: ArchiveCustomFieldMutation,
  SetCustomFieldValue: SetCustomFieldValueMutation,
  MoveApplicationStage: MoveApplicationStageMutation,
} as const

export type OperationName = keyof typeof operations
