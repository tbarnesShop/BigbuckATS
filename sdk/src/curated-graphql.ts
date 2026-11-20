/** Curated GraphQL operations shared by MCP and the CLI. Keep documents import-free. */
export type CuratedGraphqlTool = {
  name: string
  description: string
  write: boolean
  document: string
  /** Variable names and types, for the tool's input schema. */
  variables: Record<
    string,
    { type: 'string' | 'integer' | 'object' | 'boolean'; required?: boolean; description?: string }
  >
}

/** Small, high-value operations agents and the CLI use most. Anything else: ad hoc graphql(). */
export const CURATED_TOOLS: CuratedGraphqlTool[] = [
  {
    name: 'gql_whoami',
    description: 'Who this agent is, who it acts for, and its effective permissions.',
    write: false,
    document: `query { viewer { organizationId actorType roleKey permissions user { id name } agent { id name } } }`,
    variables: {},
  },
  {
    name: 'gql_job_pipeline',
    description: "A job's stages and its applications (stage, version, person) in one call.",
    write: false,
    // first:25 stays under the ad-hoc GraphQL complexity cap (200). first:100 was 709.
    document: `query($id: ID!) { job(id: $id) { id title status stages { key name } applications(first: 25) { nodes { id status currentStageKey version person { id displayName } } } } }`,
    variables: { id: { type: 'string', required: true, description: 'Job id' } },
  },
  {
    name: 'gql_person',
    description: 'A person with their applications and custom field values.',
    write: false,
    document: `query($id: ID!) { person(id: $id) { id displayName lifecycleStage applications(first: 20) { nodes { id status currentStageKey job { id title } } } customFields { key fieldType ... on CustomFieldTextValue { text } ... on CustomFieldNumberValue { number } ... on CustomFieldDateValue { date } ... on CustomFieldBooleanValue { boolean } ... on CustomFieldOptionValue { option } ... on CustomFieldOptionsValue { options } } } }`,
    variables: { id: { type: 'string', required: true, description: 'Person id' } },
  },
  {
    name: 'gql_custom_field_definitions',
    description: 'Custom fields defined for person, job or application records, with types and options.',
    write: false,
    document: `query($entity: String!) { customFieldDefinitions(entity: $entity) { key label fieldType required options { key label } version } }`,
    variables: { entity: { type: 'string', required: true, description: 'person, job or application' } },
  },
  {
    name: 'gql_move_application_stage',
    description:
      'Move an application to another stage. Pass expectedVersion from your last read to avoid overwriting newer changes.',
    write: true,
    document: `mutation($id: ID!, $to: String!, $reason: String, $expectedVersion: Int) { moveApplicationStage(input: { applicationId: $id, toStageKey: $to, reason: $reason, expectedVersion: $expectedVersion }) { application { id currentStageKey version } userErrors { code message } } }`,
    variables: {
      id: { type: 'string', required: true },
      to: { type: 'string', required: true, description: 'Target stage key' },
      reason: { type: 'string' },
      expectedVersion: { type: 'integer' },
    },
  },
  {
    name: 'gql_reject_application',
    description: 'Reject an active application with a reason.',
    write: true,
    document: `mutation($id: ID!, $reason: String!, $expectedVersion: Int) { rejectApplication(input: { applicationId: $id, reason: $reason, expectedVersion: $expectedVersion }) { application { id status version } userErrors { code message } } }`,
    variables: {
      id: { type: 'string', required: true },
      reason: { type: 'string', required: true },
      expectedVersion: { type: 'integer' },
    },
  },
  {
    name: 'gql_set_custom_field_value',
    description:
      'Set or clear a custom field value. value is one of { text | number | date | boolean | option | options | referenceId | clear }.',
    write: true,
    document: `mutation($entityType: String!, $entityId: ID!, $key: String!, $value: CustomFieldValueInput!) { setCustomFieldValue(input: { entityType: $entityType, entityId: $entityId, key: $key, value: $value }) { value { key fieldVersion } userErrors { code message } } }`,
    variables: {
      entityType: { type: 'string', required: true, description: 'person, job or application' },
      entityId: { type: 'string', required: true },
      key: { type: 'string', required: true },
      value: { type: 'object', required: true },
    },
  },
]

export function findCuratedTool(name: string): CuratedGraphqlTool | undefined {
  return CURATED_TOOLS.find((tool) => tool.name === name)
}

/** True when the document contains a mutation operation. */
export function isGraphqlMutation(document: string): boolean {
  const withoutComments = document.replace(/#[^\n]*/g, '')
  return /(^|[\s}])mutation\b/.test(withoutComments)
}
