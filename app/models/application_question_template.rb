class ApplicationQuestionTemplate < ApplicationRecord
  include HasUuid
  include TenantScoped
  belongs_to :owner, class_name: "User", foreign_key: :owner_user_id
  validates :name, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: %w[active archived] }
  before_validation { self.questions = PostingQuestions.normalize(questions || []) }
end
