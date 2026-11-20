export type ProblemBody = {
  type?: string
  title?: string
  status?: number
  code?: string
  detail?: string
  param?: string
  request_id?: string
}

export class BigBuckApiError extends Error {
  readonly status: number
  readonly code?: string
  readonly problem: ProblemBody
  readonly requestId?: string

  constructor(status: number, problem: ProblemBody, fallbackMessage?: string) {
    super(problem.title ?? problem.detail ?? fallbackMessage ?? `HTTP ${status}`)
    this.name = 'BigBuckApiError'
    this.status = status
    this.code = problem.code
    this.problem = problem
    this.requestId = problem.request_id
  }
}
