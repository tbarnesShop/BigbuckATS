import type { CodegenConfig } from '@graphql-codegen/cli'

// Types for app/graphql/operations.ts from the committed Rails contract.
const config: CodegenConfig = {
  schema: '../schema.graphql',
  documents: ['app/graphql/operations.ts'],
  generates: {
    'app/graphql/generated.ts': {
      plugins: ['typescript-operations'],
      config: {
        avoidOptionals: { field: true, inputValue: false, object: false },
        enumsAsTypes: true,
        skipTypename: true,
        onlyOperationTypes: true,
        scalars: { ISO8601DateTime: 'string', ISO8601Date: 'string', JSON: 'unknown' },
      },
    },
  },
}

export default config
