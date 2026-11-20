# frozen_string_literal: true

# Fills a (non-demo) org with a believable recruiting database for walking through the CRM:
#   - two recruiters, each with a Test mailbox
#   - ~300 people; 28 match "staff backend, Philadelphia, tag:go, not contacted in 90 days"
#     (3 of them are skip cases: do-not-contact, company DNC, already in another sequence)
#   - a closed job with 40 applicants, 12 of them rejected finalists (silver medalists)
#   - an open job, "Staff Backend Engineer", with must / nice-to-have criteria
# Run:  bin/rails crm:demo_seed ORG=<organization id>
class CrmDemoSeed
  FIRST = %w[Ada Ben Cara Dev Eli Fay Gus Hana Ivan Jo Kai Lena Milo Nia Omar Pia Quin Rae Sol Tia Uma Vic Wes Xia Yan Zed].freeze
  LAST = %w[Adler Brooks Chen Diaz Ellis Foster Gupta Hayes Ito Jones Khan Lopez Mehta Nolan Okafor Patel Quinn Reyes Singh Tran Usman Vega Wong Young Zhao].freeze
  OTHER_CITIES = %w[Boston Austin Seattle Denver Chicago Atlanta].freeze
  FILLER = [
    [ "Frontend engineer", "React and TypeScript" ], [ "Data scientist", "Python and ML" ], [ "Product designer", "design systems" ],
    [ "Engineering manager", "platform teams" ], [ "DevOps engineer", "Kubernetes and Terraform" ], [ "Mobile engineer", "iOS and Swift" ]
  ].freeze

  Summary = Struct.new(:people, :matching, :skip_cases, :closed_job, :open_job, :users, keyword_init: true)

  def self.call(organization:, count: 300)
    new(organization, count).call
  end

  def initialize(organization, count)
    @org = organization
    @count = count
    @serial = 0
  end

  def call
    Current.set(organization_id: @org.id, actor_type: "system", source_surface: "automation") do
      ActiveRecord::Base.transaction { seed! }
    end
  end

  private

  def seed!
      raise ArgumentError, "already_seeded" if Tag.exists?(normalized_name: "demo-seed")

      owner = Membership.joins(:role).find_by!(roles: { key: "owner" })
      Current.actor_id = owner.user_id
      @viewer = owner
      users = [ owner.user, second_recruiter ]
      users.each { |u| mailbox_for(u) }
      @go = Tag.find_or_create_named!("go")
      Tag.find_or_create_named!("demo-seed")
      closed = seed_closed_job
      open_job = seed_open_job
      matching, skips = seed_matching
      seed_near_misses
      seed_filler
      Summary.new(people: Person.count, matching: matching, skip_cases: skips, closed_job: closed, open_job: open_job, users: users.map(&:email))
  end

  def second_recruiter
    role = Role.find_by!(key: "recruiter")
    user = User.find_or_create_by!(email: "sam.recruiter@demo.bigbuck.test") { |u| u.name = "Sam Recruiter" }
    Membership.find_or_create_by!(user: user) { |m| m.role = role; m.status = "active" }
    user
  end

  def mailbox_for(user)
    Mailbox.find_or_create_by!(email: "#{user.email.split('@').first}@mailbox.bigbuck.test") do |m|
      m.kind = "personal"
      m.provider = "sandbox"
      m.status = "connected"
      m.secret_ref = "sandbox://mailbox"
      m.user = user
    end
  end

  def person(headline:, title:, city:, source: "sourced", tags: [], contacted_days_ago: nil, lifecycle: nil)
    @serial += 1
    name = "#{FIRST[@serial % FIRST.size]} #{LAST[(@serial / FIRST.size + @serial) % LAST.size]}"
    p = PersonMatcher.find_or_create(display_name: name, email: "#{name.downcase.tr(' ', '.')}.#{@serial}@example.test", viewer: @viewer).person
    attrs = { headline: headline, current_title: title, city: city, source: source }
    attrs[:lifecycle_stage] = lifecycle if lifecycle
    p.update!(attrs)
    tags.each { |t| PersonTagger.add!(person: p, tag: t) }
    p.update_columns(last_contacted_at: contacted_days_ago.days.ago, engagement_status: "contacted") if contacted_days_ago
    p
  end

  def job_pipeline
    template = PipelineTemplate.where(object_type: "job").order(:created_at).first || PipelineTemplate.create!(key: "demo-job", name: "Job", object_type: "job").tap do |t|
      t.publish!(stages: [ { "key" => "applied", "name" => "Applied", "type" => "apply" }, { "key" => "interview", "name" => "Interview", "type" => "interview" },
                           { "key" => "offer", "name" => "Offer", "type" => "offer" } ])
    end
    Pipeline.build_from_template!(template: template)
  end

  def apply(person, job, status)
    Application.create!(person: person, job: job, pipeline: job.pipeline, pipeline_version: job.pipeline.version,
      current_stage_key: job.pipeline.first_stage_key, status: status)
  end

  def seed_closed_job
    job = Job.create!(title: "Senior Backend Engineer", status: "closed", pipeline: job_pipeline)
    40.times do |i|
      backend = i < 28
      status = i < 12 ? "rejected" : (i == 12 ? "hired" : (i < 30 ? "rejected" : "withdrawn"))
      p = person(headline: backend ? "Senior backend engineer, Go and Postgres" : "Frontend engineer", title: backend ? "Senior Engineer" : "Engineer",
                 city: i.even? ? "Philadelphia" : OTHER_CITIES[i % OTHER_CITIES.size], source: "applied")
      apply(p, job, status)
    end
    { "id" => job.id, "title" => job.title, "applicants" => 40, "rejected_finalists" => 12 }
  end

  def seed_open_job
    job = Job.create!(title: "Staff Backend Engineer", status: "active", pipeline: job_pipeline, criteria: [
      { "id" => "c-backend", "label" => "Backend experience", "kind" => "must", "match" => { "q" => "backend" } },
      { "id" => "c-go", "label" => "Go", "kind" => "nice", "match" => { "q" => "go" } },
      { "id" => "c-philly", "label" => "Philadelphia", "kind" => "nice", "match" => { "location" => "Philadelphia" } }
    ])
    { "id" => job.id, "title" => job.title }
  end

  def seed_matching
    people = 28.times.map do |i|
      person(headline: "Staff backend engineer, Go services and infrastructure", title: "Staff Engineer", city: "Philadelphia",
             tags: [ @go ], contacted_days_ago: i.zero? ? 200 : nil)
    end
    dnc, corp, active = people.last(3)
    dnc.update!(do_not_contact: true)
    company = Company.create!(name: "Blocked Corp", domain: "blocked-corp.test")
    DncCompany.create!(company: company, domain: "blocked-corp.test")
    PersonAffiliation.create!(person: corp, company: company, current: true, title: "Staff Engineer")
    warmup = Sequence.create!(key: "demo-warmup", name: "Warm-up", status: "active",
      steps: [ { "id" => "s-w", "type" => "wait", "days" => 30 } ])
    SequenceEnrollment.create!(sequence: warmup, person: active, mailbox: Mailbox.first, step_index: 1, status: "active", next_run_at: 30.days.from_now)
    [ people.size, { "do_not_contact" => dnc.display_name, "company_dnc" => corp.display_name, "active_enrollment" => active.display_name } ]
  end

  # Each near miss fails exactly one part of the demo query.
  def seed_near_misses
    5.times { person(headline: "Staff backend engineer, Ruby", title: "Staff Engineer", city: "Philadelphia") }
    5.times { person(headline: "Staff backend engineer, Go", title: "Staff Engineer", city: "Boston", tags: [ @go ]) }
    4.times { person(headline: "Staff backend engineer, Go", title: "Staff Engineer", city: "Philadelphia", tags: [ @go ], contacted_days_ago: 10) }
  end

  def seed_filler
    remaining = @count - Person.count
    remaining.times do |i|
      headline, detail = FILLER[i % FILLER.size]
      person(headline: "#{headline}, #{detail}", title: headline, city: OTHER_CITIES[i % OTHER_CITIES.size],
             source: %w[sourced referral event import][i % 4], lifecycle: (i % 40).zero? ? "alumni" : nil)
    end
  end
end
