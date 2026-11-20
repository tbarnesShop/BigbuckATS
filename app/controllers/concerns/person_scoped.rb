# frozen_string_literal: true

# For controllers whose resources hang off a person: the person must be visible to the caller.
module PersonScoped
  extend ActiveSupport::Concern

  private

  def viewer
    return @viewer if defined?(@viewer)

    @viewer =
      if current_principal
        PrincipalViewer.new(current_principal)
      elsif Current.actor_id.present?
        Membership.find_by(user_id: Current.actor_id, status: "active")
      end
  end

  def visible_person!(id)
    person = Person.find(id)
    raise ActiveRecord::RecordNotFound unless PersonVisibility.visible?(person, viewer: viewer)

    person
  end
end
