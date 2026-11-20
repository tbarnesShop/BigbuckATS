/** Internal type. DO NOT USE DIRECTLY. */
type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] }
/** Internal type. DO NOT USE DIRECTLY. */
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never }
export type CustomFieldOptionInput = {
  key: string
  label?: string | null | undefined
}

export type CustomFieldValueInput =
  | {
      boolean: boolean
      clear?: never
      date?: never
      number?: never
      option?: never
      options?: never
      referenceId?: never
      text?: never
    }
  | {
      boolean?: never
      clear: boolean
      date?: never
      number?: never
      option?: never
      options?: never
      referenceId?: never
      text?: never
    }
  | {
      boolean?: never
      clear?: never
      date: string
      number?: never
      option?: never
      options?: never
      referenceId?: never
      text?: never
    }
  | {
      boolean?: never
      clear?: never
      date?: never
      number: number
      option?: never
      options?: never
      referenceId?: never
      text?: never
    }
  | {
      boolean?: never
      clear?: never
      date?: never
      number?: never
      option: string
      options?: never
      referenceId?: never
      text?: never
    }
  | {
      boolean?: never
      clear?: never
      date?: never
      number?: never
      option?: never
      options: Array<string>
      referenceId?: never
      text?: never
    }
  | {
      boolean?: never
      clear?: never
      date?: never
      number?: never
      option?: never
      options?: never
      referenceId: string | number
      text?: never
    }
  | {
      boolean?: never
      clear?: never
      date?: never
      number?: never
      option?: never
      options?: never
      referenceId?: never
      text: string
    }

export type ViewerQueryVariables = Exact<{ [key: string]: never }>

export type ViewerQuery = {
  viewer: {
    organizationId: string
    actorType: string
    roleKey: string | null
    permissions: Array<string>
    user: { id: string; name: string; email: string } | null
    agent: { id: string; name: string } | null
  }
}

export type TodayQueryVariables = Exact<{ [key: string]: never }>

export type TodayQuery = {
  viewer: { user: { id: string; name: string } | null }
  today: {
    feedback: Array<{
      id: string
      interviewKey: string
      startsAt: string | null
      interviewerUserIds: Array<string>
      application: {
        id: string
        person: { displayName: string } | null
        job: { title: string } | null
      } | null
    }>
    reviews: Array<{
      id: string
      person: { displayName: string } | null
      job: { id: string; title: string } | null
    }>
    upcoming: Array<{
      id: string
      interviewKey: string
      startsAt: string | null
      interviewerUserIds: Array<string>
      application: {
        id: string
        person: { displayName: string } | null
        job: { title: string } | null
      } | null
    }>
  }
}

export type TodayOffersQueryVariables = Exact<{ [key: string]: never }>

export type TodayOffersQuery = {
  today: {
    offersPending: Array<{
      id: string
      application: {
        id: string
        person: { displayName: string } | null
        job: { title: string } | null
      } | null
    }>
  }
}

export type TodayJobsQueryVariables = Exact<{ [key: string]: never }>

export type TodayJobsQuery = {
  today: { jobs: Array<{ id: string; title: string; openings: number; activeCount: number }> }
}

export type InterviewsHubQueryVariables = Exact<{
  scope?: string | null | undefined
}>

export type InterviewsHubQuery = {
  viewer: { user: { id: string } | null }
  upcoming: Array<{
    id: string
    applicationId: string
    interviewKey: string
    status: string
    startsAt: string | null
    interviewerUserIds: Array<string>
    application: { id: string; person: { displayName: string } | null; job: { title: string } | null } | null
  }>
  schedule: Array<{
    id: string
    applicationId: string
    interviewKey: string
    status: string
    startsAt: string | null
    interviewerUserIds: Array<string>
    application: { id: string; person: { displayName: string } | null; job: { title: string } | null } | null
  }>
  feedback: Array<{
    id: string
    applicationId: string
    interviewKey: string
    status: string
    startsAt: string | null
    interviewerUserIds: Array<string>
    application: { id: string; person: { displayName: string } | null; job: { title: string } | null } | null
  }>
  mine: Array<{
    id: string
    applicationId: string
    interviewKey: string
    status: string
    startsAt: string | null
    interviewerUserIds: Array<string>
    application: { id: string; person: { displayName: string } | null; job: { title: string } | null } | null
  }>
}

export type HubInterviewFragment = {
  id: string
  applicationId: string
  interviewKey: string
  status: string
  startsAt: string | null
  interviewerUserIds: Array<string>
  application: { id: string; person: { displayName: string } | null; job: { title: string } | null } | null
}

export type OffersHubQueryVariables = Exact<{
  status?: string | null | undefined
}>

export type OffersHubQuery = {
  offers: {
    counts: Array<{ status: string; count: number }>
    nodes: Array<{
      id: string
      status: string
      updatedAt: string
      application: {
        id: string
        person: { displayName: string } | null
        job: { title: string } | null
      } | null
    }>
  }
}

export type JobWorkspaceQueryVariables = Exact<{
  id: string | number
  after?: string | null | undefined
}>

export type JobWorkspaceQuery = {
  job: {
    id: string
    title: string
    status: string
    openings: number
    confidential: boolean
    codeName: string | null
    version: number
    stages: Array<{ key: string; name: string | null; type: string | null }>
    applications: {
      pageInfo: { hasNextPage: boolean; endCursor: string | null }
      nodes: Array<{
        id: string
        status: string
        currentStageKey: string
        version: number
        updatedAt: string
        createdAt: string
        person: { id: string; displayName: string; primaryEmail: string | null } | null
        transitions: Array<{ toStageKey: string | null; createdAt: string }>
        upcomingInterview: { interviewKey: string; stageKey: string; startsAt: string | null } | null
      } | null> | null
    }
  } | null
}

export type PersonCustomFieldsQueryVariables = Exact<{
  id: string | number
}>

export type PersonCustomFieldsQuery = {
  person: {
    id: string
    customFields: Array<
      | {
          boolean: boolean | null
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
      | {
          date: string | null
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
      | {
          number: number | null
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
      | {
          option: string | null
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
      | {
          options: Array<string>
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
      | {
          referenceId: string | null
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
      | {
          text: string | null
          key: string
          fieldType: string
          fieldVersion: number
          definition: { label: string }
        }
    >
  } | null
}

export type AgentsQueryVariables = Exact<{ [key: string]: never }>

export type AgentsQuery = {
  viewer: { permissions: Array<string>; agent: { id: string } | null }
  agents: Array<{
    id: string
    name: string
    description: string | null
    status: string
    scopes: Array<string>
    version: number
    createdAt: string
  }>
}

export type CustomFieldDefinitionsQueryVariables = Exact<{
  entity: string
}>

export type CustomFieldDefinitionsQuery = {
  customFieldDefinitions: Array<{
    id: string
    key: string
    label: string
    fieldType: string
    dataClass: string
    status: string
    version: number
    required: boolean
    options: Array<{ key: string; label: string }>
  }>
}

export type CreateCustomFieldMutationVariables = Exact<{
  entity: string
  key: string
  label: string
  fieldType: string
  dataClass?: string | null | undefined
  options?: Array<CustomFieldOptionInput> | CustomFieldOptionInput | null | undefined
}>

export type CreateCustomFieldMutation = {
  createCustomField: {
    field: { id: string; key: string; version: number } | null
    userErrors: Array<{ code: string; message: string }>
  } | null
}

export type ArchiveCustomFieldMutationVariables = Exact<{
  id: string | number
  restore?: boolean | null | undefined
  expectedVersion?: number | null | undefined
}>

export type ArchiveCustomFieldMutation = {
  archiveCustomField: {
    field: { id: string; status: string; version: number } | null
    userErrors: Array<{ code: string; message: string }>
  } | null
}

export type SetCustomFieldValueMutationVariables = Exact<{
  entityType: string
  entityId: string | number
  key: string
  value: CustomFieldValueInput
}>

export type SetCustomFieldValueMutation = {
  setCustomFieldValue: {
    value:
      | { key: string; fieldVersion: number }
      | { key: string; fieldVersion: number }
      | { key: string; fieldVersion: number }
      | { key: string; fieldVersion: number }
      | { key: string; fieldVersion: number }
      | { key: string; fieldVersion: number }
      | { key: string; fieldVersion: number }
      | null
    userErrors: Array<{ code: string; message: string }>
  } | null
}

export type MoveApplicationStageMutationVariables = Exact<{
  id: string | number
  to: string
  expectedVersion?: number | null | undefined
}>

export type MoveApplicationStageMutation = {
  moveApplicationStage: {
    application: { id: string; currentStageKey: string; version: number } | null
    userErrors: Array<{ code: string; message: string }>
  } | null
}
