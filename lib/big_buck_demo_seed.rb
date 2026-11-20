# frozen_string_literal: true

require "zlib"
require "digest"

# Demo-quality enrichment layered on top of BigBuckDataset.
#
# BigBuckDataset stays the small deterministic fixture that tests and the lab
# sandboxes depend on. This subclass keeps its build/reload/wipe behaviour and then,
# idempotently, adds everything a live demo needs: more staff, departments, pipeline
# templates (with versions and per-job overrides), jobs/requisitions/postings, message,
# offer and question templates, sequences with enrollments and tasks, sourcing pools,
# candidates with real PDF resumes and applications spread across every stage (with coherent
# interview loops, scorecards, offers, emails and timelines), CRM volume toward ~800 people,
# referrals, saved searches, webhooks, agents, an import run, and compliance records.
#
#   bin/rails db:seed                # base dataset + enrichment (re-runnable)
#   RESET=1 bin/rails db:seed        # wipe the big-buck org and rebuild everything
#   FORCE=1 bin/rails db:seed        # re-run enrichment even if already applied
class BigBuckDemoSeed < BigBuckDataset
  C = BigBuckDemo::Content
  J = BigBuckDemo::Jobs
  DEFAULT_PEOPLE_TARGET = 800
  EMAIL_DOMAINS = %w[mail.test inbox.test email.test contacts.test people.test].freeze
  PHONE_AREAS = %w[212 415 512 617 312 206 303 646 718 917].freeze

  ROLE_KEY = { standard_internal: :standard }.freeze
  RESUME_FAMILY = { sdr: :sales, standard_internal: :support }.freeze
  RATING_SEQ = {
    strong: %w[strong_yes yes strong_yes], solid: %w[yes yes strong_yes],
    mixed: %w[yes mixed mixed], weak: %w[mixed no no]
  }.freeze
  # A second interviewer in the same interview lands one notch away, so their write-ups differ.
  RATING_NEIGHBOR = { "strong_yes" => "yes", "yes" => "strong_yes", "mixed" => "no", "no" => "mixed" }.freeze
  HOURS = { standard: BigBuckDataset::STANDARD_HOURS, late: BigBuckDataset::LATE_HOURS, eu: BigBuckDataset::EU_HOURS }.freeze

  # GmailClient::Fake numbers messages from msg_1 per instance, but provider ids are unique
  # per org. Start after the highest id already stored so top-ups never collide.
  class OffsetFakeGmail < GmailClient::Fake
    def initialize(start)
      super()
      @seq = start
    end
  end

  attr_reader :summary

  def self.call(slug: DEFAULT_SLUG, reset: false, force: ENV["FORCE"].present?)
    new(slug: slug, reset: reset, force: force).call
  end

  def initialize(slug:, reset:, force: false)
    super(slug: slug, reset: reset)
    @force = force
    @summary = Hash.new(0)
  end

  def call
    result = super
    enrich!(result.organization)
    result
  end

  private

  # RESET must also clear the tables this layer adds (the base wipe predates them).
  # The base wipe predates the tenant-scoped composite foreign keys (it deletes
  # offer_templates / approval_policies before the offer versions that point at them), and
  # this layer adds more dependent tables. Every row removed belongs to this one org, so
  # FK checks are lifted for the wipe only, the same approach DemoWorkspaces.refresh! uses.
  def wipe_existing!
    org = Organization.find_by(slug: @slug)
    return super unless org

    conn = ActiveRecord::Base.connection
    conn.execute("SET FOREIGN_KEY_CHECKS=0")
    wipe_demo_extras!(org)
    super
  ensure
    ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS=1")
  end

  def wipe_demo_extras!(org)
    id = org.id
    Current.organization_id = id
    docs = Document.unscoped.where(organization_id: id).pluck(:id)
    ActiveStorage::Attachment.where(record_type: "Document", record_id: docs).find_each(&:purge)
    [ AgentProposal, RediscoveryCandidate, OutreachSnapshot, PersonNote, PersonTag, Tag, OptOut,
      SourcingTask, Referral, SavedSearch, LegalHold, DataRequest, DncCompany, WebhookDelivery ].each do |model|
      model.unscoped.where(organization_id: id).delete_all
    end
    ImportRow.unscoped.where(organization_id: id).delete_all
    ImportRun.unscoped.where(organization_id: id).delete_all
    Job.unscoped.where(organization_id: id).update_all(requisition_id: nil)
    Requisition.unscoped.where(organization_id: id).delete_all
  end

  # ---------------------------------------------------------------- orchestration

  def enrich!(org)
    Current.organization_id = org.id
    if !@force && org.setting("demo_enrichment_version").to_i >= C::VERSION
      puts "  demo enrichment v#{C::VERSION} already applied (FORCE=1 to re-run)"
      refresh_careers_copy!(org)
      return
    end
    started = Time.current
    @now = Time.current
    @cooldown = org.setting("contact_cooldown_days")
    org.merge_settings!("contact_cooldown_days" => 0)
    @cooldown_changed = true
    previous_gmail = GmailClient.backend
    highest = Communication.where("provider_message_id REGEXP '^(msg|thr)_[0-9]+$'").pluck(:provider_message_id).map { |id| id.split("_").last.to_i }.max.to_i
    GmailClient.backend = OffsetFakeGmail.new(highest + 1000)
    ActiveRecord::Base.transaction do
      load_context!(org)
      Current.actor_id = @s.fetch(:recruiter).id
      seed_departments!
      seed_staff!
      seed_companies!
      seed_rubrics!
      seed_person_custom_fields!
      seed_templates!
      seed_sequences!
      seed_pipelines!
      seed_requisitions_and_jobs!
      seed_posting_details!
      seed_pools!
      seed_funnels!
      seed_pool_conversions_and_outreach!
      seed_silver_medalists_and_alumni!
      seed_base_pool_outreach!
      seed_resumes_for_existing_people!
      seed_referrals!
      seed_saved_searches!
      seed_careers_content!
      seed_admin_surfaces!
      seed_tasks!
      seed_crm_volume!
      seed_crm_depth!
      backfill_person_sources!
      backdate_base_data!
    end
    seed_outreach_snapshots!
    org.reload.merge_settings!("demo_enrichment_version" => C::VERSION)
    puts "  demo enrichment applied in #{(Time.current - started).round(1)}s: #{@summary.sort.map { |k, v| "#{k}=#{v}" }.join(' ')}"
  ensure
    GmailClient.backend = previous_gmail if previous_gmail
    org.reload.merge_settings!("contact_cooldown_days" => (@cooldown || OutreachPolicy::DEFAULT_COOLDOWN_DAYS)) if @cooldown_changed
  end

  def load_context!(org)
    @org = org
    @roles = Role.all.index_by(&:key)
    @dept_dim = Dimension.find_by!(key: "department")
    @loc_dim = Dimension.find_by!(key: "location")
    @loc_values = DimensionValue.where(dimension: @loc_dim).index_by(&:key)
    @mailbox = Mailbox.find_by!(email: "recruiting@bigbuck.test")
    @custom = CustomField.where(entity: "person").index_by(&:key)
    @privacy_version = NoticeVersion.order(:created_at).first!
    @processing = ConsentPurpose.find_by!(key: "data-processing")
    @outreach = ConsentPurpose.find_by!(key: "outreach")
    @s = {
      recruiter: User.find_by!(email: "recruiter@bigbuck.test"), hiring_manager: User.find_by!(email: "hm@bigbuck.test"),
      sales_hm: User.find_by!(email: "sales.hm@bigbuck.test"), eng_interviewer: User.find_by!(email: "ivy.interviewer@bigbuck.test"),
      sales_interviewer: User.find_by!(email: "owen.interviewer@bigbuck.test"), admin: User.find_by!(email: "admin@bigbuck.test"),
      owner: User.find_by!(email: "owner@bigbuck.test")
    }
    @companies = {}
    @rng = Random.new(2027)
    @names = Person.pluck(:display_name).to_set
    @emails = Person.pluck(:primary_email).compact.to_set
    @phones = PersonContactPoint.where(kind: "phone").pluck(:canonical_key).compact.to_set
    @phones.merge(Person.pluck(:primary_phone).compact)
    J::JOBS.each { |j| j[:funnel].each { |r| @names << r[:hero] if r[:hero] } }
    @name_i = 0
    @phone_i = 0
    @counter = 0
    @pools = {}
    @job_ctx = {}
  end

  # ---------------------------------------------------------------- org structure

  def seed_departments!
    @depts = DimensionValue.where(dimension: @dept_dim).index_by(&:key)
    C::DEPARTMENTS.each do |key, label|
      @depts[key] ||= DimensionValue.create!(dimension: @dept_dim, key: key, label: label).tap { @summary["departments"] += 1 }
    end
  end

  def seed_staff!
    C::STAFF.each do |row|
      user = User.find_or_create_by!(email: row[:email]) { |u| u.name = row[:name] }
      @s[row[:key]] = user
      membership = Membership.find_by(user: user) || Membership.create!(user: user, role: @roles.fetch(row[:role]), status: "active").tap { @summary["staff"] += 1 }
      if row[:dept]
        MembershipScope.find_or_create_by!(membership: membership, dimension: @dept_dim, dimension_value: @depts.fetch(row[:dept])) { |m| m.include_descendants = true }
      end
      unless InterviewerProfile.exists?(user_id: user.id)
        seed_interviewer_profile!(user, time_zone: row[:tz], working_hours: HOURS.fetch(row[:hours]), daily_limit: 4, weekly_limit: 12)
      end
      seed_calendar!(user) unless CalendarConnection.exists?(kind: "user", user_id: user.id)
    end
    pools = {
      "design-panel" => [ "Design panel", %i[design_hm design_ic] ], "product-panel" => [ "Product panel", %i[product_hm product_ic] ],
      "cs-panel" => [ "Customer success panel", %i[cs_hm cs_ic] ], "eng-panel" => [ nil, %i[eng_ic2] ]
    }
    pools.each do |key, (name, users)|
      pool = InterviewerPool.find_by(key: key) || InterviewerPool.create!(key: key, name: name)
      users.each { |u| InterviewerPoolMember.find_or_create_by!(interviewer_pool: pool, user: @s.fetch(u)) { |m| m.trainee = false; m.paused = false } }
    end
    [ [ "austin-war-room", "Austin War Room", "austin", 10 ], [ "london-snug", "London Snug", "london", 3 ], [ "berlin-loft", "Berlin Loft", "berlin", 6 ] ].each do |key, name, loc, cap|
      Room.find_or_create_by!(key: key) { |r| r.name = name; r.resource_email = "#{key}@resource.bigbuck.test"; r.location_key = loc; r.capacity = cap }
    end
    y = Date.current.year
    [ [ "Thanksgiving", Date.new(y, 11, 26), "us" ], [ "Winter Break", Date.new(y, 12, 28), nil ], [ "Bank Holiday", Date.new(y, 12, 26), "london" ] ].each do |name, on, loc|
      Holiday.find_or_create_by!(name: name, observed_on: on) { |h| h.location_key = loc }
    end
  end

  def seed_companies!
    (BigBuckDataset::COMPANIES + C::EXTRA_COMPANIES).each do |c|
      @companies[c[:key]] = Company.find_by(domain: c[:domain]) ||
                            Company.create!(name: c[:name], domain: c[:domain], industry: c[:industry], employee_band: c[:employee_band]).tap { @summary["companies"] += 1 }
    end
    @company_keys = @companies.keys
  end

  def seed_rubrics!
    C::NEW_RUBRICS.each do |key, (name, guidance, attrs)|
      next if ScorecardRubric.exists?(key: key)
      ScorecardRubric.create!(key: key, name: name, guidance: guidance, attributes_spec: attrs.map { |k, n| { "key" => k, "name" => n } })
      @summary["rubrics"] += 1
    end
  end

  WORK_AUTH = [ "Citizen or permanent resident", "Work visa", "Needs sponsorship" ].freeze

  def seed_person_custom_fields!
    CustomField.find_or_create_by!(entity: "person", key: "work_authorization") do |f|
      f.label = "Work authorization"; f.field_type = "select"; f.data_class = "internal"; f.options = WORK_AUTH; f.filterable = true
    end
    CustomField.find_or_create_by!(entity: "person", key: "notice_period_weeks") do |f|
      f.label = "Notice period (weeks)"; f.field_type = "number"; f.data_class = "internal"
    end
    @custom = CustomField.where(entity: "person").index_by(&:key)
  end

  # ---------------------------------------------------------------- templates

  def seed_templates!
    C::MESSAGE_TEMPLATES.each do |t|
      locale = t[:locale] || "en"
      next if MessageTemplate.exists?(key: t[:key], locale: locale)
      tpl = MessageTemplate.create_template!(key: t[:key], message_type: t[:type], subject: t[:subject], body: t[:body] + C::SIGN_OFF, locale: locale)
      tpl.archive_template! if t[:archived]
      @summary["message_templates"] += 1
    end
    C::OFFER_TEMPLATES.each do |t|
      OfferTemplate.find_or_create_by!(key: t[:key]) { |o| o.name = t[:name]; o.body = t[:body]; o.expires_after_days = t[:expires] }
    end
    owner = @s.fetch(:recruiter)
    C::QUESTION_TEMPLATES.each do |name, questions|
      ApplicationQuestionTemplate.find_or_create_by!(name: name) { |q| q.owner = owner; q.questions = questions; q.status = "active" }
    end
    policy = ApprovalPolicy.find_by(key: "executive-offers") || ApprovalPolicy.create!(
      key: "executive-offers", name: "Executive offers (two-step)", applies_to: "offer", priority: 10,
      is_catch_all: false, conditions: { "job.dimensions.department" => "marketing" }
    )
    [ [ 1, "Hiring manager", "role:hiring-manager" ], [ 2, "People lead", "role:coordinator" ] ].each do |pos, name, approver|
      ApprovalPolicyStep.find_or_create_by!(approval_policy: policy, position: pos) do |s|
        s.name = name; s.mode = "sequential"; s.approvers = [ approver ]; s.require_mode = "all"
        s.if_no_approver = "fallback"; s.fallback_approver = "org-role:owner"
      end
    end
  end

  def seed_sequences!
    C::SEQUENCES.each do |s|
      if (existing = Sequence.find_by(key: s[:key]))
        existing.update!(status: s[:status], shared: s[:shared], name: s[:name], steps: s[:steps]) if existing.status != s[:status] || existing.shared != s[:shared]
      else
        Sequence.create!(key: s[:key], name: s[:name], steps: s[:steps], status: s[:status], shared: s[:shared], is_template: s[:template])
        @summary["sequences"] += 1
      end
    end
  end

  def seed_pipelines!
    @templates = {}
    C::PIPELINES.each do |sym, spec|
      template = PipelineTemplate.find_by(key: spec[:key]) || PipelineTemplate.create!(key: spec[:key], name: spec[:name], object_type: "job")
      spec[:versions].each { |stages| template.publish!(stages: stages) } if template.published_version.zero?
      @templates[sym] = template
    end
    @templates[:eng] = PipelineTemplate.find_by!(key: "bigbuck-engineering")
    @templates[:sales] = PipelineTemplate.find_by!(key: "bigbuck-sales")
  end

  # ---------------------------------------------------------------- requisitions & jobs

  def seed_requisitions_and_jobs!
    reqs = C::REQUISITIONS.to_h do |r|
      req = Requisition.find_by(code: r[:code]) || Requisition.create!(
        code: r[:code], title: r[:title], employment_type: r[:type], headcount: r[:headcount], status: r[:status],
        owner_user_id: (@s[r[:owner]] || @s[:owner]).id,
        approved_at: (@now - 40.days if %w[open approved filled closed].include?(r[:status])),
        closed_at: (@now - 6.days if %w[filled closed].include?(r[:status]))
      ).tap { @summary["requisitions"] += 1 }
      [ r[:code], req ]
    end
    req_by_job = C::REQUISITIONS.select { |r| r[:job] }.to_h { |r| [ r[:job], reqs.fetch(r[:code]) ] }
    # Link the two base jobs.
    { "Platform Engineer" => "REQ-1001", "Account Executive" => "REQ-1002" }.each do |title, code|
      job = Job.find_by!(title: title)
      job.update!(requisition: reqs.fetch(code), openings: reqs.fetch(code).headcount) unless job.requisition_id
    end
    question_templates = ApplicationQuestionTemplate.all.index_by(&:name)
    [ [ "Platform Engineer", "Engineering" ], [ "Account Executive", "Sales" ] ].each do |title, tpl|
      attach_question_template!(Posting.find_by!(job: Job.find_by!(title: title)), question_templates.fetch(tpl))
    end

    J::JOBS.each do |spec|
      job = Job.find_by(title: spec[:title])
      unless job
        pipeline = Pipeline.build_from_template!(template: @templates.fetch(spec[:pipeline]), overrides: spec[:overrides] || [])
        job = Job.create!(
          title: spec[:title], status: spec[:status] == "draft" ? "draft" : "active", pipeline: pipeline,
          careers_visibility: spec[:audience], confidential: !!spec[:confidential], code_name: spec[:code_name],
          openings: spec[:openings], requisition: req_by_job[spec[:title]]
        )
        @summary["jobs"] += 1
        EntityDimensionValue.create!(entity_type: "Job", entity_id: job.id, dimension: @dept_dim, dimension_value: @depts.fetch(spec[:dept]))
        unless spec[:no_posting]
          posting = Posting.create!(job: job, title: spec[:title], status: "draft",
                                    questions: spec[:posting_questions] || [])
          attach_question_template!(posting, question_templates.fetch(spec[:question_template])) if spec[:question_template]
          posting.update!(status: "published") if job.status == "active" && spec[:posting_status] != "draft"
          @summary["postings"] += 1
        end
        team = HiringTeam.create!(job: job)
        { hiring_manager: spec[:team][:hm], recruiter: spec[:team][:recruiter], coordinator: spec[:team][:coordinator] }.each do |role, key|
          HiringTeamMember.create!(hiring_team: team, user: @s.fetch(key), team_role: role.to_s.tr("_", "-"))
        end
        spec[:team][:interviewers].uniq.each do |key|
          user = @s.fetch(key)
          HiringTeamMember.create!(hiring_team: team, user: user, team_role: "interviewer") unless HiringTeamMember.exists?(hiring_team: team, user: user)
        end
      end
      @job_ctx[spec[:title]] = { spec: spec, job: job, roles_key: ROLE_KEY.fetch(spec[:family], spec[:family]) }
    end
  end

  def attach_question_template!(posting, template)
    return if posting.question_template_id
    posting.update!(question_template: template, template_questions: template.questions, template_version: template.version)
  end

  # ---------------------------------------------------------------- pools

  def seed_pools!
    sourcing = PipelineTemplate.find_by!(key: "sourcing-default")
    J::POOLS.each do |p|
      pool = Project.find_by(name: p[:name])
      unless pool
        pool = Project.create!(
          name: p[:name], pipeline: Pipeline.build_from_template!(template: sourcing, scope: "project"),
          job: p[:job] && @job_ctx.fetch(p[:job])[:job], confidential: !!p[:confidential]
        )
        @summary["pools"] += 1
      end
      @pools[p[:name]] = pool
    end
  end

  # ---------------------------------------------------------------- candidates

  def next_name
    loop do
      i = @name_i
      @name_i += 1
      first = C::FIRST[(i * 7) % C::FIRST.size]
      last = C::LAST[((i * 11) + (i / C::FIRST.size)) % C::LAST.size]
      name = "#{first} #{last}"
      next if @names.include?(name)
      @names << name
      return name
    end
  end

  def email_for(name, company_key: nil)
    base = name.downcase.gsub(/[^a-z ]/, "").tr(" ", ".")
    domain = if company_key && @companies[company_key]
      @companies.fetch(company_key).domain.sub(/\.example\z/, ".test")
    else
      EMAIL_DOMAINS[@emails.size % EMAIL_DOMAINS.size]
    end
    email = "#{base}@#{domain}"
    n = 1
    while @emails.include?(email)
      n += 1
      email = "#{base}#{n}@#{domain}"
    end
    @emails << email
    email
  end

  def next_phone
    # Dataset heroes already own 555-01xx; use 3xxx+ so enrich never collides with the base fixture.
    loop do
      @phone_i += 1
      phone = format("+1-%s-555-%04d", PHONE_AREAS[@phone_i % PHONE_AREAS.size], 3000 + @phone_i)
      key = PersonContactPoint.normalize_phone(phone)
      next if @phones.include?(key)

      @phones << key
      return phone
    end
  end

  # Person.source is a closed list (sourced/referral/applied/event/import/agent). Channel detail
  # (linkedin, careers, campus, …) belongs in source_detail and the custom field.
  def person_source_for(raw)
    detail = raw.to_s
    mapped = case detail
    when "referral" then "referral"
    when "careers", "applied" then "applied"
    when "event", "campus" then "event"
    when "import" then "import"
    when "agent" then "agent"
    else "sourced"
    end
    [ mapped, detail.presence || mapped ]
  end

  POSTING_BLURBS = {
    "engineering" => "You will own systems end to end: design them, ship them, and keep them honest in production. " \
                     "We work in small teams with short feedback loops, write things down, and review each other's code with care.",
    "design" => "You will shape how recruiters, hiring managers and candidates move through hiring. " \
                "Expect research, prototypes, and polished UI, with real users a message away.",
    "product" => "You will find the highest-leverage problems in hiring, set direction with design and engineering, " \
                 "and measure whether what we shipped actually helped.",
    "sales" => "You will run a full cycle with teams who hire for a living: discovery, demos, pricing and close. " \
               "You will have a clear territory, a strong product, and a team that shares what works.",
    "customer-success" => "You will be the person our customers call when hiring matters most. " \
                          "You will onboard new teams, run reviews, and turn what you hear into product changes.",
    "marketing" => "You will lead how the market hears about Big Buck: positioning, launches and demand, " \
                   "with a team that likes both craft and numbers.",
    "people" => "You will help Big Buck hire and grow the team, working closely with leadership on how we recruit, " \
                "onboard and develop people."
  }.freeze

  # Careers listings need a description, location and employment type (demo copy, invented).
  # Roles with careers copy (BigBuckDemo::Careers) get theirs in apply_careers_copy!.
  def seed_posting_details!
    Posting.includes(:job).where(description: nil).find_each do |posting|
      spec = J::JOBS.find { |row| row[:title] == posting.job.title } || {}
      dept = spec[:dept] || (posting.job.title.match?(/Account|Sales/) ? "sales" : "engineering")
      # The first listed location is the hub; "Remote" first means a remote role.
      first = Array(spec[:locations]).first
      location = first.nil? || first == "remote" ? "Remote — US" : location_meta(first)[:label]
      type = posting.job.title.match?(/Intern/) ? "internship" : "full_time"
      blurb = POSTING_BLURBS.fetch(dept, POSTING_BLURBS["engineering"])
      posting.update_columns(
        description: "#{posting.job.title} at Big Buck\n\n#{blurb}\n\nWhat you will do\n" \
                     "- Own meaningful work from the first week\n- Partner closely with the hiring team you meet in interviews\n" \
                     "- Help us build hiring software people actually like using\n",
        location: location, employment_type: type
      )
    end
  end

  def location_meta(key)
    BigBuckDataset::LOCATIONS.find { |l| l[:key] == key } || BigBuckDataset::LOCATIONS.last
  end

  # Builds a full candidate record (person, contact points, affiliation, resume, dimensions,
  # custom fields, notice receipt, consents). Returns the person; idempotent by email.
  def create_candidate!(name:, family:, years:, company:, title:, location:, source:, stage: "candidate", visibility: "public",
                        headline: nil, created_at: @now, department: nil, resume: true, email: nil)
    email ||= email_for(name, company_key: company)
    if (existing = Person.find_by(primary_email: PersonContactPoint.normalize_email(email)))
      return existing
    end
    loc = location_meta(location)
    phone = next_phone
    person_source, detail = person_source_for(source)
    person = Person.create!(
      display_name: name, primary_email: PersonContactPoint.normalize_email(email), primary_phone: PersonContactPoint.normalize_phone(phone),
      lifecycle_stage: stage, visibility: visibility, country: loc[:country], region: loc[:region], owner_user_id: @s.fetch(:recruiter).id,
      source: person_source, source_detail: detail, sourced_at: created_at, sourced_by_user_id: @s.fetch(:recruiter).id
    )
    slug = name.downcase.gsub(/[^a-z]+/, "-")
    PersonContactPoint.create!(person: person, kind: "email", value: email, primary: true, verified: @counter.even?)
    PersonContactPoint.create!(person: person, kind: "phone", value: phone, primary: true, verified: (@counter % 3).zero?)
    PersonContactPoint.create!(person: person, kind: "url", value: "https://linkedin.com/in/#{slug}", primary: false)
    company_row = @companies.fetch(company)
    prev_key = @company_keys[((@counter * 5) + 3) % @company_keys.size]
    prev_key = @company_keys[((@counter * 5) + 4) % @company_keys.size] if prev_key == company
    previous = @companies.fetch(prev_key)
    tenure_days = ([ years * 0.35, 0.8 ].max * 365).to_i
    PersonAffiliation.create!(person: person, company: company_row, title: title, current: stage != "alumni",
                              started_on: Date.current - tenure_days, ended_on: (stage == "alumni" ? Date.current - 5.months : nil))
    PersonAffiliation.create!(person: person, company: previous, title: C::FAMILIES.fetch(family)[:ladder].first, current: false,
                              started_on: Date.current - ((years + 1) * 365), ended_on: Date.current - tenure_days - 30)
    dept_key = department || { design: "design", product: "product", support: "customer-success", eng: "engineering", sales: "sales", leadership: "marketing", intern: "engineering" }[family]
    EntityDimensionValue.create!(entity_type: "Person", entity_id: person.id, dimension: @dept_dim, dimension_value: @depts.fetch(dept_key)) if @depts[dept_key]
    EntityDimensionValue.create!(entity_type: "Person", entity_id: person.id, dimension: @loc_dim, dimension_value: @loc_values.fetch(location)) if @loc_values[location]
    CustomFieldValue.create!(custom_field: @custom.fetch("source"), entity_type: "Person", entity_id: person.id, value_text: source.to_s)
    CustomFieldValue.create!(custom_field: @custom.fetch("years_experience"), entity_type: "Person", entity_id: person.id, value_number: years)
    CustomFieldValue.create!(custom_field: @custom.fetch("willing_to_relocate"), entity_type: "Person", entity_id: person.id, value_json: { "value" => @counter.even? })
    CustomFieldValue.create!(custom_field: @custom.fetch("work_authorization"), entity_type: "Person", entity_id: person.id, value_text: WORK_AUTH[(@counter / 2) % WORK_AUTH.size])
    CustomFieldValue.create!(custom_field: @custom.fetch("notice_period_weeks"), entity_type: "Person", entity_id: person.id, value_number: [ 0, 2, 4, 8, 4 ][@counter % 5])
    ip = "203.0.113.#{(@counter % 200) + 1}"
    NoticeReceipt.create!(person: person, notice_version: @privacy_version, shown_via: "apply_form", locale: "en", ip_address: ip,
                          user_agent: "BigBuckSeed/1.0", shown_at: created_at, created_at: created_at)
    Consent.create!(person: person, consent_purpose: @processing, notice_version: @privacy_version, lawful_basis: @processing.lawful_basis,
                    status: "granted", captured_via: "apply_form", captured_at: created_at, ip_address: ip, user_agent: "BigBuckSeed/1.0",
                    evidence_json: { "locale" => "en", "seed" => true }, created_at: created_at)
    Consent.create!(person: person, consent_purpose: @outreach, notice_version: @privacy_version, lawful_basis: @outreach.lawful_basis,
                    status: "granted", captured_via: "recorded_by_user", captured_at: created_at, created_at: created_at)
    if resume
      blocks = resume_blocks(person: person, title: title, company: company_row.name, location: loc[:label], years: years, family: family, headline: headline)
      attach_pdf!(person, "#{slug}-resume.pdf", BigBuckDemo::ResumePdf.render(blocks), at: created_at)
      extra_documents!(person, slug, family, title, years, created_at)
    end
    person.update_columns(created_at: created_at, updated_at: created_at)
    @counter += 1
    @summary["people"] += 1
    person
  end

  def extra_documents!(person, slug, family, title, years, at)
    case @counter % 9
    when 0
      attach_pdf!(person, "#{slug}-cover-letter.pdf", BigBuckDemo::ResumePdf.render([
        [ :name, person.display_name ], [ :headline, "Cover letter" ], [ :gap ],
        [ :text, "Dear Big Buck hiring team," ], [ :gap ],
        [ :text, "I am writing to apply for the #{title} work on your team. Over #{years} years I have focused on shipping work that customers notice, and I am drawn to the way Big Buck treats hiring as a craft." ], [ :gap ],
        [ :text, "I would welcome the chance to talk about how my experience maps to what you are building. Thank you for your time." ], [ :gap ], [ :text, "Warm regards," ], [ :text, person.display_name ]
      ]), at: at)
    when 4
      if family == :design
        attach_pdf!(person, "#{slug}-portfolio.pdf", BigBuckDemo::ResumePdf.render([
          [ :name, "#{person.display_name}: Portfolio" ], [ :headline, "Selected work" ], [ :gap ],
          [ :section, "CASE STUDY 1" ], [ :text, "Redesigned the primary workflow for a B2B product. Problem, approach, outcome: task completion up 31% and support tickets down by a third." ],
          [ :section, "CASE STUDY 2" ], [ :text, "Built a cross-platform component library from scratch and drove adoption across six squads." ],
          [ :section, "CASE STUDY 3" ], [ :text, "Led research and design for a mobile onboarding that doubled activation in two markets." ]
        ]), at: at)
      end
    when 7
      # An older, superseded resume shows the replace-resume history.
      attach_pdf!(person, "#{slug}-resume-2024.pdf", BigBuckDemo::ResumePdf.render(resume_blocks(person: person, title: title, company: "a previous employer", location: "", years: [ years - 2, 1 ].max, family: family, headline: nil)),
                  at: at - 6.months, superseded_at: at - 1.month)
    end
  end

  def attach_pdf!(person, filename, bytes, at: @now, superseded_at: nil, scan: "clean", document: nil)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: filename, content_type: "application/pdf", identify: false)
    doc = document || Document.new(person: person)
    doc.assign_attributes(filename: filename, content_type: "application/pdf", byte_size: bytes.bytesize, checksum: Digest::SHA256.hexdigest(bytes),
                          storage_key: blob.key, scan_status: scan, visibility: "internal", superseded_at: superseded_at)
    doc.save!
    doc.file.attach(blob)
    doc.update_columns(created_at: at, updated_at: at)
    @summary["documents"] += 1
    doc
  end

  def resume_blocks(person:, title:, company:, location:, years:, family:, headline:)
    fam = C::FAMILIES.fetch(RESUME_FAMILY.fetch(family, family))
    rng = Random.new(Zlib.crc32(person.primary_email.to_s))
    years = [ years.to_i, 1 ].max
    this_year = Date.current.year
    level = [ [ years / 4, 0 ].max, fam[:ladder].size - 1 ].min
    cur_from = this_year - [ (years * 0.35).ceil, 1 ].max
    mid_from = this_year - [ (years * 0.7).ceil, 2 ].max
    start_year = this_year - years
    other = ->(avoid) { (@company_keys - [ avoid ]).sample(random: rng).then { |k| @companies.fetch(k).name } }
    roles = [ [ title, company, "#{cur_from} - Present", 3 ] ]
    roles << [ fam[:ladder][[ level - 1, 0 ].max], other.call(nil), "#{mid_from} - #{cur_from}", 3 ] if years >= 3
    roles << [ fam[:ladder][[ level - 2, 0 ].max], other.call(nil), "#{start_year} - #{mid_from}", 2 ] if years >= 6
    bullets = fam[:bullets].shuffle(random: rng)
    take = ->(n) { bullets.shift([ n, bullets.size ].min).map { |b| b.gsub("%{n}") { rng.rand(2..9).to_s } } }
    tail = { design: "Comfortable moving between research, craft, and shipping alongside engineers.", eng: "Cares about reliability, clear ownership, and leaving systems better than found.",
             product: "Works from customer evidence and keeps roadmaps honest.", support: "Treats every renewal as a relationship worth earning.",
             sales: "Builds pipeline with curiosity and closes with a clear mutual plan.", leadership: "Builds teams and operating rhythms that outlast any one launch.",
             intern: "Eager learner who ships side projects and contributes to open source." }[RESUME_FAMILY.fetch(family, family)]
    summary = headline.presence || "#{title} with #{years} #{years == 1 ? 'year' : 'years'} of experience at companies like #{company}."
    blocks = [
      [ :name, person.display_name ],
      [ :headline, [ title, location.presence, person.primary_email, person.primary_phone ].compact.join("  ·  ") ],
      [ :gap ], [ :section, "SUMMARY" ], [ :text, "#{summary} #{tail}" ], [ :gap ], [ :section, "EXPERIENCE" ]
    ]
    roles.each do |role_title, co, span, n|
      blocks << [ :role, "#{role_title}, #{co}", span ]
      take.call(n).each { |b| blocks << [ :bullet, b ] }
      blocks << [ :gap ]
    end
    blocks << [ :section, "SKILLS" ]
    blocks << [ :text, fam[:skills].shuffle(random: rng).first(7).join("  ·  ") ]
    blocks << [ :gap ]
    blocks << [ :section, "EDUCATION" ]
    blocks << [ :role, C::SCHOOLS.sample(random: rng), (start_year - rng.rand(0..1)).to_s ]
    blocks << [ :text, C::DEGREES.sample(random: rng) ]
    blocks
  end

  # ---------------------------------------------------------------- funnels

  def seed_funnels!
    J::JOBS.each do |spec|
      ctx = @job_ctx.fetch(spec[:title])
      job = ctx[:job]
      # Idempotent: hero names mark a funnel as already applied. Base PE/AE already have apps, so
      # Application.exists? alone would skip the careers flagships forever.
      heroes = spec[:funnel].filter_map { |row| row[:hero] }
      if heroes.any?
        next if Person.where(display_name: heroes).exists?
      elsif Application.exists?(job_id: job.id)
        next
      end
      ctx[:rows_seen] = 0
      spec[:funnel].each do |row|
        row[:count].times do |i|
          place_candidate!(ctx, row, i)
        end
      end
      finalize_job!(ctx)
    end
  end

  def finalize_job!(ctx)
    spec = ctx[:spec]
    job = ctx[:job]
    return if spec[:status] == job.status || spec[:status] == "draft"
    posting_status = spec[:close_after] ? "archived" : nil
    job.update!(status: spec[:status])
    Posting.where(job_id: job.id).update_all(status: posting_status) if posting_status
    Requisition.find_by(id: job.requisition_id)&.update_columns(updated_at: @now - 6.days)
  end

  # Builds one application end to end for a funnel row.
  def place_candidate!(ctx, row, index)
    spec = ctx[:spec]
    job = ctx[:job]
    stage = row[:stage]
    strength = row[:strength]
    idx = (@counter += 1)

    stages = job.pipeline.resolved_stages
    target_idx = stages.index { |s| s["key"] == stage } || raise("unknown stage #{stage} for #{spec[:title]}")
    phase = row[:phase]
    offset = phase_offset(phase, idx)
    entries = stage_entries(stages, target_idx, offset)
    applied_at = entries.first

    person, source = candidate_for!(ctx, row, idx, applied_at)
    first = person.display_name.split.first
    company = person_company_name(person)
    title = person_title(person)

    # Sourced candidates: pool member -> conversion; everyone else applies directly.
    app = nil
    if row[:via_pool]
      pool = @pools.fetch(row[:via_pool])
      member = seed_project_member!(pool, person, "replied")
      enroll_in_sequence!(person, "engineering-cold", steps_forward: 2, stop: "replied", at: applied_at - 9.days) if pool
      app = ProjectConversion.call(member: member, job: job)
      seed_sourcing_activity!(person, pool, { pool_stage: "replied" }, applied_at - 8.days)
    else
      app = ApplicationCreator.call(job: job, person: person)
    end
    attach_posting_answers!(app, ctx, source, idx)
    record_timeline!(person, "application.submitted", {
      "application_id" => app.id, "job_title" => job.title, "source" => source,
      "summary" => "#{person.display_name} applied for #{job.title} via #{source.to_s.tr('_', ' ')}."
    }, applied_at)
    send_comm!(person, "application-received", at: applied_at + 6.minutes, type: "confirmation") if source.to_s == "careers" || idx.even?

    last_event = applied_at
    (0...target_idx).each do |k|
      s = stages[k]
      complete_stage_interviews!(app, ctx, s, entries[k], person, strength, final: false, idx: idx, company: company, title: title)
      nxt = stages[k + 1]
      SubjectTransitions.move(subject: app, to_stage_key: nxt["key"], reason: move_reason(s, nxt))
      app.reload
      stamp_last_transition!(app, entries[k + 1])
      record_timeline!(person, "application.moved", {
        "application_id" => app.id, "from" => s["key"], "to" => nxt["key"], "status" => "active",
        "summary" => "#{first} moved from #{s['name']} to #{nxt['name']} for #{job.title}."
      }, entries[k + 1])
      send_comm!(person, "phone-screen-request", at: entries[k + 1] + 1.hour, type: "scheduling", reply: (idx % 3 != 0)) if nxt["key"] == "screen"
      last_event = entries[k + 1]
    end

    target = stages[target_idx]
    if Array(target["interviews"]).any? && phase != :none
      # No earlier stage had interviews: this stage's first round is the recruiter screen.
      first_loop = stages[0...target_idx].none? { |st| Array(st["interviews"]).any? }
      last_event = run_stage_interviews!(app, ctx, target, phase, entries[target_idx], person, strength, idx: idx, company: company, title: title,
                                         first_loop: first_loop)
    end

    if stage == "offer" || target["type"] == "offer"
      last_event = place_offer!(app, ctx, row, person, entries[target_idx], idx)
    end

    apply_final_status!(app, ctx, row, person, last_event, phase)
    app.reload
    app.update_columns(created_at: applied_at, updated_at: [ last_event, applied_at ].max)
    add_notes!(person, row, ctx, [ applied_at + 1.day, last_event ].min)
    maybe_referral_note!(person, row, ctx, app)
    @summary["applications"] += 1
  end

  def phase_offset(phase, idx)
    days = case phase
    when :none then 0.5 + ((idx % 7) * 0.6)
    when :requested then 1 + (idx % 3)
    when :scheduled then 1.5 + (idx % 3)
    when :partial then 4 + (idx % 3)
    when :awaiting_feedback then 5 + (idx % 4)
    when :attention then 4 + (idx % 2)
    else 7 + (idx % 6)
    end
    days.days
  end

  def stage_span(stage)
    n = Array(stage["interviews"]).size
    (n.zero? ? 2 : 2 + n) + 1
  end

  # Entry time per stage; the target stage is entered `offset` ago and earlier stages are spaced back from it.
  def stage_entries(stages, target_idx, offset)
    entries = Array.new(target_idx + 1)
    entries[target_idx] = @now - offset
    (target_idx - 1).downto(0) { |k| entries[k] = entries[k + 1] - stage_span(stages[k]).days }
    entries
  end

  # Interview hours are stored in UTC but read in the viewer's zone. 16:00-21:00 UTC is
  # 11am-4pm Eastern / 8am-1pm Pacific, so nothing shows up at dawn for a US audience.
  def biz_hour(n) = 16 + (n % 6)

  def past_workday(time) = workday(time, direction: -1)

  def workday(time, direction: 1)
    time += direction.days while time.saturday? || time.sunday?
    time
  end

  def complete_stage_interviews!(app, ctx, stage, entry, person, strength, final:, idx:, company:, title:)
    Array(stage["interviews"]).each_with_index do |iv, j|
      starts = workday((entry + (1 + j).days).change(hour: biz_hour(idx + j), min: (j.even? ? 0 : 30)))
      starts = past_workday((@now - 1.day).change(hour: biz_hour(idx + j), min: 0)) if starts > @now - 2.hours
      build_completed_interview!(app, ctx, stage, iv, starts, person, strength, final: final, idx: idx, j: j, company: company, title: title)
    end
  end

  def run_stage_interviews!(app, ctx, stage, phase, entry, person, strength, idx:, company:, title:, first_loop: false)
    ivs = Array(stage["interviews"])
    last = entry
    # A loop that opens with the screen (engineering and sales Onsite) books rounds in order: nobody
    # has the later rounds on the calendar before the screen, and past the screen there is feedback.
    if first_loop && ivs.size > 1 && %i[requested scheduled].include?(phase)
      return run_loop_opening!(app, ctx, stage, phase, ivs, entry, person, strength, idx: idx, company: company, title: title)
    end
    case phase
    when :requested
      ivs.each { |iv| create_interview!(app, stage, iv, ctx, status: "requested", starts: nil) }
      SchedulingLink.create!(application: app, kind: "self_schedule", interview_keys: ivs.map { |i| i["key"] }, expires_at: @now + 10.days)
      record_timeline!(person, "interview.requested", { "summary" => "Asked #{person.display_name.split.first} to pick times for #{ivs.map { |i| i['name'] }.to_sentence.downcase}." }, entry + 4.hours)
      send_comm!(person, "phone-screen-request", at: entry + 4.hours, type: "scheduling") if stage["key"] != "screen"
      last = entry + 4.hours
    when :scheduled
      ivs.each_with_index { |iv, j| schedule_upcoming!(app, stage, iv, ctx, person, idx + j, j) }
      send_comm!(person, "interview-invite", at: entry + 6.hours, type: "scheduling", reply: idx.even?)
      last = entry + 6.hours
    when :partial
      done = ivs.size > 1 ? ivs[0...-1] : []
      done.each_with_index do |iv, j|
        starts = workday((entry + (1 + j).days).change(hour: biz_hour(idx + j), min: 0))
        starts = past_workday((@now - (done.size - j).days).change(hour: biz_hour(idx + j), min: 0)) if starts > @now - 3.hours
        build_completed_interview!(app, ctx, stage, iv, starts, person, strength, final: true, idx: idx, j: j, company: company, title: title)
        last = starts
      end
      schedule_upcoming!(app, stage, ivs.last, ctx, person, idx, done.size)
      send_comm!(person, "interview-invite", at: entry + 5.hours, type: "scheduling")
      send_comm!(person, "interview-prep", at: entry + 1.day, type: "interview_prep") if ivs.size > 1
    when :awaiting_feedback
      ivs.each_with_index do |iv, j|
        starts = workday((entry + (1 + j).days).change(hour: biz_hour(idx + j), min: 0))
        starts = past_workday((@now - 2.days).change(hour: biz_hour(idx + j), min: 0)) if starts > @now - 3.hours
        owed = j == ivs.size - 1
        build_completed_interview!(app, ctx, stage, iv, starts, person, strength, final: true, idx: idx, j: j, company: company, title: title, owed: owed)
        last = starts
      end
    when :attention
      ivs.each_with_index do |iv, j|
        if j.zero? && ivs.size > 1
          starts = workday((entry + 1.day).change(hour: biz_hour(idx + 1), min: 0))
          starts = past_workday((@now - 2.days).change(hour: biz_hour(idx + 1), min: 0)) if starts > @now - 3.hours
          build_completed_interview!(app, ctx, stage, iv, starts, person, strength, final: true, idx: idx, j: j, company: company, title: title)
          last = starts
        elsif j == 1 || ivs.size == 1
          users = step_users(ctx, iv["key"])
          starts = workday((@now + (2 + idx % 3).days).change(hour: biz_hour(idx), min: 0))
          create_interview!(app, stage, iv, ctx, status: "needs_attention", starts: starts, users: users,
                            reason: "decline_no_replacement")
        else
          create_interview!(app, stage, iv, ctx, status: "requested", starts: nil)
        end
      end
    when :complete
      ivs.each_with_index do |iv, j|
        starts = workday((entry + (1 + j).days).change(hour: biz_hour(idx + j), min: 0))
        starts = past_workday((@now - 1.day).change(hour: biz_hour(idx + j), min: 0)) if starts > @now - 2.hours
        build_completed_interview!(app, ctx, stage, iv, starts, person, strength, final: true, idx: idx, j: j, company: company, title: title)
        last = starts
      end
    end
    last
  end

  # :requested -> screen booked, the rest waiting on the candidate's times; no feedback yet.
  # :scheduled -> screen done with feedback, the next round booked, the rest not scheduled.
  def run_loop_opening!(app, ctx, stage, phase, ivs, entry, person, strength, idx:, company:, title:)
    if phase == :requested
      schedule_upcoming!(app, stage, ivs.first, ctx, person, idx, 0)
      rest = ivs.drop(1)
      rest.each { |iv| create_interview!(app, stage, iv, ctx, status: "requested", starts: nil) }
      SchedulingLink.create!(application: app, kind: "self_schedule", interview_keys: rest.map { |i| i["key"] }, expires_at: @now + 10.days)
      send_comm!(person, "interview-invite", at: entry + 4.hours, type: "scheduling")
      return entry + 4.hours
    end
    starts = workday((entry + 1.day).change(hour: biz_hour(idx), min: 0))
    starts = past_workday((@now - 1.day).change(hour: biz_hour(idx), min: 0)) if starts > @now - 3.hours
    build_completed_interview!(app, ctx, stage, ivs.first, starts, person, strength, final: true, idx: idx, j: 0, company: company, title: title)
    schedule_upcoming!(app, stage, ivs[1], ctx, person, idx, 1)
    send_comm!(person, "interview-invite", at: starts + 5.hours, type: "scheduling")
    starts
  end

  def step_users(ctx, key)
    roles = C::ROLES.fetch(ctx[:roles_key], {})[key] || %i[recruiter]
    roles.map { |r| @s.fetch(r) }.uniq
  end

  def create_interview!(app, stage, iv, ctx, status:, starts:, users: nil, reason: nil)
    users ||= step_users(ctx, iv["key"])
    meta = C::STEPS[iv["key"]] || BigBuckDataset::ENG_LOOP.find { |s| s[:key] == iv["key"] } || { minutes: 45 }
    minutes = meta[:minutes] || 45
    pool = InterviewerPool.find_by(key: { design: "design-panel", product: "product-panel", support: "cs-panel", eng: "eng-panel", sales: "sales-panel" }[ctx[:roles_key]] || "none")
    Interview.create!(
      application: app, stage_key: stage["key"], interview_key: iv["key"], status: status,
      starts_at: starts, ends_at: (starts + minutes.minutes if starts), interviewer_user_ids: users.map(&:id),
      calendar_event_id: (status == "scheduled" ? "evt_#{SecureRandom.hex(8)}" : nil), interviewer_pool_id: pool&.id,
      needs_attention_reason: reason
    ).tap do |interview|
      created = starts ? starts - 3.days : @now - 1.day
      interview.update_columns(created_at: [ created, @now ].min, updated_at: [ (starts || @now), @now ].min)
      @summary["interviews"] += 1
    end
  end

  def schedule_upcoming!(app, stage, iv, ctx, person, seed, j)
    day = (seed % 7) + j
    starts = (@now + day.days).change(hour: biz_hour(seed), min: (seed.even? ? 0 : 30))
    starts += 1.day while starts <= @now + 2.hours
    starts = workday(starts)
    interview = create_interview!(app, stage, iv, ctx, status: "scheduled", starts: starts)
    record_timeline!(person, "interview.scheduled", {
      "interview_key" => iv["key"], "interview_name" => iv["name"],
      "summary" => "#{iv['name']} booked for #{starts.strftime('%a %b %-d at %-l:%M %p')} with #{step_users(ctx, iv['key']).map(&:name).to_sentence}."
    }, @now - (1 + j).hours)
    interview
  end

  def build_completed_interview!(app, ctx, stage, iv, starts, person, strength, final:, idx:, j:, company:, title:, owed: false)
    users = step_users(ctx, iv["key"])
    # Someone still owes feedback only on a panel; a one-person interview that is done has its scorecard.
    owed &&= users.size > 1
    interview = create_interview!(app, stage, iv, ctx, status: "completed", starts: starts, users: users)
    roles = C::ROLES.fetch(ctx[:roles_key], {})[iv["key"]] || %i[recruiter]
    rubric_key = iv["rubric_key"] || (C::STEPS[iv["key"]] || {})[:rubric]
    users.each_with_index do |user, u|
      if owed && u == users.size - 1
        # Feedback owed: the interviewer has not submitted; every other time leave a started draft.
        Scorecard.create!(interview: interview, user: user, status: "draft", notes: "Started notes, not submitted yet.") if idx.odd?
        next
      end
      rating = rating_for(strength, idx + j, final)
      rating = RATING_NEIGHBOR.fetch(rating) if u.odd?
      ScorecardSubmitter.call(
        interview: interview, user: user, rating: rating, notes: demo_note(iv, person, company, title, rating, roles[u] || roles.first, user),
        attribute_ratings: demo_attribute_ratings(rubric_key, rating, u)
      )
    end
    Scorecard.where(interview_id: interview.id).update_all(created_at: starts + (iv_minutes(iv) + 90).minutes, updated_at: starts + (iv_minutes(iv) + 90).minutes)
    record_timeline!(person, "interview.completed", {
      "interview_key" => iv["key"], "interview_name" => iv["name"], "job_title" => ctx[:job].title,
      "summary" => "#{person.display_name.split.first}'s #{iv['name'].downcase} for #{ctx[:job].title} is in#{owed ? ', waiting on one scorecard' : ", with scorecards from #{users.map(&:name).to_sentence}"}."
    }, starts + iv_minutes(iv).minutes)
    interview
  end

  def iv_minutes(iv)
    (C::STEPS[iv["key"]] || BigBuckDataset::ENG_LOOP.find { |s| s[:key] == iv["key"] } || { minutes: 45 })[:minutes]
  end

  def rating_for(strength, i, final)
    s = final ? strength : (%i[weak mixed].include?(strength) ? :solid : strength)
    RATING_SEQ.fetch(s)[i % 3]
  end

  def demo_note(iv, person, company, title, rating, role, user)
    meta = C::STEPS[iv["key"]]
    key = meta ? meta[:note] : (BigBuckDataset::ENG_LOOP.find { |s| s[:key] == iv["key"] } || {})[:note_key] || "screen"
    set = C::NOTES[key] || BigBuckDataset::SCORECARD_NOTES.fetch(key)
    body = set.fetch(rating).gsub("%{name}", person.display_name.split.first).gsub("%{company}", company).gsub("%{title}", title.to_s)
    focus = C::FOCUS[role] || BigBuckDataset::INTERVIEWER_FOCUS[role]
    [ body, focus ].compact.join(" ")
  end

  def demo_attribute_ratings(rubric_key, rating, user_index)
    return nil if rubric_key.blank?
    score = BigBuckDataset::RATING_SCORE.fetch(rating)
    keys = ScorecardRubric.find_by!(key: rubric_key).required_keys
    keys.each_with_index.to_h { |k, i| [ k, [ score + (rating == "mixed" && i == user_index % 2 ? -1 : 0), 1 ].max ] }
  end

  def move_reason(from, to)
    Array(from["interviews"]).any? ? "#{from['name']} complete, panel advanced" : "Advanced after review"
  end

  def stamp_last_transition!(app, at)
    t = StageTransition.where(subject_type: "Application", subject_id: app.id).order(:created_at).last
    t&.update_columns(created_at: at, updated_at: at)
  end

  def apply_final_status!(app, ctx, row, person, last_event, phase)
    first = person.display_name.split.first
    status = row[:status]
    offer = Offer.where(application_id: app.id).order(:created_at).last
    case status
    when "rejected"
      reason = C::REJECTION_REASONS[(@counter % C::REJECTION_REASONS.size)]
      SubjectTransitions.reject(subject: app, reason: reason)
      at = last_event + 1.day
      at = [ at, @now - 2.hours ].min
      stamp_last_transition!(app, at)
      record_timeline!(person, "application.rejected", { "application_id" => app.id, "summary" => "#{first} was rejected for #{ctx[:job].title}: #{reason.downcase}." }, at)
      later = Array(app.pipeline.resolved_stages).index { |s| s["key"] == app.current_stage_key }.to_i >= 2
      send_comm!(person, later ? "rejection-after-onsite" : (app.current_stage_key == "applied" ? "rejection-application" : "rejection-after-screen"), at: at + 3.hours, type: "rejection")
    when "withdrawn"
      SubjectTransitions.withdraw(subject: app, reason: "Candidate withdrew")
      at = [ last_event + 1.day, @now - 3.hours ].min
      stamp_last_transition!(app, at)
      record_timeline!(person, "application.withdrawn", { "application_id" => app.id, "summary" => "#{first} withdrew from #{ctx[:job].title}." }, at)
    when "hired"
      SubjectTransitions.hire(subject: app)
      at = [ last_event + 2.days, @now - 1.day ].min
      stamp_last_transition!(app, at)
      record_timeline!(person, "application.hired", { "application_id" => app.id, "summary" => "#{person.display_name} was hired as #{ctx[:job].title}." }, at)
      Person.where(id: person.id).update_all(lifecycle_stage: "employee") unless ctx[:spec][:confidential]
    end
    if offer&.status == "declined" && app.reload.status == "active"
      SubjectTransitions.withdraw(subject: app, reason: "Declined the offer for a competing role")
      stamp_last_transition!(app, last_event + 1.day)
    end
  end

  # ---------------------------------------------------------------- offers

  def place_offer!(app, ctx, row, person, entry, idx)
    status = row[:offer] || "draft"
    lo, hi = ctx[:spec][:salary]
    base = ((lo + ((hi - lo) * (0.35 + ((idx % 6) * 0.1)))) / 1000.0).round * 1000
    equity = ctx[:spec][:family] == :intern ? nil : format("%.2f%%", 0.03 + ((idx % 9) / 100.0))
    fields = { "base_salary" => base, "currency" => "USD", "start_date" => (Date.current + 21 + (idx % 30)).iso8601 }
    fields["equity"] = equity if equity
    fields["signing_bonus"] = 10_000 + ((idx % 4) * 2_500) if base > 120_000 && idx.odd?
    at = entry + 6.hours
    at = [ at, @now - 2.hours ].min
    offer = OfferSubmitter.create_draft!(application: app, fields: fields)
    approver = @s.fetch(ctx[:spec][:team][:hm])
    offer = advance_offer!(offer, status, application: app, approver: approver)
    seed_offer_activity!(person, offer, ctx[:job], at + 1.day)
    backdate_offer!(offer, at)
    send_comm!(person, "offer-followup", at: [ at + 4.days, @now - 1.hour ].min, type: "offer") if status == "sent" && idx.even?
    @summary["offers"] += 1
    at + 1.day
  end

  def backdate_offer!(offer, at)
    versions = OfferVersion.unscoped.where(offer_id: offer.id)
    Offer.unscoped.where(id: offer.id).update_all(created_at: at, updated_at: at + 2.days)
    versions.each do |v|
      v.update_columns(created_at: at, updated_at: at + 2.days, sent_at: (v.sent_at ? at + 1.day : nil))
      SignatureRequest.unscoped.where(offer_version_id: v.id).update_all(created_at: at + 1.day)
      OfferDocument.unscoped.where(offer_version_id: v.id).update_all(created_at: at + 1.day)
      OfferResponse.unscoped.where(offer_version_id: v.id).update_all(created_at: at + 3.days)
    end
    Approval.unscoped.where(entity_type: "Offer", entity_id: offer.id).find_each do |a|
      a.update_columns(requested_at: at + 1.hour, approved_at: (a.approved_at ? at + 1.day : nil), created_at: at + 1.hour)
    end
  end

  # ---------------------------------------------------------------- candidate source

  def candidate_for!(ctx, row, idx, applied_at)
    spec = ctx[:spec]
    source = row[:source] || %w[careers linkedin referral agency outbound campus][idx % 6]
    if row[:existing] == "employee"
      person = Person.where(lifecycle_stage: "employee").where.not(id: Application.unscoped.select(:person_id)).order(:created_at).first!
      return [ person, "internal" ]
    end
    name = row[:hero] || next_name
    family = RESUME_FAMILY.fetch(spec[:family], spec[:family])
    range = { sdr: 0..3, intern: 0..1, leadership: 12..20 }[spec[:family]] || { design: 3..11, product: 4..12, support: 2..8 }.fetch(family, 3..12)
    years = row[:years] || @rng.rand(range)
    fam = C::FAMILIES.fetch(family)
    level = [ [ years / 4, 0 ].max, fam[:ladder].size - 1 ].min
    title = row[:title] || fam[:ladder][level]
    company = row[:company] || @company_keys[(idx * 3 + years) % @company_keys.size]
    location = row[:location] || spec[:locations][idx % spec[:locations].size]
    visibility = (!row[:hero] && (idx % 23).zero?) ? "restricted" : "public"
    person = create_candidate!(name: name, family: family, years: years, company: company, title: title, location: location, source: source,
                               headline: row[:headline], created_at: applied_at, visibility: visibility)
    [ person, source ]
  end

  def person_company_name(person)
    PersonAffiliation.where(person_id: person.id, current: true).order(:started_on).last&.company&.name || "their last team"
  end

  def person_title(person)
    PersonAffiliation.where(person_id: person.id, current: true).order(:started_on).last&.title || "the role"
  end

  def attach_posting_answers!(app, ctx, source, idx)
    posting = Posting.find_by(job_id: ctx[:job].id, status: %w[published archived])
    return unless posting && source.to_s == "careers"
    defs = PostingQuestions.definitions(posting)
    return if defs.empty?
    answers = defs.each_with_object({}) do |q, h|
      h[q["key"]] = case q["field_type"]
      when "select" then q["options"][idx % q["options"].size]
      when "multi_select" then q["options"].first(2)
      when "number" then (1 + (idx % 6)).to_f
      when "url" then "https://example.net/#{app.id[0, 6]}"
      when "boolean" then idx.even?
      else [ "Rebuilding a core workflow while keeping the old one running for customers.", "Around four weeks, depending on my current project.", "Open to the posted range." ][idx % 3]
      end
    end
    app.update!(posting: posting, application_form_snapshot: defs, application_answers: answers)
  end

  def add_notes!(person, row, ctx, at)
    Array(row[:notes]).each_with_index do |(who, body), i|
      user = @s.fetch(who)
      write_note!(person, user, body, [ at + i.hours, @now - 1.hour ].min)
    end
  end

  def maybe_referral_note!(person, row, ctx, app)
    return unless row[:referrer]
    @referral_queue ||= []
    @referral_queue << [ person, app, @s.fetch(row[:referrer]), ctx[:job] ]
  end

  # ---------------------------------------------------------------- comms

  def send_comm!(person, template_key, at:, type:, reply: false)
    return if person.do_not_contact
    tpl = MessageTemplate.find_by(key: template_key, locale: "en") || return
    tokens = { "person.display_name" => person.display_name.split.first, "person.email" => person.primary_email }
    comm = MessageSender.send_now!(
      mailbox: @mailbox, person: person, subject: MessageRenderer.render(tpl.subject, tokens),
      body: MessageRenderer.render(tpl.body, tokens), message_type: type
    )
    at = [ at, @now - 1.minute ].min
    backdate_comm!(comm, at)
    if reply
      first = person.display_name.split.first
      text = [ "Thanks #{first}, that works for me. Looking forward to it.", "Great, thank you. Tuesday afternoon would suit me best if that is possible.", "Thanks for the update. I have a couple of questions about the team, happy to ask on the call." ][@counter % 3]
      inbound = Communication.create!(person: person, mailbox: @mailbox, direction: "inbound", channel: "email", subject: "Re: #{comm.subject}", body: text,
                                      provider_message_id: "seed-in-#{SecureRandom.hex(6)}", thread_id: comm.thread_id, message_type: "reply", status: "received")
      inbound.update_columns(created_at: at + 3.hours, updated_at: at + 3.hours)
      record_timeline!(person, "communication.received", { "id" => inbound.id, "direction" => "inbound", "subject" => inbound.subject, "summary" => "#{person.display_name.split.first} replied: #{text.truncate(80)}" }, at + 3.hours)
      @summary["replies"] += 1
    end
    @summary["emails"] += 1
    comm
  end

  def backdate_comm!(comm, at)
    comm.update_columns(created_at: at, updated_at: at)
    TimelineEvent.where(person_id: comm.person_id, event_type: "communication.sent").order(:created_at).last&.update_columns(occurred_at: at, created_at: at, updated_at: at)
  end

  # ---------------------------------------------------------------- sourcing

  def enroll_in_sequence!(person, key, steps_forward:, stop: nil, at:)
    sequence = Sequence.find_by!(key: key)
    return if SequenceEnrollment.exists?(sequence_id: sequence.id, person_id: person.id)
    # Restricted or confidential profiles are not put in shared outreach; most members could not even
    # see who the enrollee is, and the sequence would list an anonymous row.
    return unless person.visibility == "public"
    enrollment = SequenceRunner.enroll!(sequence: sequence, person: person, mailbox: @mailbox)
    steps_forward.times do
      break unless enrollment.reload.active? && enrollment.next_run_at
      enrollment.update!(next_run_at: @now - 1.minute)
      SequenceRunner.advance!(enrollment.reload)
    end
    comms = Communication.where(sequence_enrollment_id: enrollment.id).order(:created_at).to_a
    comms.each_with_index do |c, i|
      t = at + (i * 3).days
      t = [ t, @now - (2 + i).hours ].min
      backdate_comm!(c, t)
      ScheduledMessage.where(communication_id: c.id).update_all(sent_at: t, updated_at: t)
    end
    enrollment.reload
    if stop == "replied"
      enrollment.stop!("replied")
      t = (comms.last&.created_at || at) + 5.hours
      reply = Communication.create!(person: person, mailbox: @mailbox, direction: "inbound", channel: "email", subject: "Re: #{comms.last&.subject}",
                                    body: sequence_reply_text(person),
                                    provider_message_id: "seed-in-#{SecureRandom.hex(6)}", thread_id: comms.last&.thread_id, message_type: "reply", status: "received",
                                    sequence_enrollment_id: enrollment.id)
      reply.update_columns(created_at: t, updated_at: t)
      record_timeline!(person, "communication.received", { "id" => reply.id, "direction" => "inbound", "subject" => reply.subject, "summary" => "#{person.display_name.split.first} replied: #{reply.body.truncate(80)}" }, t)
      enrollment.update_columns(next_run_at: nil)
      @summary["replies"] += 1
    else
      enrollment.update_columns(next_run_at: [ enrollment.next_run_at, @now + 3.hours ].max) if enrollment.next_run_at
    end
    enrollment.update_columns(created_at: at, updated_at: @now - 1.hour)
    @summary["enrollments"] += 1
    enrollment
  end

  def seed_pool_conversions_and_outreach!
    stages = %w[prospect reached-out replied ready reached-out prospect replied reached-out]
    J::POOLS.each do |p|
      next unless p[:family]
      pool = @pools.fetch(p[:name])
      existing = ProjectMember.where(project_id: pool.id).count
      need = p[:members] - existing
      next if need <= 0
      job = p[:job] && @job_ctx.fetch(p[:job])
      family = p[:family]
      need.times do |i|
        name = next_name
        loc = (job ? job[:spec][:locations] : %w[sf nyc remote])[i % 3]
        fam = C::FAMILIES.fetch(family)
        years = family == :intern ? 0 : @rng.rand(4..12)
        years = 1 if family == :intern
        title = fam[:ladder][[ [ years / 4, 0 ].max, fam[:ladder].size - 1 ].min]
        person = create_candidate!(name: name, family: family, years: years, company: @company_keys[(@counter * 3) % @company_keys.size], title: title,
                                   location: loc, source: (family == :intern ? "campus" : "outbound"), stage: "prospect",
                                   created_at: @now - (25 + (i * 2)).days)
        stage = stages[i % stages.size]
        member = seed_project_member!(pool, person, stage)
        seed_sourcing_activity!(person, pool, { pool_stage: stage }, @now - (22 + i).days)
        ProjectMember.where(id: member.id).update_all(created_at: @now - (22 + i).days, updated_at: @now - (3 + i).days)
        next unless p[:sequence] && %w[reached-out replied].include?(stage)
        enroll_in_sequence!(person, p[:sequence], steps_forward: (stage == "replied" ? 2 : i % 3), stop: (stage == "replied" ? "replied" : nil), at: @now - (18 + i).days)
      end
    end
  end

  def seed_silver_medalists_and_alumni!
    silver = @pools.fetch("Silver medalists")
    stages = %w[ready replied prospect ready reached-out replied ready prospect]
    # Ordered by id (UUIDv7, time-sortable and unaffected by backdating) and skipped once populated.
    candidates = ProjectMember.exists?(project_id: silver.id) ? [] : Application.where(status: "rejected").where.not(current_stage_key: %w[applied]).order(:id).limit(8).to_a
    candidates.each_with_index do |app, i|
      next if ProjectMember.exists?(project_id: silver.id, person_id: app.person_id)
      member = seed_project_member!(silver, app.person, stages[i % stages.size])
      seed_sourcing_activity!(app.person, silver, { pool_stage: stages[i % stages.size] }, @now - (10 + i).days)
      if i < 3
        begin
          enroll_in_sequence!(app.person, "silver-medalists", steps_forward: 1, at: @now - (8 + i).days)
        rescue ArgumentError => e
          Rails.logger.warn("silver enrollment skipped: #{e.message}")
        end
      end
      ProjectMember.where(id: member.id).update_all(created_at: @now - (10 + i).days)
    end
    alumni = @pools.fetch("Boomerangs & alumni")
    unless ProjectMember.exists?(project_id: alumni.id)
      Person.where(lifecycle_stage: "alumni").order(:id).limit(14).each_with_index do |person, i|
        next if ProjectMember.exists?(project_id: alumni.id, person_id: person.id)
        stage = %w[prospect reached-out prospect ready][i % 4]
        seed_project_member!(alumni, person, stage)
        seed_sourcing_activity!(person, alumni, { pool_stage: stage }, @now - (14 + i).days)
      end
    end
    ProjectMember.where(project_id: alumni.id, status: "active").order(:id).limit(10).each_with_index do |member, i|
      next if SequenceEnrollment.exists?(person_id: member.person_id, sequence_id: Sequence.find_by(key: "alumni-boomerang")&.id)
      begin
        enroll_in_sequence!(member.person, "alumni-boomerang",
                            steps_forward: (i % 3), stop: (i.even? ? "replied" : nil), at: @now - (9 + i).days)
      rescue ArgumentError => e
        Rails.logger.warn("alumni enrollment skipped: #{e.message}")
      end
    end
  end

  # The base pools have members at reached-out/replied but no outreach behind them.
  def seed_base_pool_outreach!
    { "Platform warm bench" => "engineering-cold", "AE talent pool" => "default-outreach" }.each do |pool_name, sequence|
      pool = Project.find_by(name: pool_name) or next
      ProjectMember.where(project_id: pool.id, current_stage_key: %w[reached-out replied], status: "active").order(:id).limit(6).each_with_index do |member, i|
        replied = member.current_stage_key == "replied"
        begin
          enroll_in_sequence!(member.person, sequence, steps_forward: (replied ? 1 : 0), stop: (replied ? "replied" : nil), at: @now - (12 + (i * 2)).days)
        rescue ArgumentError => e
          Rails.logger.warn("base pool enrollment skipped: #{e.message}")
        end
      end
    end
  end

  def seed_tasks!
    assignees = [ @s.fetch(:sourcer), @s.fetch(:recruiter) ]
    SourcingTask.where(assignee_user_id: nil).order(:created_at).each_with_index do |task, i|
      due = case i % 4
      when 0 then @now - (1 + i % 3).days
      when 1 then @now + 1.day
      when 2 then @now + 3.days
      else @now + 6.days
      end
      task.update_columns(assignee_user_id: assignees[i % 2].id, due_at: due, created_at: @now - (4 + i % 5).days)
      task.update_columns(status: "completed", completed_at: @now - 1.day) if i % 5 == 4
    end
    # A few standalone follow-ups not tied to a sequence.
    return if SourcingTask.exists?(title: "Send the platform roadmap deck")
    Person.where(lifecycle_stage: "prospect").order(:id).limit(3).each_with_index do |person, i|
      SourcingTask.create!(person: person, title: [ "Send the platform roadmap deck", "Intro call with Harper", "Check in after the conference" ][i],
                           assignee_user_id: assignees[i % 2].id, status: "open", due_at: @now + (i + 1).days)
    end
    @summary["tasks"] = SourcingTask.count
  end

  # ---------------------------------------------------------------- resumes for the base roster

  def seed_resumes_for_existing_people!
    people = Person.order(:id).to_a
    people.each_with_index do |person, i|
      doc = Document.where(person_id: person.id, superseded_at: nil).order(:created_at).first
      next if doc&.file&.attached?
      aff = PersonAffiliation.where(person_id: person.id, current: true).order(:started_on).last || PersonAffiliation.where(person_id: person.id).order(:started_on).last
      next unless aff
      years = CustomFieldValue.find_by(custom_field_id: @custom["years_experience"].id, entity_type: "Person", entity_id: person.id)&.value_number.to_i
      family = family_for_title(aff.title)
      loc = location_label_for(person)
      @counter = i
      blocks = resume_blocks(person: person, title: aff.title, company: aff.company&.name || "Big Buck", location: loc, years: [ years, 1 ].max, family: family, headline: nil)
      slug = person.display_name.downcase.gsub(/[^a-z]+/, "-")
      scan = case i
      when 0, 50 then "pending"
      when 77 then "infected"
      else "clean"
      end
      attach_pdf!(person, "#{slug}-resume.pdf", BigBuckDemo::ResumePdf.render(blocks), at: person.created_at, scan: scan, document: doc)
      extra_documents!(person, slug, family, aff.title, [ years, 1 ].max, person.created_at) if i % 3 == 0
      @summary["resumes_for_existing"] += 1
    end
  end

  def family_for_title(title)
    case title.to_s
    when /Designer/ then :design
    when /Product Manager/ then :product
    when /Account|AE|Solutions|Sales/ then :sales
    else :eng
    end
  end

  def location_label_for(person)
    key = EntityDimensionValue.find_by(entity_type: "Person", entity_id: person.id, dimension_id: @loc_dim.id)&.dimension_value&.key
    location_meta(key)[:label]
  end

  # ---------------------------------------------------------------- referrals

  def seed_referrals!
    return if Referral.exists?
    (@referral_queue || []).each do |person, app, referrer, job|
      next if job.careers_visibility == "internal"
      app.reload
      status = { "hired" => "hired", "withdrawn" => "withdrawn" }.fetch(app.status, "converted")
      create_referral!(person, referrer, job, app, status, "Worked together previously and I would hire them again.")
    end
    # Base roster candidates who came in by referral.
    field = @custom.fetch("source")
    person_ids = CustomFieldValue.where(custom_field_id: field.id, entity_type: "Person", value_text: "referral").pluck(:entity_id)
    referrers = [ @s.fetch(:eng_interviewer), @s.fetch(:hiring_manager), @s.fetch(:sales_hm), @s.fetch(:sales_interviewer), @s.fetch(:design_ic), @s.fetch(:product_ic) ]
    notes = [ "Former teammate. Strong systems thinker.", "Met at a meetup. Great at explaining hard things.", "Customer champion who has asked about joining us.", "Worked with them for three years, easy yes.", "Ex-colleague looking for a bigger scope." ]
    # Hired and withdrawn applications first so every referral status is represented, then by id
    # (UUIDv7, stable under backdating).
    priority = { "hired" => 0, "withdrawn" => 1 }
    referred = Application.joins(:job).where(person_id: person_ids).where.not(jobs: { careers_visibility: "internal" }).to_a
    referred.sort_by { |app| [ priority.fetch(app.status, 2), app.id ] }.first(12).each_with_index do |app, i|
      next if Referral.exists?(person_id: app.person_id, job_id: app.job_id)
      status = { "hired" => "hired", "withdrawn" => "withdrawn" }.fetch(app.status, "converted")
      create_referral!(app.person, referrers[i % referrers.size], app.job, app, status, notes[i % notes.size])
    end
    # Submitted referrals that nobody has acted on yet.
    [ [ "Ines Almeida", :eng_interviewer, "Staff Site Reliability Engineer", "A former on-call partner, rock solid under pressure." ],
      [ "Callum Reid", :design_ic, nil, "Brilliant illustrator turned product designer. Not looking yet, but open to a chat." ],
      [ "Yusra Khalil", :cs_ic, "Customer Success Manager", "Ran my onboarding at a previous company, a natural." ] ].each do |name, who, job_title, note|
      next if Person.exists?(display_name: name)
      family = job_title ? RESUME_FAMILY.fetch(@job_ctx[job_title][:spec][:family], @job_ctx[job_title][:spec][:family]) : :design
      person = create_candidate!(name: name, family: family, years: 6, company: @company_keys[@counter % @company_keys.size], title: C::FAMILIES.fetch(family)[:ladder][1],
                                 location: "remote", source: "referral", stage: "prospect", created_at: @now - 2.days)
      create_referral!(person, @s.fetch(who), job_title && @job_ctx[job_title][:job], nil, "submitted", note)
    end
  end

  def create_referral!(person, referrer, job, app, status, note)
    referral = Referral.new(person: person, referrer_user_id: referrer.id, job: job, application: app, status: status, note: note)
    ChangeWriter.call(
      record: referral, action: "referral.created", event_type: "referral.created",
      payload: { "person_id" => person.id, "referrer_user_id" => referrer.id, "job_id" => job&.id, "application_id" => app&.id }
    )
    referral.update_columns(created_at: (app&.created_at || @now - 2.days), updated_at: @now - 1.day)
    @summary["referrals"] += 1
  end

  # ---------------------------------------------------------------- saved searches, admin, compliance

  def seed_saved_searches!
    [ [ :recruiter, "Designers in pipeline", { "q" => "designer", "lifecycle_stage" => "candidate" } ],
      [ :recruiter, "Prospects to re-engage", { "lifecycle_stage" => "prospect" } ],
      [ :recruiter, "Product candidates", { "q" => "product" } ],
      [ :sourcer, "SRE and infrastructure", { "q" => "SRE" } ],
      [ :sourcer, "Alumni worth a call", { "lifecycle_stage" => "alumni" } ],
      [ :admin, "Employees (internal mobility)", { "lifecycle_stage" => "employee" } ],
      [ :hiring_manager, "Engineers I am interviewing", { "q" => "engineer", "lifecycle_stage" => "candidate" } ] ].each do |who, name, filters|
      SavedSearch.find_or_create_by!(user_id: @s.fetch(who).id, name: name) { |s| s.entity_type = "person"; s.filters = filters }
    end
    pool = @pools.fetch("Design leaders, Bay Area")
    SavedSearch.find_or_create_by!(user_id: @s.fetch(:recruiter).id, name: "Design leaders pool") { |s| s.entity_type = "person"; s.filters = { "project_id" => pool.id } }
  end

  def seed_careers_content!
    apply_careers_copy!
    CustomField.find_or_create_by!(entity: "application", key: "heard_about_us") do |f|
      f.label = "How did you hear about us?"; f.field_type = "select"; f.data_class = "internal"
      f.options = [ "Careers page", "Referral", "LinkedIn", "Event", "Other" ]; f.show_on_apply = true; f.required = false
    end
  end

  # Careers brand copy, role descriptions and the demo roast question in the V1 demo's voice
  # (BigBuckDemo::Careers). Applied once per Careers::VERSION, so a deploy re-seed picks up new copy
  # without re-running the whole enrichment, and org edits survive until the version is bumped.
  def apply_careers_copy!
    copy = BigBuckDemo::Careers
    return if !@force && @org.reload.setting("demo_careers_version").to_i >= copy::VERSION

    @org.merge_settings!(copy::BRAND)
    Posting.includes(:job).find_each do |posting|
      role = copy::ROLES[posting.job.title]
      next unless role

      questions = Array(posting.questions)
      unless questions.any? { |q| q["key"] == copy::ROAST_KEY }
        questions += [ { "key" => copy::ROAST_KEY, "label" => role[:roast], "field_type" => "long_text", "required" => true, "options" => [] } ]
      end
      posting.update!(description: role[:description], questions: questions)
    end
    @org.reload.merge_settings!("demo_careers_version" => copy::VERSION)
  end

  def refresh_careers_copy!(org)
    @org = org
    ActiveRecord::Base.transaction { apply_careers_copy! }
  end

  def seed_admin_surfaces!
    recruiter_membership = Membership.find_by!(user: @s.fetch(:recruiter))
    admin_membership = Membership.find_by!(user: @s.fetch(:admin))
    [ [ "Sourcing assistant", "Reads people and pools and enrolls prospects in outreach sequences on the recruiter's behalf.", %w[people:read projects:read sequences:enroll], "active", recruiter_membership ],
      [ "Scheduling assistant", "Proposes interview times and reads scorecards so it can chase late feedback.", %w[scheduling:write jobs:read scorecards:read], "active", admin_membership ],
      [ "Offer analytics (paused)", "Read-only offer reporting. Paused while compensation fields are reviewed.", %w[offers:read], "paused", admin_membership ] ].each do |name, desc, scopes, status, owner|
      Agent.find_or_create_by!(owner_membership: owner, name: name) do |a|
        a.description = desc; a.scopes = scopes; a.status = status; a.created_by_user_id = owner.user_id
        a.paused_at = (@now - 3.days if status == "paused")
      end
    end
    [ [ "slack-notifications", "https://hooks.bigbuck.test/slack/recruiting-alerts", %w[application.moved offer.accepted interview.scheduled], true ],
      [ "hris-onboarding", "https://people.bigbuck.test/hris/webhooks/new-hires", %w[offer.accepted application.hire], true ],
      [ "data-warehouse", "https://data.bigbuck.test/ingest/recruiting", nil, false ] ].each do |key, url, events, active|
      WebhookEndpoint.find_or_create_by!(key: key) { |w| w.url = url; w.event_types = events; w.active = active }
    end
    endpoint = WebhookEndpoint.find_by!(key: "slack-notifications")
    if WebhookDelivery.where(webhook_endpoint_id: endpoint.id).none?
      OutboxEvent.where(organization_id: @org.id, event_type: endpoint.event_types).order(created_at: :desc).limit(6).each_with_index do |event, i|
        ok = i != 2
        WebhookDelivery.create!(
          webhook_endpoint: endpoint, outbox_event_id: event.id, event_type: event.event_type, status: ok ? "delivered" : "failed",
          attempt_count: ok ? 1 : 3, response_status: ok ? 200 : 503, response_snippet: ok ? "ok" : "upstream unavailable",
          delivered_at: (event.created_at + 2.seconds if ok), last_error: (ok ? nil : "HTTP 503 from endpoint")
        )
      end
    end
    seed_import_run!
    seed_compliance!
  end

  def seed_import_run!
    return if ImportRun.exists?
    run = ImportRun.create!(
      source: "csv", entity: "people", status: "applied",
      field_mapping: { "Full Name" => "display_name", "Email" => "email", "Phone" => "phone", "Current Company" => "company", "Title" => "title" },
      row_count: 48, created_count: 44, updated_count: 2, error_count: 2, processed_count: 48, actor_id: @s.fetch(:sourcer).id,
      finished_at: @now - 9.days,
      errors_json: [ { "row" => 17, "error" => "email is invalid" }, { "row" => 33, "error" => "display_name is blank" } ]
    )
    [ [ 1, "Dalia Hossain", "created", nil ], [ 2, "Idris Mahlangu", "created", nil ], [ 3, "Elif Yilmaz", "updated", nil ],
      [ 17, "Felix Ibrahim", "error", "email is invalid" ], [ 33, "", "error", "display_name is blank" ] ].each do |n, name, status, error|
      ImportRow.create!(import_run: run, row_number: n, source_id: "csv-#{n}", resource_type: (status == "error" ? nil : "Person"),
                        raw: { "Full Name" => name, "Email" => "#{name.downcase.tr(' ', '.')}@example.net" }, mapped: { "display_name" => name },
                        status: status, error_message: error)
    end
    run.update_columns(created_at: @now - 9.days - 5.minutes, updated_at: @now - 9.days)
  end

  def seed_compliance!
    DncCompany.find_or_create_by!(domain: "competitor.example") { |d| d.reason = "Direct competitor. Do not recruit from this team." }
    tyrell = @companies["tyrell"]
    DncCompany.find_or_create_by!(company_id: tyrell.id) { |d| d.reason = "Non-solicit agreement with Helix Biosciences until next June." } if tyrell
    return if DataRequest.exists?
    people = Person.where(lifecycle_stage: %w[alumni candidate]).order(:id).limit(3).to_a
    [ [ people[0], "access", "open", 3, 27 ], [ people[1], "erasure", "open", 20, 10 ], [ people[2], "correction", "completed", 25, 5 ] ].each do |person, kind, status, ago, due_in|
      next unless person
      DataRequest.create!(person: person, kind: kind, requester_email: person.primary_email, received_at: @now - ago.days, due_at: @now + due_in.days,
                          status: status, assigned_user_id: @s.fetch(:admin).id, completed_at: (@now - 2.days if status == "completed"),
                          outcome_note: (status == "completed" ? "Updated the preferred name and confirmed by email." : nil))
    end
    hold_target = Application.where(status: "rejected").order(:id).first
    if hold_target && !LegalHold.exists?
      LegalHold.create!(subject_type: "person", subject_id: hold_target.person_id, reason: "Pending employment claim: retain all interview records.",
                        placed_by_user_id: @s.fetch(:admin).id, placed_at: @now - 12.days)
    end
  end

  # ---------------------------------------------------------------- base data timestamps

  # The base dataset stamps everything "now". Spread its applications over the past
  # ~6 weeks (matching its own timeline anchors) so analytics and ages look real.
  # ---------------------------------------------------------------- CRM depth
  #
  # What makes the person record, the approvals queue and the outreach numbers look lived-in:
  # replies that are classified, notes, tags, a pool of fresh prospects nobody has contacted,
  # a rediscovery queue and agent proposals waiting for a decision.

  SEQUENCE_REPLIES = [
    "Thanks for reaching out. This is a good moment for me, happy to chat. Can we find 30 minutes next week?",
    "Sounds interesting. Tell me more about the team and what the first six months look like.",
    "What is the compensation range, and is the role remote?",
    "Appreciate the note, but I'm not looking right now. Maybe next year.",
    "Thanks, I'm interested. I can do Thursday or Friday afternoon.",
    "I'm out of the office until the 18th with limited access to email.",
    "Please remove me from your list.",
    "Is this the same team Morgan joined last spring?",
    "No thanks, I'm happy where I am.",
    "Love to learn more. Could you send the job description?"
  ].freeze

  def sequence_reply_text(person)
    @reply_i = (@reply_i || 0) + 1
    SEQUENCE_REPLIES[(@reply_i - 1) % SEQUENCE_REPLIES.size]
  end

  # A note a recruiter could have typed: a real PersonNote, on the feed at the time it was written.
  def write_note!(person, user, body, at, pinned: false)
    note = PersonNote.create!(person: person, body: body, author_user_id: user.id, pinned: pinned)
    note.update_columns(created_at: at, updated_at: at)
    record_timeline!(person, "note.created", { "note_id" => note.id, "author" => user.name, "body" => body }, at)
    @summary["notes"] += 1
    note
  end

  def seed_crm_depth!
    classify_replies!
    seed_tags!
    seed_person_notes!
    seed_fresh_prospects!
    seed_agent_proposals!
  end

  # Runs every reply through the same classifier live mail uses, so "interested" people show as
  # interested, an unsubscribe opts the person out, and the outreach numbers have a breakdown.
  def classify_replies!
    Communication.where(direction: "inbound", classification: nil).order(:created_at).find_each do |reply|
      ReplyClassifier.apply!(reply, ReplyClassifier.classify(subject: reply.subject, body: reply.body))
      @summary["replies_classified"] += 1
    end
  end

  TAGS = [
    [ "backend", "#2563eb", /engineer|developer|sre|reliability|platform/i ],
    [ "infrastructure", "#0f766e", /sre|reliability|platform|infrastructure|devops/i ],
    [ "design systems", "#a21caf", /design/i ],
    [ "product", "#b45309", /product manager|growth/i ],
    [ "sales", "#be123c", /sales|account|business development|sdr/i ],
    [ "customer success", "#4d7c0f", /customer|success|support/i ],
    [ "leadership", "#7c3aed", /vp|head of|director|chief|lead\b/i ],
    [ "campus", "#0369a1", /intern|student|graduate/i ]
  ].freeze
  EXTRA_TAGS = [ [ "open to relocate", "#64748b" ], [ "met at conference", "#64748b" ], [ "strong referral", "#15803d" ], [ "follow up in Q1", "#c2410c" ] ].freeze

  def seed_tags!
    tags = (TAGS + EXTRA_TAGS).to_h { |name, color, _| [ name, Tag.find_by(normalized_name: Tag.normalize_name(name)) || Tag.create!(name: name, color: color) ] }
    titles = PersonAffiliation.where(current: true).order(:started_on).pluck(:person_id, :title).to_h
    recruiter = @s.fetch(:recruiter)
    Person.where(lifecycle_stage: %w[prospect candidate alumni]).order(:created_at, :id).each_with_index do |person, i|
      next if PersonTag.exists?(person_id: person.id)
      title = [ titles[person.id], person.try(:current_title), person.try(:headline) ].compact.join(" ")
      names = TAGS.select { |_, _, pattern| pattern.match?(title) }.map(&:first).first(2)
      names << EXTRA_TAGS[i % EXTRA_TAGS.size].first if i % 4 == 0 || names.empty?
      names.uniq.each do |name|
        row = PersonTag.create!(person: person, tag: tags.fetch(name), added_by_user_id: recruiter.id)
        at = [ person.created_at + (1 + (i % 5)).days, @now - 2.hours ].min
        row.update_columns(created_at: at, updated_at: at)
        @summary["tags"] += 1
      end
    end
  end

  SOURCING_NOTES = [
    "Sourced from the platform engineering meetup list. Runs a team of six; not looking, but would talk for the right scope.",
    "Spoke for 20 minutes. Motivated by ownership more than title. Comp expectations are in range. Wants to hear back by month end.",
    "Second touch after the conference. Asked for the engineering blog posts; sent them.",
    "Came recommended by two people on the team. Strong systems background, lighter on people management.",
    "Left a voicemail. Prefers email, mornings Pacific.",
    "Was a finalist last year and lost to an internal move. Parted on good terms; worth a call when the next req opens.",
    "Relocating in the spring, so timing may line up with the Q2 openings.",
    "Portfolio review went well. Wants to meet the design lead before committing to a loop.",
    "Not ready to move until their current launch ships. Check back in eight weeks.",
    "Replied quickly and asked good questions about on-call. Send the rotation doc before the next call."
  ].freeze

  def seed_person_notes!
    return if PersonNote.where(body: SOURCING_NOTES.first).exists?
    authors = [ @s.fetch(:sourcer), @s.fetch(:recruiter) ]
    members = ProjectMember.where(status: "active").includes(:person).order(:created_at, :id).to_a
    members.each_with_index do |member, i|
      next unless member.person && member.person.visibility == "public"
      at = [ member.created_at + (2 + (i % 6)).days, @now - (3 + (i % 20)).hours ].min
      write_note!(member.person, authors[i % 2], SOURCING_NOTES[i % SOURCING_NOTES.size], at, pinned: i % 10 == 0)
    end
    # Active late-stage candidates get a short debrief-style note too.
    Application.where(status: "active", current_stage_key: %w[onsite offer panel case scenario role-play exec])
               .includes(:person).order(:id).limit(80).each_with_index do |app, i|
      person = app.person
      next if person.nil? || PersonNote.exists?(person_id: person.id)
      at = [ app.created_at + 2.days, @now - 1.day ].min
      write_note!(person, authors[i % 2],
                  "#{person.display_name.split.first} is in #{app.current_stage_key} on #{app.job.title}. Next step owned by recruiting.",
                  at)
    end
  end

  def people_target
    Integer(ENV.fetch("BIGBUCK_DEMO_PEOPLE_TARGET", DEFAULT_PEOPLE_TARGET.to_s))
  end

  # Fill toward people_target with CRM-ready prospects and light-touch candidates. Idempotent: stops
  # once the org already has enough people (FORCE re-runs must not grow past the target).
  def seed_crm_volume!
    have = Person.count
    need = people_target - have
    return if need <= 0

    families = %i[eng design product sales support]
    sources = %w[linkedin outbound referral careers agency campus]
    stages = %w[prospect prospect prospect candidate candidate alumni]
    sequences = %w[engineering-cold design-leaders default-outreach]
    authors = [ @s.fetch(:sourcer), @s.fetch(:recruiter) ]
    need.times do |i|
      family = families[i % families.size]
      fam = C::FAMILIES.fetch(family)
      years = family == :intern ? 1 : (3 + (i % 12))
      title = fam[:ladder][[ years / 4, fam[:ladder].size - 1 ].min]
      stage = stages[i % stages.size]
      person = create_candidate!(
        name: next_name, family: family, years: years,
        company: @company_keys[(@counter * 3) % @company_keys.size], title: title,
        location: %w[sf nyc austin remote london berlin toronto][i % 7],
        source: sources[i % sources.size], stage: stage,
        created_at: @now - (3 + (i % 90)).days,
        resume: i % 4 != 0
      )
      if i % 3 == 0 && person.visibility == "public"
        write_note!(person, authors[i % 2], SOURCING_NOTES[i % SOURCING_NOTES.size],
                    [ person.created_at + 1.day, @now - 2.hours ].min)
      end
      if stage == "prospect" && i % 5 == 0
        begin
          enroll_in_sequence!(person, sequences[i % sequences.size], steps_forward: i % 3,
                              stop: (i % 10 == 0 ? "replied" : nil), at: @now - (5 + (i % 20)).days)
        rescue ArgumentError => e
          Rails.logger.warn("volume enrollment skipped: #{e.message}")
        end
      end
      @summary["crm_volume"] += 1
    end
  end

  # Base fixture people never set Person.source (only some custom fields). Point CRM filters at real values.
  def backfill_person_sources!
    recruiter_id = @s.fetch(:recruiter).id
    fallback = %w[linkedin careers referral outbound agency campus]
    Person.where(source: [ nil, "" ]).find_each.with_index do |person, i|
      custom = CustomFieldValue.find_by(entity_type: "Person", entity_id: person.id, custom_field_id: @custom["source"]&.id)
      detail = custom&.value_text.presence || fallback[i % fallback.size]
      mapped, detail = person_source_for(detail)
      person.update_columns(source: mapped, source_detail: detail, sourced_at: person.created_at,
                            sourced_by_user_id: person.sourced_by_user_id || recruiter_id)
      @summary["sources_backfilled"] += 1
    end
  end

  FRESH_POOL = "Fresh leads: backend and platform"

  # People nobody has emailed yet, so an enrollment review has someone to enroll (and a couple to skip).
  def seed_fresh_prospects!
    sourcing = PipelineTemplate.find_by!(key: "sourcing-default")
    job = @job_ctx["Staff Site Reliability Engineer"]
    pool = Project.find_by(name: FRESH_POOL) ||
           Project.create!(name: FRESH_POOL, pipeline: Pipeline.build_from_template!(template: sourcing, scope: "project"), job: job && job[:job])
    @pools[FRESH_POOL] = pool
    need = 40 - ProjectMember.where(project_id: pool.id).count
    return if need <= 0
    fam = C::FAMILIES.fetch(:eng)
    need.times do |i|
      years = 4 + (i % 9)
      title = fam[:ladder][[ years / 4, fam[:ladder].size - 1 ].min]
      person = create_candidate!(name: next_name, family: :eng, years: years, company: @company_keys[(@counter * 5) % @company_keys.size], title: title,
                                 location: %w[sf nyc remote][i % 3], source: "outbound", stage: "prospect", created_at: @now - (2 + (i % 8)).days)
      member = seed_project_member!(pool, person, "prospect")
      seed_sourcing_activity!(person, pool, { pool_stage: "prospect" }, @now - (2 + (i % 8)).days)
      ProjectMember.where(id: member.id).update_all(created_at: @now - (2 + (i % 8)).days, updated_at: @now - (1 + (i % 3)).days)
      # One person the review must skip, with a reason a recruiter recognizes.
      person.update_columns(do_not_contact: true) if i == 5
      @summary["fresh_prospects"] += 1
    end
  end

  AGENT_JOBS = {
    "Staff Site Reliability Engineer" => [
      { "id" => "c-eng", "label" => "Engineering background", "kind" => "must", "match" => { "tag" => "backend" } },
      { "id" => "c-infra", "label" => "Infrastructure experience", "kind" => "nice", "match" => { "tag" => "infrastructure" } },
      { "id" => "c-senior", "label" => "Senior or staff level", "kind" => "nice", "match" => { "q" => "senior" } }
    ],
    "Senior Product Designer" => [
      { "id" => "c-design", "label" => "Design background", "kind" => "must", "match" => { "tag" => "design systems" } },
      { "id" => "c-senior", "label" => "Senior level", "kind" => "nice", "match" => { "q" => "senior" } }
    ]
  }.freeze

  # The sourcing assistant's real loop: rediscovery against each job's criteria, then proposals a
  # recruiter has to approve. A few are decided already so every tab of the page has something in it.
  def seed_agent_proposals!
    return if AgentProposal.exists?
    agent = Agent.find_by(name: "Sourcing assistant", status: "active") or return
    viewer = Membership.find_by!(user: @s.fetch(:recruiter))
    sequences = { "Staff Site Reliability Engineer" => "engineering-cold", "Senior Product Designer" => "design-leaders" }
    AGENT_JOBS.each do |title, criteria|
      job = Job.find_by(title: title) or next
      job.update!(criteria: criteria)
      sequence = Sequence.find_by(key: sequences.fetch(title)) or next
      result = SourcingAgent.run!(agent: agent, job: job, sequence: sequence, mailbox: @mailbox, viewer: viewer, limit: 7)
      @summary["proposals"] += result.proposed.size
      @summary["rediscovery"] += RediscoveryCandidate.where(job_id: job.id).count
      recruiter = @s.fetch(:recruiter)
      result.proposed.each_with_index do |proposal, i|
        proposal.update_columns(created_at: @now - (2 + i).hours)
        case i
        when 0, 1 then ProposalDecision.approve!(proposal, decided_by_user_id: recruiter.id)
        when 2 then ProposalDecision.reject!(proposal, decided_by_user_id: recruiter.id, reason: "Spoke last month; not the right time")
        end
      end
    end
  end

  # Thirty days of daily outreach numbers, taken after everything is backdated.
  def seed_outreach_snapshots!
    return if OutreachSnapshot.exists?
    30.downto(0) { |n| OutreachSnapshotter.call(day: Date.current - n) }
    puts "  outreach snapshots: #{OutreachSnapshot.count}"
  end

  def backdate_base_data!
    Application.where("created_at > ?", @now - 3.hours).where(posting_id: nil).where(job_id: Job.where(title: BigBuckDataset::INTERNAL_OPENING_TITLES).select(:id)).find_each.with_index do |app, i|
      anchor = @now - (36 + (i % 12)).days
      app.update_columns(created_at: anchor, updated_at: anchor + 3.days)
      StageTransition.where(subject_type: "Application", subject_id: app.id).order(:created_at).each_with_index do |t, k|
        t.update_columns(created_at: anchor + (k + 1).days, updated_at: anchor + (k + 1).days)
      end
      Person.where(id: app.person_id).update_all(created_at: anchor - 1.day)
      @summary["base_apps_backdated"] += 1
    end
    # Base interviews were laid out on a plain 3-day cadence (weekends included) with
    # scorecards stamped "now". Keep them on workdays and make feedback arrive after the call.
    base_job_ids = Job.where(title: BigBuckDataset::INTERNAL_OPENING_TITLES).select(:id)
    Interview.joins(:application).where(applications: { job_id: base_job_ids }, status: "completed").find_each do |interview|
      next unless Scorecard.where(interview_id: interview.id).where("created_at > ?", @now - 3.hours).exists?
      starts = interview.starts_at
      shift = starts.saturday? ? -1 : (starts.sunday? ? -2 : 0)
      duration = interview.ends_at - interview.starts_at
      starts = (starts - shift.abs.days).change(hour: biz_hour(interview.id.hash.abs), min: (interview.id.hash.abs.even? ? 0 : 30))
      interview.update_columns(starts_at: starts, ends_at: starts + duration, created_at: starts - 3.days, updated_at: starts)
      Scorecard.where(interview_id: interview.id).update_all(created_at: starts + 3.hours, updated_at: starts + 3.hours)
      @summary["base_interviews_adjusted"] += 1
    end
  end
end
