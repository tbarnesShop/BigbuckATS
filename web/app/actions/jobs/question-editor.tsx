import type { Handle } from 'remix/component'
import type { PostingQuestion } from '../../data/api.ts'

export const questionTypes = [
  'text',
  'long_text',
  'number',
  'boolean',
  'email',
  'url',
  'select',
  'multi_select',
] as const
export function readQuestions(form: FormData): PostingQuestion[] {
  const count = Math.min(50, Math.max(0, Number(form.get('question_count')) || 0))
  return Array.from({ length: count }, (_, i) => ({
    key: String(form.get(`q_key_${i}`) ?? `question_${i + 1}`),
    label: String(form.get(`q_label_${i}`) ?? '').trim(),
    field_type: String(form.get(`q_type_${i}`) ?? 'text'),
    required: form.get(`q_required_${i}`) === 'on',
    options: String(form.get(`q_options_${i}`) ?? '')
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean),
  }))
}
export function addQuestion(questions: PostingQuestion[]) {
  let key = 1
  while (questions.some((q) => q.key === `question_${key}`)) key++
  return [
    ...questions,
    { key: `question_${key}`, label: '', field_type: 'text', required: false, options: [] },
  ]
}
export function QuestionEditor(handle: Handle<{ questions: PostingQuestion[] }>) {
  return () => (
    <div class="question-editor">
      <input type="hidden" name="question_count" value={handle.props.questions.length} />
      {handle.props.questions.map((question, i) => (
        <fieldset key={question.key} class="question-row">
          <legend>Question {i + 1}</legend>
          <input type="hidden" name={`q_key_${i}`} value={question.key} />
          <label class="field">
            <span>Question {i + 1} wording</span>
            <input name={`q_label_${i}`} defaultValue={question.label} required maxLength={500} />
          </label>
          <div class="question-fields">
            <label class="field">
              <span>Question {i + 1} type</span>
              <select name={`q_type_${i}`} aria-label={`Question ${i + 1} type`}>
                {questionTypes.map((type) => (
                  <option key={type} value={type} selected={type === question.field_type}>
                    {type.replaceAll('_', ' ')}
                  </option>
                ))}
              </select>
            </label>
            <label class="question-required">
              <span>
                <input type="checkbox" name={`q_required_${i}`} defaultChecked={question.required} /> Required
                answer
              </span>
            </label>
          </div>
          <label class="field">
            <span>Question {i + 1} choices (one per line, for select types)</span>
            <textarea name={`q_options_${i}`} rows={3} defaultValue={(question.options ?? []).join('\n')} />
          </label>
          <button
            class="btn btn-ghost btn-small"
            name="intent"
            value={`remove_question:${i}`}
            type="submit"
            formNoValidate
          >
            Remove question {i + 1}
          </button>
        </fieldset>
      ))}
      {handle.props.questions.length < 50 ? (
        <button
          class="btn btn-ghost btn-small"
          name="intent"
          value="add_question"
          type="submit"
          formNoValidate
        >
          Add question
        </button>
      ) : null}
    </div>
  )
}
