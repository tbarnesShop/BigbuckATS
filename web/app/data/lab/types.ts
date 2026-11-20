export type Json = string | number | boolean | null | Json[] | { [key: string]: Json }
export type Surface = 'ui' | 'mcp' | 'api' | 'cli'
export type Mode = 'explore' | 'compare' | 'connect'
export type Sandbox = {
  surface: Surface
  organization_id: string
  generation: number
  state: string
  resets_at: string
  shared: true
}
export type Persona = {
  email: string
  name: string
  role_key: string
  role_name: string
  permissions: string[]
}
export type Schema = {
  type?: string
  description?: string
  enum?: string[]
  properties?: Record<string, Schema>
  required?: string[]
  items?: Schema
  example?: Json
  default?: Json
  additionalProperties?: boolean
  $ref?: string
}
export type CatalogItem = {
  name: string
  description: string
  method?: string
  path?: string
  write: boolean
  inputSchema: Schema
  bodySchema?: Schema
  available: boolean
}
export type RecordLink = { label: string; href: string; kind: string; id: string }
export type Result = {
  ok: boolean
  status: number
  duration: number
  output: unknown
  links: RecordLink[]
  error?: string
  outcome?: 'unknown'
  warning?: string
  request?: string
  example?: string
}
export type Step = {
  id: string
  title: string
  detail: string
  permission?: string
  surface?: Surface
  api?: string
  mcp?: string
  command?: string
  args?: Record<string, Json>
  ui?: string
  check?: 'person' | 'pool' | 'member' | 'import' | 'plan' | 'applied'
}
export type Story = { title: string; intro: string; steps: Step[] }
export const SURFACES: Surface[] = ['ui', 'mcp', 'api', 'cli']
export const MODES: Mode[] = ['explore', 'compare', 'connect']
export const surfaceValue = (value: unknown): Surface =>
  SURFACES.includes(value as Surface) ? (value as Surface) : 'ui'
export const modeValue = (value: unknown): Mode =>
  MODES.includes(value as Mode) ? (value as Mode) : 'explore'
