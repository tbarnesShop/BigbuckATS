# frozen_string_literal: true

class PersonMerger
  def self.call(survivor:, merged:, actor: nil)
    new(survivor: survivor, merged: merged, actor: actor).call
  end

  def initialize(survivor:, merged:, actor: nil)
    @survivor = survivor
    @merged = merged
    @actor = actor
  end

  def call
    if DemoSandbox.for_organization(@survivor.organization_id)
      raise Authenticator::Forbidden.new("demo_action_blocked", DemoPolicy::MESSAGE)
    end
    raise ArgumentError, "same person" if @survivor.id == @merged.id
    raise ArgumentError, "cross-tenant" if @survivor.organization_id != @merged.organization_id

    ActiveRecord::Base.transaction do
      Current.organization_id = @survivor.organization_id

      @merged.contact_points.find_each do |cp|
        conflict = PersonContactPoint.find_by(kind: cp.kind, canonical_key: cp.normalized_value)
        if conflict && conflict.person_id != @survivor.id && conflict.person_id != @merged.id
          cp.update!(person_id: @survivor.id, duplicate_of_person_id: conflict.person_id, canonical_key: nil)
        elsif conflict&.person_id == @survivor.id
          cp.destroy!
        else
          cp.update!(person_id: @survivor.id, duplicate_of_person_id: nil, canonical_key: cp.normalized_value)
        end
      end

      PersonAffiliation.where(person_id: @merged.id).update_all(person_id: @survivor.id)
      Document.where(person_id: @merged.id).update_all(person_id: @survivor.id)

      @merged.update!(merged_into_id: @survivor.id)

      MergeSuggestion.where(status: "open").where(
        "(person_a_id = :a AND person_b_id = :b) OR (person_a_id = :b AND person_b_id = :a)",
        a: @survivor.id, b: @merged.id
      ).update_all(status: "merged")

      ChangeWriter.call(
        record: @survivor,
        action: "person.merged",
        event_type: "person.merged",
        payload: { "merged_id" => @merged.id, "survivor_id" => @survivor.id },
        changes: { "merged_id" => [ nil, @merged.id ] }
      )

      @survivor
    end
  end
end
