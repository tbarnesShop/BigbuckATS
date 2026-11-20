import type { Schema } from '../../../data/lab/types.ts'
/** Validate parsed execution arguments against the currently authorized catalog, never while editing. */
export function validateInput(value: unknown, schema: Schema, path = 'input'): void {
  if (schema.enum && !schema.enum.includes(value as never))
    throw new SyntaxError(`${path} must use a listed value`)
  const type = schema.type
  if (type === 'object' || schema.properties) {
    if (!value || typeof value !== 'object' || Array.isArray(value))
      throw new SyntaxError(`${path} must be an object`)
    const object = value as Record<string, unknown>
    for (const key of schema.required ?? [])
      if (object[key] === undefined) throw new SyntaxError(`${path}.${key} is required`)
    for (const [key, field] of Object.entries(object)) {
      if (schema.properties?.[key]) validateInput(field, schema.properties[key], `${path}.${key}`)
      else if (schema.additionalProperties === false) throw new SyntaxError(`${path}.${key} is not supported`)
    }
  } else if (type === 'array') {
    if (!Array.isArray(value)) throw new SyntaxError(`${path} must be an array`)
    if (schema.items) value.forEach((item, index) => validateInput(item, schema.items!, `${path}[${index}]`))
  } else if (
    type === 'integer'
      ? !Number.isInteger(value)
      : type === 'number'
        ? typeof value !== 'number' || !Number.isFinite(value)
        : type === 'string' || type === 'boolean'
          ? typeof value !== type
          : false
  ) {
    throw new SyntaxError(`${path} must be ${type}`)
  }
}
