# frozen_string_literal: true

# Criteria-based rediscovery. Candidates are people the org already knows (past applicants, pool
# members, employees and alumni); each is judged against the job's explicit criteria and the
# verdict, with the evidence behind it, is stored so the UI can say why.
#
# criteria: [{ "id", "label", "kind" => "must"|"nice", "match" => { "q"|"tag"|"location"|"title"|"company"|"source" => "..." } }]
class RediscoveryEngine
  MAX_CANDIDATES = 500
  RECENT_REJECTION = 90.days

  Result = Struct.new(:created, :refreshed, :skipped, :buckets, keyword_init: true)

  def self.run!(job:, viewer:, found_by_agent_id: nil)
    new(job: job, viewer: viewer, found_by_agent_id: found_by_agent_id).run!
  end

  def initialize(job:, viewer:, found_by_agent_id:)
    @job = job
    @viewer = viewer
    @agent_id = found_by_agent_id
    @criteria = Array(job.criteria).map { |c| c.to_h.stringify_keys }
  end

  def run!
    people = candidates
    ctx = context_for(people)
    result = Result.new(created: 0, refreshed: 0, skipped: 0, buckets: Hash.new(0))
    existing = RediscoveryCandidate.where(job_id: @job.id).index_by(&:person_id)

    people.each do |person|
      verdicts = @criteria.map { |c| verdict(person, c, ctx) }
      must = verdicts.select { |v| v["kind"] == "must" }
      next result.skipped += 1 unless must.all? { |v| v["met"] }

      bucket, reasons = bucket_for(person, verdicts, ctx)
      next result.skipped += 1 unless bucket

      row = existing[person.id]
      if row&.decided?
        result.skipped += 1
        next
      end
      attrs = { bucket: bucket, score: score(verdicts, bucket), verdicts: verdicts, reasons: reasons }
      if row
        row.update!(attrs)
        result.refreshed += 1
      else
        RediscoveryCandidate.create!(attrs.merge(job: @job, person: person, found_by_agent_id: @agent_id))
        result.created += 1
      end
      result.buckets[bucket] += 1
    end
    result
  end

  private

  def candidates
    visible = PersonVisibility.scope_for(@viewer).not_merged.not_erased.where(do_not_contact: false)
    active_here = Application.where(job_id: @job.id, status: "active").select(:person_id)
    applied = ResourceVisibility.applications.where.not(status: "active").select(:person_id)
    pooled = ResourceVisibility.members.where(status: "active").select(:person_id)
    internal = Person.where(lifecycle_stage: %w[employee alumni]).select(:id)
    visible.where(id: applied).or(visible.where(id: pooled)).or(visible.where(id: internal))
           .where.not(id: active_here).where.not(id: recently_rejected_here)
           .order(:created_at).limit(MAX_CANDIDATES).to_a
  end

  def recently_rejected_here
    Application.where(job_id: @job.id, status: "rejected", updated_at: RECENT_REJECTION.ago..).select(:person_id)
  end

  def context_for(people)
    ids = people.map(&:id)
    tags = PersonTag.where(person_id: ids).includes(:tag).group_by(&:person_id).transform_values { |r| r.filter_map { |pt| pt.tag&.name } }
    notes = PersonNote.where(person_id: ids).group_by(&:person_id).transform_values { |r| r.map(&:body) }
    companies = PersonAffiliation.where(person_id: ids, current: true).includes(:company).group_by(&:person_id)
                                 .transform_values { |r| r.filter_map { |a| a.company&.name } }
    apps = ResourceVisibility.applications.where(person_id: ids).where.not(status: "active").group_by(&:person_id)
    pooled = ResourceVisibility.members.where(person_id: ids, status: "active").pluck(:person_id).to_set
    { tags: tags, notes: notes, companies: companies, apps: apps, pooled: pooled }
  end

  # Evidence-bearing check of one criterion against one person.
  def verdict(person, criterion, ctx)
    match = (criterion["match"] || {}).to_h.stringify_keys
    fields = {
      "name" => person.display_name, "headline" => person.headline, "title" => person.current_title, "city" => person.city,
      "company" => ctx[:companies][person.id]&.join(", "), "tags" => ctx[:tags][person.id]&.join(", "),
      "notes" => ctx[:notes][person.id]&.join(" ")
    }
    evidence = []
    met = match.any? && match.all? do |key, value|
      case key
      when "q" then value.to_s.downcase.split(/\s+/).reject(&:empty?).all? { |w| (found = fields.find { |_, v| v.to_s.downcase.include?(w) }) && evidence << evidence_line(found, w) }
      when "tag" then value.to_s.split(",").map { |t| t.strip.downcase }.reject(&:empty?).all? { |t| (ctx[:tags][person.id] || []).any? { |n| n.downcase == t } && evidence << "tag: #{t}" }
      when "location" then person.city.to_s.downcase.include?(value.to_s.downcase) && evidence << "city: #{person.city}"
      when "title" then [ person.current_title, person.headline ].any? { |v| v.to_s.downcase.include?(value.to_s.downcase) } && evidence << "title: #{person.current_title || person.headline}"
      when "company" then fields["company"].to_s.downcase.include?(value.to_s.downcase) && evidence << "company: #{fields['company']}"
      when "source" then person.source == value.to_s && evidence << "source: #{person.source}"
      else false
      end
    end
    { "id" => criterion["id"], "label" => criterion["label"], "kind" => criterion["kind"], "met" => met ? true : false,
      "evidence" => met ? evidence.uniq.first(4) : [] }
  end

  def evidence_line(found, word)
    field, text = found
    snippet = text.to_s
    index = snippet.downcase.index(word)
    from = [ index.to_i - 30, 0 ].max
    "#{field}: …#{snippet[from, 80].to_s.strip}…"
  end

  def bucket_for(person, verdicts, ctx)
    reasons = []
    apps = ctx[:apps][person.id] || []
    same_job_rejected = apps.any? { |a| a.job_id == @job.id && a.status == "rejected" }
    nice_met = verdicts.count { |v| v["kind"] == "nice" && v["met"] }
    must_count = verdicts.count { |v| v["kind"] == "must" }

    bucket =
      if person.lifecycle_stage.in?(%w[employee alumni]) then (reasons << person.lifecycle_stage; "internal_transfer")
      elsif apps.any? { |a| a.status == "rejected" } then (reasons << (same_job_rejected ? "rejected_earlier_for_this_job" : "rejected_elsewhere"); "silver_medalist")
      elsif must_count.positive? && nice_met.positive? then (reasons << "all_must_haves_and_nice_to_haves"; "high_fit")
      elsif ctx[:pooled].include?(person.id) || person.engagement_status.in?(%w[replied interested]) then (reasons << "warm"; "warm_lead")
      elsif must_count.positive? then (reasons << "all_must_haves"; "high_fit")
      end
    [ bucket, reasons ]
  end

  def score(verdicts, bucket)
    musts = verdicts.select { |v| v["kind"] == "must" }
    nices = verdicts.select { |v| v["kind"] == "nice" }
    total = 40
    total += 40 * (nices.empty? ? 0 : nices.count { |v| v["met"] }.fdiv(nices.size))
    total += 20 if musts.any?
    total += { "silver_medalist" => 15, "internal_transfer" => 10, "warm_lead" => 5, "high_fit" => 0 }.fetch(bucket)
    total.round
  end
end
