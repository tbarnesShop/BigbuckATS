# frozen_string_literal: true

# Deterministic Big Buck org for backend + UI end-to-end tests.
# 100 people with rich candidate profiles, spread across lifecycle, visibility,
# dimensions, pipeline stages, and talent-pool stages.
# Anyone at the interview stage or later has a full loop with submitted
# scorecards, offers cover every status, and each person has timeline activity.
class BigBuckDataset
  ORG_NAME = "Big Buck"
  DEFAULT_SLUG = "big-buck"
  TARGET_COUNT = 100
  INTERNAL_OPENING_TITLES = [ "Platform Engineer", "Account Executive" ].freeze

  FIRST_NAMES = %w[
    Avery Bailey Cameron Dakota Eden Finley Harper Indigo Jordan Kai
    Logan Morgan Noa Oakley Parker Quinn Reese Sage Taylor Uri
    Val Wes Xia Yuki Zion Alex Blair Casey Drew Ellis
    Flynn Greer Hayden Ira Jules Kit Lane Marley Nico Ocean
    Paige Remy Skye True Wren Ari Blake Chris Dana Eli
    Fran Gray Hope Ivan Jules Kris Lee Max Noel Oli
    Pat Rae Sam Tess Uma Vic Will Xan Yue Zak
  ].freeze

  LAST_NAMES = %w[
    Alvarez Bennett Carter Diaz Ellis Foster Garcia Hayes Ito Jackson
    Khan Lopez Meyer Nguyen Ortiz Patel Quinn Rivera Singh Tran
    Underwood Vega Walsh Xu Young Zimmerman Adler Brooks Cole Dunn
    Ernst Frost Green Holt Iyer Jain Kim Lane Moss Nash
    Owens Price Reed Stone Torres Vargas Wells Xu Yang Zhou
  ].freeze

  COMPANIES = [
    { key: "acme", name: "Arden Systems", domain: "ardensystems.example", industry: "Software", employee_band: "201-500" },
    { key: "northwind", name: "Northwind Labs", domain: "northwind.example", industry: "Biotech", employee_band: "51-200" },
    { key: "globex", name: "Halvorsen Manufacturing", domain: "halvorsen.example", industry: "Manufacturing", employee_band: "1000+" },
    { key: "initech", name: "Corvid Software", domain: "corvid.example", industry: "Software", employee_band: "51-200" },
    { key: "umbrella", name: "Bastion Security", domain: "bastionsec.example", industry: "Security", employee_band: "501-1000" },
    { key: "hooli", name: "Lumen Cloud", domain: "lumencloud.example", industry: "Software", employee_band: "1000+" },
    { key: "piedpiper", name: "Tidewater Data", domain: "tidewater.example", industry: "Software", employee_band: "11-50" },
    { key: "stark", name: "Keel Robotics", domain: "keelrobotics.example", industry: "Hardware", employee_band: "1000+" }
  ].freeze

  LOCATIONS = [
    { key: "sf", label: "San Francisco", country: "US", region: "us" },
    { key: "nyc", label: "New York", country: "US", region: "us" },
    { key: "austin", label: "Austin", country: "US", region: "us" },
    { key: "london", label: "London", country: "GB", region: "uk" },
    { key: "berlin", label: "Berlin", country: "DE", region: "eu" },
    { key: "paris", label: "Paris", country: "FR", region: "eu" },
    { key: "toronto", label: "Toronto", country: "CA", region: "us" },
    { key: "bangalore", label: "Bangalore", country: "IN", region: "apac" },
    { key: "remote", label: "Remote", country: "US", region: "us" }
  ].freeze

  SOURCES = %w[linkedin referral careers agency outbound campus].freeze
  TITLES = [
    "Software Engineer", "Senior Engineer", "Staff Engineer", "Engineering Manager",
    "Account Executive", "Senior AE", "Solutions Consultant", "Product Manager",
    "Designer", "Data Scientist", "SRE", "Security Engineer"
  ].freeze

  STANDARD_HOURS = {
    "mon" => [ [ "09:00", "17:00" ] ],
    "tue" => [ [ "09:00", "17:00" ] ],
    "wed" => [ [ "09:00", "17:00" ] ],
    "thu" => [ [ "09:00", "17:00" ] ],
    "fri" => [ [ "09:00", "17:00" ] ]
  }.freeze

  LATE_HOURS = {
    "mon" => [ [ "11:00", "19:00" ] ],
    "tue" => [ [ "11:00", "19:00" ] ],
    "wed" => [ [ "11:00", "19:00" ] ],
    "thu" => [ [ "11:00", "19:00" ] ],
    "fri" => [ [ "10:00", "16:00" ] ]
  }.freeze

  EU_HOURS = {
    "mon" => [ [ "09:00", "18:00" ] ],
    "tue" => [ [ "09:00", "18:00" ] ],
    "wed" => [ [ "09:00", "18:00" ] ],
    "thu" => [ [ "09:00", "18:00" ] ],
    "fri" => [ [ "09:00", "15:00" ] ]
  }.freeze

  # Interview stage and anything after it. Applied candidates do not get a loop.
  INTERVIEW_OR_LATER = %w[onsite offer].freeze

  # Engineering loop lives on the onsite stage: screen, coding, system design, onsite.
  ENG_LOOP = [
    { key: "screen", name: "Recruiter screen", minutes: 30, rubric: "recruiter-screen", note_key: "screen",
      interviewers: %i[recruiter] },
    { key: "coding", name: "Coding", minutes: 60, rubric: "coding", note_key: "coding",
      interviewers: %i[eng_interviewer] },
    { key: "system-design", name: "System design", minutes: 60, rubric: "system-design", note_key: "system-design",
      interviewers: %i[hiring_manager] },
    { key: "onsite", name: "Onsite panel", minutes: 180, rubric: "onsite", note_key: "onsite-eng",
      interviewers: %i[hiring_manager eng_interviewer recruiter] }
  ].freeze

  # Sales loop is the same shape, with conversations an AE actually has.
  SALES_LOOP = [
    { key: "screen", name: "Recruiter screen", minutes: 30, rubric: "recruiter-screen", note_key: "screen",
      interviewers: %i[recruiter] },
    { key: "discovery", name: "Discovery", minutes: 45, rubric: "discovery", note_key: "discovery",
      interviewers: %i[sales_interviewer] },
    { key: "case-study", name: "Case study", minutes: 45, rubric: "case-study", note_key: "case-study",
      interviewers: %i[sales_hm] },
    { key: "onsite", name: "Final panel", minutes: 150, rubric: "onsite-sales", note_key: "onsite-sales",
      interviewers: %i[sales_hm sales_interviewer recruiter] }
  ].freeze

  LOOP_RUBRICS = {
    "recruiter-screen" => {
      "name" => "Recruiter screen",
      "guidance" => "Motivation, communication, and whether this is the role they want.",
      "attributes" => [
        { "key" => "communication", "name" => "Communication" },
        { "key" => "motivation", "name" => "Motivation" },
        { "key" => "role-fit", "name" => "Role fit" }
      ]
    },
    "coding" => {
      "name" => "Coding",
      "guidance" => "How they break down a problem and the quality of the code they write.",
      "attributes" => [
        { "key" => "problem-solving", "name" => "Problem solving" },
        { "key" => "code-quality", "name" => "Code quality" },
        { "key" => "communication", "name" => "Communication" }
      ]
    },
    "system-design" => {
      "name" => "System design",
      "guidance" => "How they scope a system and defend the tradeoffs.",
      "attributes" => [
        { "key" => "problem-framing", "name" => "Problem framing" },
        { "key" => "tradeoffs", "name" => "Tradeoffs" },
        { "key" => "communication", "name" => "Communication" }
      ]
    },
    "onsite" => {
      "name" => "Onsite",
      "guidance" => "Cross-functional onsite for engineering. Depth, collaboration, and a hire signal.",
      "attributes" => [
        { "key" => "depth", "name" => "Technical depth" },
        { "key" => "collaboration", "name" => "Collaboration" },
        { "key" => "hiring-signal", "name" => "Hiring signal" }
      ]
    },
    "discovery" => {
      "name" => "Discovery",
      "guidance" => "Whether they find the customer's problem before they pitch.",
      "attributes" => [
        { "key" => "questioning", "name" => "Questioning" },
        { "key" => "listening", "name" => "Listening" },
        { "key" => "next-step", "name" => "Next step" }
      ]
    },
    "case-study" => {
      "name" => "Case study",
      "guidance" => "Can they turn a scenario into a mutual plan and a forecast.",
      "attributes" => [
        { "key" => "qualification", "name" => "Qualification" },
        { "key" => "plan", "name" => "Mutual plan" },
        { "key" => "judgment", "name" => "Judgment" }
      ]
    },
    "onsite-sales" => {
      "name" => "Sales onsite",
      "guidance" => "Late-stage role play with the hiring panel.",
      "attributes" => [
        { "key" => "presence", "name" => "Presence" },
        { "key" => "objection-handling", "name" => "Objection handling" },
        { "key" => "hiring-signal", "name" => "Hiring signal" }
      ]
    }
  }.freeze

  RATINGS = %w[strong_yes yes yes mixed no].freeze
  RATING_SCORE = { "strong_yes" => 5, "yes" => 4, "mixed" => 3, "no" => 2 }.freeze

  # Real interviewer write-ups. %{name}, %{company}, and %{title} are filled per candidate.
  SCORECARD_NOTES = {
    "screen" => {
      "strong_yes" => "%{name} was specific about the %{title} work at %{company}: what they owned, what they would change, and why this role is the next step. Clear communicator. Advance.",
      "yes" => "%{name} can tell the %{company} story and the level lines up with %{title}. Motivation is real, if a little broad. Worth the rest of the loop.",
      "mixed" => "The %{company} examples stayed high level. %{name} wants a %{title} title but could not point to a decision they made. I am unsure on scope.",
      "no" => "%{name} is shopping titles more than this role. The %{company} work does not match what we need from a %{title}."
    },
    "coding" => {
      "strong_yes" => "%{name} drove the session. They named the invariant, tested the edge, and talked through tradeoffs without being walked there. The %{company} background showed.",
      "yes" => "Finished a working solution and explained it. A couple of false starts, then a clean fix. Solid %{title} signal from %{name}.",
      "mixed" => "Needed hints to get off the first approach. The code worked, but %{name} did not notice the failure mode until I pointed at it.",
      "no" => "We did not get to a working solution. %{name} could not say what the code was doing when it failed."
    },
    "system-design" => {
      "strong_yes" => "%{name} framed the constraints before drawing boxes, called out the bottleneck, and picked a boring design they could defend. This is the judgment we want.",
      "yes" => "Reasonable design for the scale we gave them. %{name} handled the follow-ups on failure and data growth. I would trust them with a subsystem.",
      "mixed" => "The diagram got complicated fast. %{name} added a queue before saying what problem it solved. Depth is uneven compared with their %{title} scope at %{company}.",
      "no" => "Could not get past a single box. No story for failure, growth, or who operates it. Not the level this loop is for."
    },
    "onsite-eng" => {
      "strong_yes" => "Best conversation of the loop. %{name} pushed back on a premise, then updated the answer when the constraint changed. I would hire them onto the platform team.",
      "yes" => "Worked well with the panel. The deep dive on the %{company} system was concrete, and %{name} was good when we disagreed.",
      "mixed" => "Pleasant and prepared, but the technical answers stayed at the diagram. I did not hear enough from %{name} about what they personally decided at %{company}.",
      "no" => "The panel could not get to a decision %{name} owned. The %{title} story at %{company} did not survive follow-up questions."
    },
    "discovery" => {
      "strong_yes" => "%{name} opened with the customer's problem, not the pitch. They qualified budget and timeline without making it feel like a script. This is how our better AEs run a first call.",
      "yes" => "Good discovery. %{name} found the pain and the next step. A bit quick to demo, but the questions were the right ones for someone coming from %{company}.",
      "mixed" => "%{name} jumped to product before understanding why the buyer is looking. They recovered once prompted, which is not the same as doing it cold.",
      "no" => "Talked the whole time. %{name} did not ask what a win looks like for the buyer. Not ready for this AE seat."
    },
    "case-study" => {
      "strong_yes" => "%{name} built a mutual plan on the whiteboard: champion, economic buyer, risk, and a close date they could defend. The %{company} deal story matched the exercise.",
      "yes" => "Clear plan and a credible forecast. %{name} missed one stakeholder and caught it when asked. I would put them on a live deal with support.",
      "mixed" => "The plan was a list of activities, not a point of view. %{name} could not say what would make this deal slip.",
      "no" => "No qualification, no multi-thread, no ask. %{name}'s case never became a deal."
    },
    "onsite-sales" => {
      "strong_yes" => "The role play felt like a real late-stage call. %{name} handled the pricing pushback and still left with a next step. Hire.",
      "yes" => "Credible with the panel. %{name} knows how to run a cycle and was honest about a deal they lost at %{company}.",
      "mixed" => "Energy was high and the close was fuzzy. I wanted a sharper point of view from %{name} on why we win against the incumbent.",
      "no" => "Could not hold the room when the scenario got tense. The %{title} experience at %{company} did not show up in the role play."
    }
  }.freeze

  INTERVIEWER_FOCUS = {
    recruiter: "I was checking motivation, communication, and level.",
    hiring_manager: "I was listening for depth and whether I want them on the team.",
    eng_interviewer: "I was looking at how they broke the problem down.",
    sales_hm: "I was listening for how they run a deal.",
    sales_interviewer: "I was looking at discovery and how they handle pushback."
  }.freeze

  # Stable named roster used by permission/UI e2e assertions.
  NAMED_CANDIDATES = [
    { key: "ava", name: "Ava Chen", email: "ava.chen@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+1-415-555-0101", location: "sf", company: "acme", title: "Software Engineer",
      track: :application, job: :eng, app_stage: "applied", app_status: "active",
      has_communication: true, years_experience: 4, source: "careers", willing_to_relocate: false },
    { key: "ben", name: "Ben Ortiz", email: "ben.ortiz@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+1-415-555-0102", location: "sf", company: "northwind", title: "Senior Engineer",
      track: :application, job: :eng, app_stage: "onsite", app_status: "active",
      has_interview: true, has_scheduling_link: true, has_offer: true, offer_status: "draft",
      offer_fields: { "base_salary" => 185_000, "currency" => "USD" },
      years_experience: 7, source: "referral", willing_to_relocate: true },
    { key: "cara", name: "Cara Nguyen", email: "cara.nguyen@example.com", stage: "prospect", visibility: "public", department: "engineering",
      phone: "+1-628-555-0103", location: "nyc", company: "globex", title: "Staff Engineer",
      track: :pool, pool: :platform, pool_stage: "prospect",
      years_experience: 9, source: "linkedin", willing_to_relocate: false },
    { key: "diego", name: "Diego Santos", email: "diego.santos@example.com", stage: "candidate", visibility: "restricted", department: "engineering",
      phone: "+1-212-555-0104", location: "nyc", company: "initech", title: "Engineering Manager",
      track: :application, job: :eng, app_stage: "applied", app_status: "active",
      years_experience: 11, source: "agency", willing_to_relocate: true },
    { key: "elena", name: "Elena Rossi", email: "elena.rossi@example.com", stage: "employee", visibility: "public", department: "engineering",
      phone: "+1-415-555-0105", location: "sf", company: "acme", title: "Senior Engineer",
      track: :none, years_experience: 6, source: "campus", willing_to_relocate: false },
    { key: "farah", name: "Farah Khan", email: "farah.khan@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+44-20-7946-0106", location: "london", company: "hooli", title: "SRE",
      track: :application, job: :eng, app_stage: "offer", app_status: "active",
      has_interview: true, has_offer: true, offer_status: "pending_approval",
      years_experience: 5, source: "linkedin", willing_to_relocate: true },
    { key: "gabe", name: "Gabe Miller", email: "gabe.miller@example.com", stage: "alumni", visibility: "public", department: "engineering",
      phone: "+1-512-555-0107", location: "austin", company: "umbrella", title: "Software Engineer",
      track: :none, years_experience: 8, source: "referral", willing_to_relocate: false },
    { key: "hana", name: "Hana Park", email: "hana.park@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+1-646-555-0108", location: "nyc", company: "piedpiper", title: "Product Manager",
      track: :application, job: :eng, app_stage: "onsite", app_status: "active",
      has_interview: true, years_experience: 3, source: "careers", willing_to_relocate: false },
    { key: "ian", name: "Ian Brooks", email: "ian.brooks@example.com", stage: "prospect", visibility: "restricted", department: "engineering",
      phone: "+49-30-555-0109", location: "berlin", company: "stark", title: "Security Engineer",
      track: :pool, pool: :platform, pool_stage: "reached-out",
      years_experience: 10, source: "outbound", willing_to_relocate: true },
    { key: "jade", name: "Jade Thompson", email: "jade.thompson@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+1-415-555-0110", location: "remote", company: "acme", title: "Designer",
      track: :application, job: :eng, app_stage: "applied", app_status: "withdrawn",
      years_experience: 2, source: "careers", willing_to_relocate: false },
    { key: "kai", name: "Kai Nakamura", email: "kai.nakamura@example.com", stage: "candidate", visibility: "public", department: "sales",
      phone: "+1-212-555-0111", location: "nyc", company: "northwind", title: "Account Executive",
      track: :application, job: :sales, app_stage: "applied", app_status: "active",
      has_communication: true, years_experience: 5, source: "linkedin", willing_to_relocate: false },
    { key: "lena", name: "Lena Hofmann", email: "lena.hofmann@example.com", stage: "candidate", visibility: "public", department: "sales",
      phone: "+49-30-555-0112", location: "berlin", company: "globex", title: "Senior AE",
      track: :application, job: :sales, app_stage: "onsite", app_status: "active",
      has_interview: true, years_experience: 6, source: "referral", willing_to_relocate: true },
    { key: "marco", name: "Marco Silva", email: "marco.silva@example.com", stage: "prospect", visibility: "public", department: "sales",
      phone: "+33-1-555-0113", location: "paris", company: "initech", title: "Solutions Consultant",
      track: :pool, pool: :sales, pool_stage: "replied",
      years_experience: 4, source: "outbound", willing_to_relocate: false },
    { key: "nina", name: "Nina Patel", email: "nina.patel@example.com", stage: "candidate", visibility: "restricted", department: "sales",
      phone: "+91-80-555-0114", location: "bangalore", company: "hooli", title: "Account Executive",
      track: :application, job: :sales, app_stage: "applied", app_status: "active",
      years_experience: 3, source: "agency", willing_to_relocate: true },
    { key: "omar", name: "Omar Hassan", email: "omar.hassan@example.com", stage: "employee", visibility: "public", department: "sales",
      phone: "+1-416-555-0115", location: "toronto", company: "umbrella", title: "Senior AE",
      track: :none, years_experience: 9, source: "referral", willing_to_relocate: false },
    { key: "priya", name: "Priya Shah", email: "priya.shah@example.com", stage: "candidate", visibility: "public", department: "sales",
      phone: "+1-512-555-0116", location: "austin", company: "piedpiper", title: "Account Executive",
      track: :application, job: :sales, app_stage: "offer", app_status: "active",
      has_interview: true, has_offer: true, offer_status: "sent",
      years_experience: 4, source: "careers", willing_to_relocate: false },
    { key: "quinn", name: "Quinn Adler", email: "quinn.adler@example.com", stage: "alumni", visibility: "public", department: "sales",
      phone: "+1-415-555-0117", location: "sf", company: "stark", title: "Account Executive",
      track: :none, years_experience: 7, source: "linkedin", willing_to_relocate: false },
    { key: "rosa", name: "Rosa Alvarez", email: "rosa.alvarez@example.com", stage: "candidate", visibility: "public", department: nil,
      phone: "+1-305-555-0118", location: "remote", company: "acme", title: "Data Scientist",
      track: :pool, pool: :sales, pool_stage: "prospect",
      years_experience: 5, source: "campus", willing_to_relocate: true },
    { key: "sam", name: "Sam Okonkwo", email: "sam.okonkwo@example.com", stage: "prospect", visibility: "public", department: nil,
      phone: "+44-20-7946-0119", location: "london", company: "northwind", title: "Software Engineer",
      track: :pool, pool: :platform, pool_stage: "ready",
      years_experience: 6, source: "outbound", willing_to_relocate: true },
    { key: "tess", name: "Tess Bergman", email: "tess.bergman@example.com", stage: "candidate", visibility: "public", department: nil,
      phone: "+1-617-555-0120", location: "nyc", company: "globex", title: "Designer",
      track: :application, job: :eng, app_stage: "applied", app_status: "rejected",
      years_experience: 3, source: "careers", willing_to_relocate: false },
    { key: "uma", name: "Uma Sharma", email: "uma.sharma@example.com", stage: "candidate", visibility: "restricted", department: nil,
      phone: "+91-22-555-0121", location: "bangalore", company: "initech", title: "SRE",
      track: :application, job: :eng, app_stage: "onsite", app_status: "active",
      has_interview: true, years_experience: 8, source: "agency", willing_to_relocate: false },
    { key: "victor", name: "Victor Lang", email: "victor.lang@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+1-503-555-0122", location: "remote", company: "hooli", title: "Staff Engineer",
      track: :application, job: :eng, app_stage: "applied", app_status: "active",
      years_experience: 12, source: "referral", willing_to_relocate: true },
    { key: "wren", name: "Wren Cole", email: "wren.cole@example.com", stage: "candidate", visibility: "public", department: "engineering",
      phone: "+1-206-555-0123", location: "sf", company: "umbrella", title: "Software Engineer",
      track: :application, job: :eng, app_stage: "onsite", app_status: "active",
      has_interview: true, has_scheduling_link: true, years_experience: 4, source: "linkedin", willing_to_relocate: false },
    { key: "yasmin", name: "Yasmin Farouk", email: "yasmin.farouk@example.com", stage: "candidate", visibility: "public", department: "sales",
      phone: "+33-1-555-0124", location: "paris", company: "piedpiper", title: "Senior AE",
      track: :application, job: :sales, app_stage: "applied", app_status: "active",
      years_experience: 5, source: "outbound", willing_to_relocate: true },
    { key: "zachary", name: "Zachary Kim", email: "zachary.kim@example.com", stage: "prospect", visibility: "public", department: "engineering",
      phone: "+1-408-555-0125", location: "sf", company: "stark", title: "Software Engineer",
      track: :pool, pool: :platform, pool_stage: "reached-out",
      years_experience: 2, source: "campus", willing_to_relocate: false }
  ].freeze

  Result = Struct.new(
    :organization, :roles, :dimensions, :department_values, :location_values, :users, :memberships,
    :people, :jobs, :applications, :offers, :projects, :project_members,
    :interviewer_profiles, :interviewer_pools, :calendar_connections, :hiring_teams,
    :rooms, :holidays,
    keyword_init: true
  )

  def self.candidates
    NAMED_CANDIDATES + generated_candidates
  end

  def self.generated_candidates
    start = NAMED_CANDIDATES.size + 1
    seen = NAMED_CANDIDATES.map { |spec| spec[:email].to_s.downcase }.to_set
    (start..TARGET_COUNT).map do |n|
      spec = build_generated_spec(n)
      # Name-based addresses can repeat (two "Jules Kim"s); the second gets a number, as real ones do.
      if seen.include?(spec[:email])
        local, domain = spec[:email].split("@")
        spec = spec.merge(email: "#{local}#{n}@#{domain}")
      end
      seen << spec[:email]
      spec
    end
  end

  # Personal addresses on reserved example domains: they read like real people and can never deliver.
  CANDIDATE_EMAIL_DOMAINS = %w[example.com example.net example.org].freeze

  def self.build_generated_spec(n)
    idx = n - 1
    first = FIRST_NAMES[idx % FIRST_NAMES.size]
    last = LAST_NAMES[(idx * 3) % LAST_NAMES.size]
    key = format("c%03d", n)
    email = "#{first.downcase}.#{last.downcase}@#{CANDIDATE_EMAIL_DOMAINS[idx % CANDIDATE_EMAIL_DOMAINS.size]}"
    location = LOCATIONS[idx % LOCATIONS.size]
    company = COMPANIES[idx % COMPANIES.size]
    department = %w[engineering engineering sales sales][idx % 4]
    department = nil if (idx % 11).zero?
    lifecycle = %w[prospect candidate candidate candidate employee alumni][idx % 6]
    visibility = case idx % 17
    when 0 then "restricted"
    when 1 then "confidential"
    when 2 then "private"
    else "public"
    end

    track, extras = track_for(idx, lifecycle, department)
    {
      key: key,
      name: "#{first} #{last}",
      email: email,
      stage: lifecycle,
      visibility: visibility,
      department: department,
      phone: format("+1-555-%04d", 2000 + n),
      location: location[:key],
      country: location[:country],
      region: location[:region],
      company: company[:key],
      title: TITLES[idx % TITLES.size],
      years_experience: 1 + (idx % 15),
      source: SOURCES[idx % SOURCES.size],
      willing_to_relocate: idx.even?,
      track: track
    }.merge(extras)
  end

  def self.track_for(idx, lifecycle, department)
    return [ :none, {} ] if lifecycle.in?(%w[employee alumni]) && (idx % 3).zero?

    if lifecycle == "prospect" || (idx % 5).zero?
      pool = department == "sales" ? :sales : :platform
      stage = %w[prospect reached-out replied ready][idx % 4]
      return [ :pool, { pool: pool, pool_stage: stage } ]
    end

    job = department == "sales" ? :sales : :eng
    app_stage = %w[applied applied onsite onsite offer][idx % 5]
    app_status = case idx % 23
    when 0 then "rejected"
    when 1 then "withdrawn"
    when 2 then "hired"
    else "active"
    end
    # A hire always comes through Offer with an accepted offer, never straight from Applied.
    app_stage = "offer" if app_status == "hired"
    extras = {
      job: job,
      app_stage: app_stage,
      app_status: app_status,
      has_interview: app_stage.in?(INTERVIEW_OR_LATER),
      has_scheduling_link: app_stage == "onsite" && app_status == "active" && idx.even?,
      has_offer: app_stage == "offer" && app_status.in?(%w[active hired]),
      has_communication: idx % 3 == 0
    }
    [ :application, extras ]
  end

  def self.call(slug: DEFAULT_SLUG, reset: false)
    new(slug: slug, reset: reset).call
  end

  def initialize(slug:, reset:)
    @slug = slug
    @reset = reset
  end

  def call
    if @reset
      wipe_existing!
    elsif (existing = Organization.find_by(slug: @slug))
      return reload_existing(existing)
    end

    build!
  end

  # Backfill only the named published demo jobs. Explicit internal/hidden choices
  # and unpublished roles are preserved; rerunning this creates no new records.
  def self.seed_internal_openings!(organization:)
    Current.set(organization_id: organization.id, source_surface: "system") do
      Job.on_careers("public").where(title: INTERNAL_OPENING_TITLES, careers_visibility: "public")
         .find_each { |job| job.update!(careers_visibility: "both") }
    end
  end

  def self.fixture_payload(result)
    people_specs = candidates.index_by { |c| c[:email] }
    {
      "organization" => {
        "id" => result.organization.id,
        "name" => result.organization.name,
        "slug" => result.organization.slug,
        "careers" => {
          "hero_image_url" => result.organization.careers_hero_image_url,
          "headline" => result.organization.careers_headline,
          "subcopy" => result.organization.careers_subcopy
        }
      },
      "users" => result.users.transform_values { |u| { "id" => u.id, "email" => u.email, "name" => u.name } },
      "people" => result.people.map { |row|
        person = row[:person]
        spec = people_specs[person.primary_email] || {}
        {
          "id" => person.id,
          "key" => row[:key],
          "display_name" => person.display_name,
          "primary_email" => person.primary_email,
          "primary_phone" => person.primary_phone,
          "lifecycle_stage" => person.lifecycle_stage,
          "visibility" => person.visibility,
          "country" => person.country,
          "region" => person.region,
          "department" => row[:department],
          "location" => row[:location],
          "title" => spec[:title],
          "company" => spec[:company],
          "years_experience" => spec[:years_experience],
          "source" => spec[:source],
          "willing_to_relocate" => spec[:willing_to_relocate]
        }
      },
      "jobs" => result.jobs.map { |job|
        pipeline = job.pipeline
        {
          "id" => job.id,
          "title" => job.title,
          "status" => job.status,
          "careers_visibility" => job.careers_visibility,
          "careers_published" => job.postings.exists?(status: "published"),
          "pipeline_id" => job.pipeline_id,
          "pipeline" => pipeline && {
            "id" => pipeline.id,
            "stages" => Array(pipeline.resolved_stages)
          }
        }
      },
      "applications" => Array(result.applications).map { |app|
        {
          "id" => app.id,
          "job_id" => app.job_id,
          "person_id" => app.person_id,
          "status" => app.status,
          "current_stage_key" => app.current_stage_key,
          "pipeline_id" => app.pipeline_id
        }
      },
      "offers" => Array(result.offers).map { |offer|
        {
          "id" => offer.id,
          "application_id" => offer.application_id,
          "status" => offer.status,
          "fields" => offer.current_version&.fields
        }
      },
      "projects" => Array(result.projects).map { |project|
        pipeline = project.pipeline
        {
          "id" => project.id,
          "name" => project.name,
          "job_id" => project.job_id,
          "pipeline_id" => project.pipeline_id,
          "confidential" => project.confidential,
          "member_count" => ProjectMember.where(project_id: project.id, status: "active").count,
          "pipeline" => pipeline && {
            "id" => pipeline.id,
            "stages" => Array(pipeline.resolved_stages)
          },
          "job" => project.job && { "id" => project.job.id, "title" => project.job.title, "status" => project.job.status }
        }
      },
      "project_members" => Array(result.project_members).map { |member|
        {
          "id" => member.id,
          "project_id" => member.project_id,
          "person_id" => member.person_id,
          "pipeline_id" => member.pipeline_id,
          "current_stage_key" => member.current_stage_key,
          "status" => member.status,
          "converted_application_id" => member.converted_application_id
        }
      },
      "interviewer_profiles" => Array(result.interviewer_profiles).map { |profile|
        {
          "id" => profile.id,
          "user_id" => profile.user_id,
          "time_zone" => profile.time_zone,
          "working_hours" => profile.working_hours,
          "daily_limit" => profile.daily_limit,
          "weekly_limit" => profile.weekly_limit,
          "buffer_minutes" => profile.buffer_minutes,
          "paused" => profile.paused
        }
      },
      "interviewer_pools" => Array(result.interviewer_pools).map { |pool|
        {
          "id" => pool.id,
          "key" => pool.key,
          "name" => pool.name,
          "member_user_ids" => pool.members.order(:created_at).map(&:user_id)
        }
      },
      "calendar_connections" => Array(result.calendar_connections).map { |conn|
        {
          "id" => conn.id,
          "kind" => conn.kind,
          "user_id" => conn.user_id,
          "calendar_id" => conn.calendar_id,
          "status" => conn.status
        }
      },
      "hiring_teams" => Array(result.hiring_teams).map { |team|
        {
          "id" => team.id,
          "job_id" => team.job_id,
          "members" => team.members.order(:created_at).map { |m|
            { "id" => m.id, "user_id" => m.user_id, "team_role" => m.team_role }
          }
        }
      },
      "rooms" => Array(result.rooms).map { |room|
        {
          "id" => room.id,
          "key" => room.key,
          "name" => room.name,
          "resource_email" => room.resource_email,
          "location_key" => room.location_key,
          "capacity" => room.capacity
        }
      },
      "holidays" => Array(result.holidays).map { |holiday|
        {
          "id" => holiday.id,
          "name" => holiday.name,
          "observed_on" => holiday.observed_on.iso8601,
          "location_key" => holiday.location_key
        }
      },
      "expectations" => expectations
    }
  end

  def self.expectations
    roster = candidates
    {
      "admin_count" => roster.size,
      "recruiter_count" => roster.count { |c| c[:visibility] == "public" },
      "hiring_manager_count" => roster.count { |c| c[:visibility] == "public" && c[:department] == "engineering" },
      "non_user_count" => 0,
      "restricted_names" => roster.select { |c| c[:visibility] != "public" }.map { |c| c[:name] },
      "hiring_manager_names" => roster.select { |c| c[:visibility] == "public" && c[:department] == "engineering" }.map { |c| c[:name] }
    }
  end

  # Named anchors keep their status (Ben stays draft for the UI fixture).
  # A hired application is an accepted offer. Everyone else fills any status
  # the named anchors did not already cover, then repeats the full set.
  def self.offer_status_plan
    specs = candidates.select { |c| c[:has_offer] }
    plan = {}
    specs.each { |spec| plan[spec[:email]] = spec[:offer_status] if spec[:offer_status].present? }
    specs.each do |spec|
      next if plan[spec[:email]]

      plan[spec[:email]] = "accepted" if spec[:app_status] == "hired"
    end
    covered = plan.values.uniq
    missing = Offer::STATUSES - covered
    rest = specs.reject { |spec| plan[spec[:email]] }
    queue = missing + (Offer::STATUSES * (rest.size + 1))
    rest.each_with_index { |spec, i| plan[spec[:email]] = queue.fetch(i) }
    plan
  end

  def self.loop_for(job_key)
    job_key == :sales ? SALES_LOOP : ENG_LOOP
  end

  def self.job_stages_for(job_key)
    interviews = loop_for(job_key).map do |step|
      {
        "key" => step[:key],
        "name" => step[:name],
        "required" => true,
        "rubric_key" => step[:rubric]
      }
    end
    [
      { "key" => "applied", "name" => "Applied", "type" => "apply" },
      { "key" => "onsite", "name" => "Onsite", "type" => "interview", "interviews" => interviews },
      { "key" => "offer", "name" => "Offer", "type" => "offer" }
    ]
  end

  def self.stable_fixture_payload(result)
    payload = fixture_payload(result)
    remap = {}

    remap[payload["organization"]["id"]] = "org-bigbuck-fixture-0001"
    payload["organization"]["id"] = remap[payload["organization"]["id"]]
    payload["organization"]["slug"] = "big-buck-fixture"

    payload["users"].each do |role, user|
      stable = "user-bigbuck-#{role.tr('_', '-')}-0001"
      remap[user["id"]] = stable
      user["id"] = stable
    end

    payload["people"].each do |person|
      stable = "person-#{person['key']}-0001"
      remap[person["id"]] = stable
      person["id"] = stable
    end

    payload["jobs"].each_with_index do |job, idx|
      stable = idx.zero? ? "job-bigbuck-platform-0001" : "job-bigbuck-ae-0001"
      pipe_stable = idx.zero? ? "pipe-bigbuck-eng-0001" : "pipe-bigbuck-sales-0001"
      remap[job["id"]] = stable
      remap[job["pipeline_id"]] = pipe_stable if job["pipeline_id"]
      job["id"] = stable
      job["pipeline_id"] = pipe_stable
      if job["pipeline"]
        remap[job["pipeline"]["id"]] = pipe_stable
        job["pipeline"]["id"] = pipe_stable
      end
    end

    payload["projects"].each do |project|
      stable = project["name"].include?("Platform") ? "project-platform-pool-0001" : "project-ae-pool-0001"
      pipe_stable = project["name"].include?("Platform") ? "pipe-sourcing-platform-0001" : "pipe-sourcing-sales-0001"
      remap[project["id"]] = stable
      remap[project["pipeline_id"]] = pipe_stable if project["pipeline_id"]
      project["id"] = stable
      project["pipeline_id"] = pipe_stable
      project["job_id"] = remap[project["job_id"]] if project["job_id"]
      if project["pipeline"]
        remap[project["pipeline"]["id"]] = pipe_stable
        project["pipeline"]["id"] = pipe_stable
      end
      if project["job"]
        project["job"]["id"] = remap.fetch(project["job"]["id"], project["job"]["id"])
      end
    end

    job_suffix = {
      "job-bigbuck-platform-0001" => "platform",
      "job-bigbuck-ae-0001" => "ae"
    }
    project_suffix = {
      "project-platform-pool-0001" => "platform",
      "project-ae-pool-0001" => "ae"
    }

    payload["applications"].each_with_index do |app, idx|
      person_id = remap.fetch(app["person_id"])
      job_id = remap.fetch(app["job_id"])
      person_key = payload["people"].find { |p| p["id"] == person_id }&.dig("key") || format("app%03d", idx + 1)
      suffix = job_suffix[job_id] || "job"
      stable = "app-#{person_key}-#{suffix}-0001"
      remap[app["id"]] = stable
      app["id"] = stable
      app["person_id"] = person_id
      app["job_id"] = job_id
      app["pipeline_id"] = remap.fetch(app["pipeline_id"]) if app["pipeline_id"]
    end

    payload["offers"].each_with_index do |offer, idx|
      application_id = remap.fetch(offer["application_id"])
      person_app = payload["applications"].find { |a| a["id"] == application_id }
      person = payload["people"].find { |p| p["id"] == person_app&.dig("person_id") }
      stable = "offer-#{person&.dig('key') || idx}-#{offer['status']}-0001"
      remap[offer["id"]] = stable
      offer["id"] = stable
      offer["application_id"] = application_id
    end

    payload["project_members"].each_with_index do |member, idx|
      person_id = remap.fetch(member["person_id"])
      project_id = remap.fetch(member["project_id"])
      person = payload["people"].find { |p| p["id"] == person_id }
      suffix = project_suffix[project_id] || "pool"
      stable = "pm-#{person&.dig('key') || idx}-#{suffix}-0001"
      remap[member["id"]] = stable
      member["id"] = stable
      member["project_id"] = project_id
      member["person_id"] = person_id
      member["pipeline_id"] = remap.fetch(member["pipeline_id"]) if member["pipeline_id"] && remap[member["pipeline_id"]]
      if member["converted_application_id"]
        member["converted_application_id"] = remap.fetch(member["converted_application_id"], member["converted_application_id"])
      end
    end

    Array(payload["interviewer_profiles"]).each do |profile|
      role = payload["users"].find { |_k, u| u["id"] == remap[profile["user_id"]] || u["id"] == profile["user_id"] }&.first
      role ||= "user"
      stable = "iprofile-#{role.tr('_', '-')}-0001"
      remap[profile["id"]] = stable
      profile["id"] = stable
      profile["user_id"] = remap.fetch(profile["user_id"])
    end

    Array(payload["interviewer_pools"]).each do |pool|
      stable = "ipool-#{pool['key']}-0001"
      remap[pool["id"]] = stable
      pool["id"] = stable
      pool["member_user_ids"] = Array(pool["member_user_ids"]).map { |uid| remap.fetch(uid) }
    end

    Array(payload["calendar_connections"]).each_with_index do |conn, idx|
      if conn["kind"] == "domain"
        stable = "cal-domain-0001"
      else
        role = payload["users"].find { |_k, u| u["id"] == remap[conn["user_id"]] || u["id"] == conn["user_id"] }&.first
        stable = "cal-#{(role || idx).to_s.tr('_', '-')}-0001"
      end
      remap[conn["id"]] = stable
      conn["id"] = stable
      conn["user_id"] = remap.fetch(conn["user_id"]) if conn["user_id"]
    end

    Array(payload["hiring_teams"]).each do |team|
      job_id = remap.fetch(team["job_id"])
      suffix = job_suffix[job_id] || "job"
      stable = "hteam-#{suffix}-0001"
      remap[team["id"]] = stable
      team["id"] = stable
      team["job_id"] = job_id
      Array(team["members"]).each_with_index do |member, idx|
        member_stable = "htm-#{suffix}-#{member['team_role']}-0001"
        # Disambiguate duplicate roles on one team.
        member_stable = "htm-#{suffix}-#{member['team_role']}-#{idx + 1}-0001" if team["members"].count { |m| m["team_role"] == member["team_role"] } > 1
        remap[member["id"]] = member_stable
        member["id"] = member_stable
        member["user_id"] = remap.fetch(member["user_id"])
      end
    end

    Array(payload["rooms"]).each do |room|
      stable = "room-#{room['key']}-0001"
      remap[room["id"]] = stable
      room["id"] = stable
    end

    Array(payload["holidays"]).each_with_index do |holiday, idx|
      stable = "holiday-#{idx + 1}-0001"
      remap[holiday["id"]] = stable
      holiday["id"] = stable
    end

    payload
  end

  private

  def seed_project_member!(project, person, stage)
    member = ProjectMember.create!(
      project: project,
      person: person,
      pipeline: project.pipeline,
      pipeline_version: project.pipeline.version,
      current_stage_key: project.pipeline.first_stage_key,
      status: "active",
      version: 1
    )
    if stage != member.current_stage_key
      SubjectTransitions.move(subject: member, to_stage_key: stage, reason: "seed")
    end
    member.reload
  end

  # Demo reset only: audit_events is append-only (trigger), so deleting a demo
  # organization's history needs the explicit purge flag for this connection.
  def purge_history!(org_id)
    AuditPurge.with_access do
      AuditEvent.unscoped.where(organization_id: org_id).delete_all
      OutboxEvent.unscoped.where(organization_id: org_id).delete_all
    end
  end

  def wipe_existing!
    org = Organization.find_by(slug: @slug)
    return unless org

    AuditPurge.ensure_access!
    Current.organization_id = org.id
    org_id = org.id
    TimelineEvent.unscoped.where(organization_id: org_id).delete_all
    ScorecardRubric.unscoped.where(organization_id: org_id).delete_all
    purge_history!(org_id)
    Communication.unscoped.where(organization_id: org_id).delete_all
    ScheduledMessage.unscoped.where(organization_id: org_id).delete_all
    SequenceEnrollment.unscoped.where(organization_id: org_id).delete_all
    Sequence.unscoped.where(organization_id: org_id).delete_all
    MessageTemplate.unscoped.where(organization_id: org_id).delete_all
    Mailbox.unscoped.where(organization_id: org_id).delete_all
    Scorecard.unscoped.where(organization_id: org_id).delete_all
    Interview.unscoped.where(organization_id: org_id).delete_all
    AvailabilityRequest.unscoped.where(organization_id: org_id).delete_all
    SchedulingLink.unscoped.where(organization_id: org_id).delete_all
    InterviewerBlock.unscoped.where(organization_id: org_id).delete_all
    InterviewerPoolMember.unscoped.where(organization_id: org_id).delete_all
    InterviewerPool.unscoped.where(organization_id: org_id).delete_all
    InterviewerProfile.unscoped.where(organization_id: org_id).delete_all
    CalendarConnection.unscoped.where(organization_id: org_id).delete_all
    Holiday.unscoped.where(organization_id: org_id).delete_all
    Room.unscoped.where(organization_id: org_id).delete_all
    HiringTeamMember.unscoped.where(organization_id: org_id).delete_all
    HiringTeam.unscoped.where(organization_id: org_id).delete_all
    OfferTemplate.unscoped.where(organization_id: org_id).delete_all
    Approval.unscoped.where(organization_id: org_id).delete_all
    ApprovalPolicyStep.unscoped.where(organization_id: org_id).delete_all
    ApprovalPolicy.unscoped.where(organization_id: org_id).delete_all
    # Offer responses are append-only at the model layer, so skip callbacks.
    OfferResponse.unscoped.where(organization_id: org_id).delete_all
    Offer.unscoped.where(organization_id: org_id).find_each(&:destroy!)
    Application.unscoped.where(organization_id: org_id).find_each(&:destroy!)
    StageTransition.unscoped.where(organization_id: org_id).delete_all
    ProjectMember.unscoped.where(organization_id: org_id).delete_all
    Project.unscoped.where(organization_id: org_id).delete_all
    Consent.unscoped.where(organization_id: org_id).delete_all
    NoticeReceipt.unscoped.where(organization_id: org_id).delete_all
    NoticeVersion.unscoped.where(organization_id: org_id).delete_all
    Notice.unscoped.where(organization_id: org_id).delete_all
    ConsentPurpose.unscoped.where(organization_id: org_id).delete_all
    CompliancePolicy.unscoped.where(organization_id: org_id).delete_all
    CustomFieldValue.unscoped.where(organization_id: org_id).delete_all
    CustomField.unscoped.where(organization_id: org_id).delete_all
    Document.unscoped.where(organization_id: org_id).delete_all
    PersonContactPoint.unscoped.where(organization_id: org_id).delete_all
    PersonAffiliation.unscoped.where(organization_id: org_id).delete_all
    Company.unscoped.where(organization_id: org_id).delete_all
    MergeSuggestion.unscoped.where(organization_id: org_id).delete_all
    WebhookEndpoint.unscoped.where(organization_id: org_id).delete_all
    VerifiedDomain.unscoped.where(organization_id: org_id).delete_all
    Person.unscoped.where(organization_id: org_id).find_each(&:destroy!)
    Job.unscoped.where(organization_id: org_id).find_each(&:destroy!)
    ApplicationQuestionTemplate.unscoped.where(organization_id: org_id).delete_all
    Pipeline.unscoped.where(organization_id: org_id).find_each(&:destroy!)
    PipelineTemplate.unscoped.where(organization_id: org_id).find_each(&:destroy!)
    EntityDimensionValue.unscoped.where(organization_id: org_id).delete_all
    ApiCredential.unscoped.where(organization_id: org_id).delete_all
    Agent.unscoped.where(organization_id: org_id).delete_all
    MembershipScope.unscoped.where(organization_id: org_id).delete_all
    Membership.unscoped.where(organization_id: org_id).delete_all
    RolePermission.unscoped.where(organization_id: org_id).delete_all
    Role.unscoped.where(organization_id: org_id).delete_all
    DimensionValue.unscoped.where(organization_id: org_id).delete_all
    Dimension.unscoped.where(organization_id: org_id).delete_all
    Organization.unscoped.where(id: org_id).delete_all
    Current.reset
  rescue StandardError
    Current.reset
    raise
  end

  def reload_existing(org)
    Current.organization_id = org.id
    roles = Role.where(organization_id: org.id).index_by(&:key)
    users = {
      "admin" => User.find_by!(email: "admin@bigbuck.test"),
      "recruiter" => User.find_by!(email: "recruiter@bigbuck.test"),
      "hiring_manager" => User.find_by!(email: "hm@bigbuck.test"),
      "sales_hm" => User.find_by!(email: "sales.hm@bigbuck.test"),
      "interviewer_eng" => User.find_by!(email: "ivy.interviewer@bigbuck.test"),
      "interviewer_sales" => User.find_by!(email: "owen.interviewer@bigbuck.test"),
      "non_user" => User.find_by!(email: "outsider@example.com"),
      "owner" => Membership.find_by!(organization_id: org.id, role: roles.fetch("owner")).user
    }
    memberships = {
      "admin" => Membership.find_by!(user: users["admin"], organization_id: org.id),
      "recruiter" => Membership.find_by!(user: users["recruiter"], organization_id: org.id),
      "hiring_manager" => Membership.find_by!(user: users["hiring_manager"], organization_id: org.id),
      "sales_hm" => Membership.find_by!(user: users["sales_hm"], organization_id: org.id),
      "interviewer_eng" => Membership.find_by!(user: users["interviewer_eng"], organization_id: org.id),
      "interviewer_sales" => Membership.find_by!(user: users["interviewer_sales"], organization_id: org.id)
    }
    department_dim = Dimension.find_by(key: "department")
    location_dim = Dimension.find_by(key: "location")
    people = Person.order(:created_at).map { |p|
      dept = department_dim && EntityDimensionValue.find_by(
        entity_type: "Person", entity_id: p.id, dimension_id: department_dim.id
      )&.dimension_value&.key
      loc = location_dim && EntityDimensionValue.find_by(
        entity_type: "Person", entity_id: p.id, dimension_id: location_dim.id
      )&.dimension_value&.key
      key = self.class.candidates.find { |c| c[:email] == p.primary_email }&.dig(:key)
      { key: key, person: p, department: dept, location: loc }
    }
    Result.new(
      organization: org,
      roles: roles,
      dimensions: {
        department: department_dim,
        location: location_dim
      },
      department_values: DimensionValue.joins(:dimension).where(dimensions: { key: "department" }).index_by(&:key),
      location_values: location_dim ? DimensionValue.where(dimension: location_dim).index_by(&:key) : {},
      users: users,
      memberships: memberships,
      people: people,
      jobs: Job.includes(:pipeline).order(:title).to_a,
      applications: Application.order(:created_at).to_a,
      offers: Offer.includes(:current_version).order(:created_at).to_a,
      projects: Project.includes(:pipeline, :job).order(:created_at).to_a,
      project_members: ProjectMember.order(:created_at).to_a,
      interviewer_profiles: InterviewerProfile.order(:created_at).to_a,
      interviewer_pools: InterviewerPool.includes(:members).order(:created_at).to_a,
      calendar_connections: CalendarConnection.order(:created_at).to_a,
      hiring_teams: HiringTeam.includes(:members).order(:created_at).to_a,
      rooms: Room.order(:created_at).to_a,
      holidays: Holiday.order(:observed_on).to_a
    )
  end

  def build!
    provisioned = OrganizationProvisioner.call(
      name: ORG_NAME,
      slug: @slug,
      owner_email: "owner@bigbuck.test",
      owner_name: "Big Buck Owner"
    )
    org = provisioned[:organization]
    Current.organization_id = org.id
    Current.actor_id = provisioned[:user].id
    org.merge_settings!(
      "careers_hero_image_url" => "/careers-canopy.avif",
      "careers_headline" => "Open roles",
      "careers_subcopy" => "Build with us at Big Buck.",
      # Seed includes hired applications without walking the full offer-accept path.
      "hire_requires_accepted_offer" => false
    )

    roles = provisioned[:roles]
    department = provisioned[:dimensions][:department]
    location_dim = provisioned[:dimensions][:location]
    eng = DimensionValue.create!(dimension: department, key: "engineering", label: "Engineering")
    sales = DimensionValue.create!(dimension: department, key: "sales", label: "Sales")
    location_values = LOCATIONS.to_h do |loc|
      [ loc[:key], DimensionValue.create!(dimension: location_dim, key: loc[:key], label: loc[:label]) ]
    end

    admin_user = User.find_or_create_by!(email: "admin@bigbuck.test") { |u| u.name = "Ada Admin" }
    recruiter_user = User.find_or_create_by!(email: "recruiter@bigbuck.test") { |u| u.name = "Riley Recruiter" }
    hm_user = User.find_or_create_by!(email: "hm@bigbuck.test") { |u| u.name = "Harper Manager" }
    sales_hm_user = User.find_or_create_by!(email: "sales.hm@bigbuck.test") { |u| u.name = "Sasha Sales Manager" }
    eng_interviewer = User.find_or_create_by!(email: "ivy.interviewer@bigbuck.test") { |u| u.name = "Ivy Interviewer" }
    sales_interviewer = User.find_or_create_by!(email: "owen.interviewer@bigbuck.test") { |u| u.name = "Owen Interviewer" }
    non_user = User.find_or_create_by!(email: "outsider@example.com") { |u| u.name = "No Membership" }
    owner_user = provisioned[:user]

    admin_membership = Membership.create!(user: admin_user, role: roles.fetch("admin"), status: "active")
    recruiter_membership = Membership.create!(user: recruiter_user, role: roles.fetch("recruiter"), status: "active")
    hm_membership = Membership.create!(user: hm_user, role: roles.fetch("hiring_manager"), status: "active")
    sales_hm_membership = Membership.create!(user: sales_hm_user, role: roles.fetch("hiring_manager"), status: "active")
    eng_interviewer_membership = Membership.create!(user: eng_interviewer, role: roles.fetch("recruiter"), status: "active")
    sales_interviewer_membership = Membership.create!(user: sales_interviewer, role: roles.fetch("recruiter"), status: "active")
    MembershipScope.create!(
      membership: hm_membership,
      dimension: department,
      dimension_value: eng,
      include_descendants: true
    )
    MembershipScope.create!(
      membership: sales_hm_membership,
      dimension: department,
      dimension_value: sales,
      include_descendants: true
    )

    interviewer_profiles = [
      seed_interviewer_profile!(owner_user, time_zone: "America/Los_Angeles", working_hours: STANDARD_HOURS, daily_limit: 3, weekly_limit: 10),
      seed_interviewer_profile!(admin_user, time_zone: "America/Los_Angeles", working_hours: STANDARD_HOURS, daily_limit: 4, weekly_limit: 12),
      seed_interviewer_profile!(recruiter_user, time_zone: "America/New_York", working_hours: STANDARD_HOURS, daily_limit: 6, weekly_limit: 20, buffer_minutes: 10),
      seed_interviewer_profile!(hm_user, time_zone: "America/Los_Angeles", working_hours: LATE_HOURS, daily_limit: 3, weekly_limit: 8, buffer_minutes: 20),
      seed_interviewer_profile!(sales_hm_user, time_zone: "America/Chicago", working_hours: STANDARD_HOURS, daily_limit: 4, weekly_limit: 12),
      seed_interviewer_profile!(eng_interviewer, time_zone: "Europe/Berlin", working_hours: EU_HOURS, daily_limit: 5, weekly_limit: 15),
      seed_interviewer_profile!(sales_interviewer, time_zone: "America/New_York", working_hours: STANDARD_HOURS, daily_limit: 5, weekly_limit: 15, paused: false)
    ]

    calendar_connections = [
      CalendarConnection.create!(kind: "domain", calendar_id: "domain:bigbuck.test", secret_ref: "sm://bigbuck-domain-cal", status: "connected"),
      seed_calendar!(owner_user),
      seed_calendar!(admin_user),
      seed_calendar!(recruiter_user),
      seed_calendar!(hm_user),
      seed_calendar!(sales_hm_user),
      seed_calendar!(eng_interviewer),
      seed_calendar!(sales_interviewer)
    ]

    eng_interviewer_pool = InterviewerPool.create!(key: "eng-panel", name: "Engineering panel")
    sales_interviewer_pool = InterviewerPool.create!(key: "sales-panel", name: "Sales panel")
    [
      [ eng_interviewer_pool, hm_user, false ],
      [ eng_interviewer_pool, eng_interviewer, false ],
      [ eng_interviewer_pool, recruiter_user, true ],
      [ sales_interviewer_pool, sales_hm_user, false ],
      [ sales_interviewer_pool, sales_interviewer, false ],
      [ sales_interviewer_pool, recruiter_user, false ]
    ].each do |pool, user, trainee|
      InterviewerPoolMember.create!(interviewer_pool: pool, user: user, trainee: trainee, paused: false)
    end
    interviewer_pools = [ eng_interviewer_pool, sales_interviewer_pool ]

    InterviewerBlock.create!(
      user: hm_user,
      starts_at: 1.week.from_now.change(hour: 12, min: 0),
      ends_at: 1.week.from_now.change(hour: 13, min: 0),
      reason: "Weekly staff sync"
    )

    rooms = [
      Room.create!(key: "sf-board", name: "SF Boardroom", resource_email: "sf-board@resource.bigbuck.test", location_key: "sf", capacity: 8),
      Room.create!(key: "nyc-huddle", name: "NYC Huddle", resource_email: "nyc-huddle@resource.bigbuck.test", location_key: "nyc", capacity: 4),
      Room.create!(key: "remote-meet", name: "Remote Meet", resource_email: "remote-meet@resource.bigbuck.test", location_key: "remote", capacity: 12)
    ]
    holidays = [
      Holiday.create!(name: "Company Day", observed_on: Date.new(Date.current.year, 12, 24), location_key: nil),
      Holiday.create!(name: "SF Office Closure", observed_on: Date.new(Date.current.year, 7, 3), location_key: "sf")
    ]

    companies = COMPANIES.to_h do |c|
      [ c[:key], Company.create!(name: c[:name], domain: c[:domain], industry: c[:industry], employee_band: c[:employee_band]) ]
    end

    source_field = CustomField.create!(
      entity: "person", key: "source", label: "Source", field_type: "string", data_class: "internal"
    )
    years_field = CustomField.create!(
      entity: "person", key: "years_experience", label: "Years of experience",
      field_type: "number", data_class: "internal"
    )
    relocate_field = CustomField.create!(
      entity: "person", key: "willing_to_relocate", label: "Willing to relocate",
      field_type: "boolean", data_class: "internal"
    )

    processing_purpose = ConsentPurpose.create!(
      key: "data-processing", label: "Data processing", lawful_basis: "legitimate_interest",
      description: "Process candidate data for recruiting"
    )
    outreach_purpose = ConsentPurpose.create!(
      key: "outreach", label: "Outreach", lawful_basis: "legitimate_interest",
      description: "Email candidates about roles"
    )
    privacy_notice = Notice.create!(key: "privacy-notice", name: "Privacy notice")
    privacy_version = privacy_notice.publish!(locale: "en", body: "Big Buck processes your application data to evaluate candidacy.")

    seed_scorecard_rubrics!
    eng_template = PipelineTemplate.create!(key: "bigbuck-engineering", name: "Engineering", object_type: "job")
    eng_template.publish!(stages: self.class.job_stages_for(:eng))
    sales_template = PipelineTemplate.create!(key: "bigbuck-sales", name: "Sales", object_type: "job")
    sales_template.publish!(stages: self.class.job_stages_for(:sales))
    eng_pipeline = Pipeline.build_from_template!(template: eng_template)
    sales_pipeline = Pipeline.build_from_template!(template: sales_template)
    eng_job = Job.create!(title: "Platform Engineer", status: "active", pipeline: eng_pipeline, careers_visibility: "both")
    sales_job = Job.create!(title: "Account Executive", status: "active", pipeline: sales_pipeline, careers_visibility: "both")
    EntityDimensionValue.create!(entity_type: "Job", entity_id: eng_job.id, dimension: department, dimension_value: eng)
    EntityDimensionValue.create!(entity_type: "Job", entity_id: sales_job.id, dimension: department, dimension_value: sales)

    Posting.create!(job: eng_job, title: "Platform Engineer", status: "published")
    Posting.create!(job: sales_job, title: "Account Executive", status: "published")

    mailbox = Mailbox.create!(
      kind: "shared",
      email: "recruiting@bigbuck.test",
      status: "connected",
      secret_ref: "sm://bigbuck-shared"
    )
    Mailbox.create!(
      kind: "personal",
      email: "recruiter@bigbuck.test",
      user: recruiter_user,
      status: "connected",
      secret_ref: "sm://bigbuck-recruiter"
    )
    MessageTemplate.create!(
      key: "outreach-1", message_type: "sequence",
      subject: "Hi {{ person.display_name }} — Big Buck",
      body: "Interested in chatting about opportunities at Big Buck?"
    )
    Sequence.create!(
      key: "default-outreach",
      name: "Default outreach",
      steps: [ { "type" => "email", "template_key" => "outreach-1" } ],
      status: "active"
    )
    GoogleSignIn.verify_domain!(domain: "bigbuck.test")
    default_offer_policy = ApprovalPolicy.create!(
      key: "default-offers", name: "Default offers", applies_to: "offer",
      priority: 0, is_catch_all: true
    )
    ApprovalPolicyStep.create!(
      approval_policy: default_offer_policy,
      position: 1,
      name: "Hiring manager",
      mode: "sequential",
      approvers: [ "role:hiring-manager" ],
      require_mode: "all",
      # A job without a hiring manager still needs a person to approve its offers.
      if_no_approver: "fallback",
      fallback_approver: "org-role:owner"
    )
    OfferTemplate.create!(
      key: "us-ft", name: "US full-time",
      body: "Dear {{ candidate.display_name }}, we are pleased to offer you the {{ job.title }} role at {{ offer.fields.base_salary }} {{ offer.fields.currency }}.",
      expires_after_days: 7
    )

    eng_hiring_team = HiringTeam.create!(job: eng_job)
    HiringTeamMember.create!(hiring_team: eng_hiring_team, user: hm_user, team_role: "hiring-manager")
    HiringTeamMember.create!(hiring_team: eng_hiring_team, user: recruiter_user, team_role: "recruiter")
    HiringTeamMember.create!(hiring_team: eng_hiring_team, user: eng_interviewer, team_role: "interviewer")
    HiringTeamMember.create!(hiring_team: eng_hiring_team, user: admin_user, team_role: "coordinator")

    sales_hiring_team = HiringTeam.create!(job: sales_job)
    HiringTeamMember.create!(hiring_team: sales_hiring_team, user: sales_hm_user, team_role: "hiring-manager")
    HiringTeamMember.create!(hiring_team: sales_hiring_team, user: recruiter_user, team_role: "recruiter")
    HiringTeamMember.create!(hiring_team: sales_hiring_team, user: sales_interviewer, team_role: "interviewer")
    hiring_teams = [ eng_hiring_team, sales_hiring_team ]

    sourcing_template = PipelineTemplate.create!(
      key: "sourcing-default", name: "Sourcing", object_type: "project"
    )
    sourcing_template.publish!(stages: [
      { "key" => "prospect", "name" => "Prospect", "type" => "source" },
      { "key" => "reached-out", "name" => "Reached out", "type" => "outreach" },
      { "key" => "replied", "name" => "Replied", "type" => "outreach" },
      { "key" => "ready", "name" => "Ready", "type" => "ready" }
    ])
    platform_pool_pipeline = Pipeline.build_from_template!(template: sourcing_template, scope: "project")
    sales_pool_pipeline = Pipeline.build_from_template!(template: sourcing_template, scope: "project")
    platform_pool = Project.create!(
      name: "Platform warm bench",
      pipeline: platform_pool_pipeline,
      job: eng_job
    )
    sales_pool = Project.create!(
      name: "AE talent pool",
      pipeline: sales_pool_pipeline,
      job: sales_job
    )

    applications = []
    offers = []
    project_members = []
    people = []
    offer_plan = self.class.offer_status_plan
    staff = {
      recruiter: recruiter_user,
      hiring_manager: hm_user,
      eng_interviewer: eng_interviewer,
      sales_hm: sales_hm_user,
      sales_interviewer: sales_interviewer
    }

    previous_gmail = GmailClient.backend
    GmailClient.backend = GmailClient::Fake.new
    begin
      self.class.candidates.each_with_index do |spec, index|
        loc_meta = LOCATIONS.find { |l| l[:key] == spec[:location] } || LOCATIONS.first
        person = Person.create!(
          display_name: spec[:name],
          primary_email: PersonContactPoint.normalize_email(spec[:email]),
          primary_phone: PersonContactPoint.normalize_phone(spec[:phone]),
          lifecycle_stage: spec[:stage],
          visibility: spec[:visibility],
          country: spec[:country] || loc_meta[:country],
          region: spec[:region] || loc_meta[:region]
        )

        PersonContactPoint.create!(
          person: person, kind: "email", value: spec[:email], primary: true, verified: index.even?
        )
        PersonContactPoint.create!(
          person: person, kind: "phone", value: spec[:phone], primary: true, verified: (index % 3).zero?
        )
        PersonContactPoint.create!(
          person: person, kind: "url", value: "https://linkedin.com/in/#{spec[:key]}", primary: false
        )

        company = companies.fetch(spec[:company] || COMPANIES.first[:key])
        PersonAffiliation.create!(
          person: person,
          company: company,
          title: spec[:title] || TITLES.first,
          current: spec[:stage] != "alumni",
          started_on: Date.new(2020, 1, 1) + index.months,
          ended_on: (spec[:stage] == "alumni" ? Date.new(2025, 6, 1) : nil)
        )

        Document.create!(
          person: person,
          filename: "#{spec[:key]}-resume.pdf",
          content_type: "application/pdf",
          byte_size: 10_000 + index,
          checksum: Digest::SHA256.hexdigest("resume-#{spec[:key]}"),
          storage_key: "seed/#{org.id}/#{spec[:key]}/resume.pdf",
          scan_status: index % 7 == 0 ? "pending" : "clean",
          visibility: "internal"
        )

        if spec[:department]
          value = spec[:department] == "engineering" ? eng : sales
          EntityDimensionValue.create!(
            entity_type: "Person", entity_id: person.id,
            dimension: department, dimension_value: value
          )
        end
        if spec[:location] && location_values[spec[:location]]
          EntityDimensionValue.create!(
            entity_type: "Person", entity_id: person.id,
            dimension: location_dim, dimension_value: location_values[spec[:location]]
          )
        end

        CustomFieldValue.create!(
          custom_field: source_field, entity_type: "Person", entity_id: person.id,
          value_text: spec[:source].to_s
        )
        CustomFieldValue.create!(
          custom_field: years_field, entity_type: "Person", entity_id: person.id,
          value_number: spec[:years_experience]
        )
        CustomFieldValue.create!(
          custom_field: relocate_field, entity_type: "Person", entity_id: person.id,
          value_json: { "value" => !!spec[:willing_to_relocate] }
        )

        NoticeReceipt.create!(
          person: person,
          notice_version: privacy_version,
          shown_via: "apply_form",
          locale: "en",
          ip_address: "203.0.113.#{(index % 200) + 1}",
          user_agent: "BigBuckSeed/1.0",
          shown_at: Time.current - index.hours,
          created_at: Time.current - index.hours
        )
        Consent.create!(
          person: person,
          consent_purpose: processing_purpose,
          notice_version: privacy_version,
          lawful_basis: processing_purpose.lawful_basis,
          status: "granted",
          captured_via: "apply_form",
          captured_at: Time.current - index.hours,
          ip_address: "203.0.113.#{(index % 200) + 1}",
          user_agent: "BigBuckSeed/1.0",
          evidence_json: { "locale" => "en", "seed" => true },
          created_at: Time.current - index.hours
        )
        Consent.create!(
          person: person,
          consent_purpose: outreach_purpose,
          notice_version: privacy_version,
          lawful_basis: outreach_purpose.lawful_basis,
          status: "granted",
          captured_via: "recorded_by_user",
          captured_at: Time.current - index.hours,
          created_at: Time.current - index.hours
        )

        row = { key: spec[:key], person: person, department: spec[:department], location: spec[:location] }
        people << row

        case spec[:track]
        when :application
          job = spec[:job] == :sales ? sales_job : eng_job
          app = ApplicationCreator.call(job: job, person: person)
          target_stage = spec[:app_stage] || "applied"
          anchor = Time.current - (36 + (index % 12)).days
          if target_stage.in?(INTERVIEW_OR_LATER)
            if app.current_stage_key != "onsite"
              SubjectTransitions.move(subject: app, to_stage_key: "onsite", reason: "Scheduling the interview loop")
              app.reload
            end
            seed_interview_loop!(app, spec, index, job: job, staff: staff, anchor: anchor)
            if target_stage == "offer"
              SubjectTransitions.move(subject: app, to_stage_key: "offer", reason: "Interview loop complete")
              app.reload
            end
          elsif target_stage != app.current_stage_key
            SubjectTransitions.move(subject: app, to_stage_key: target_stage, reason: "Advanced after review")
            app.reload
          end

          if spec[:has_scheduling_link]
            SchedulingLink.create!(
              application: app,
              kind: "self_schedule",
              interview_keys: [ "onsite" ],
              expires_at: 14.days.from_now
            )
          end

          if spec[:has_offer]
            fields = spec[:offer_fields] || {
              "base_salary" => 140_000 + (index * 1_000),
              "currency" => "USD",
              "equity" => format("%.2f%%", 0.05 + (index % 10) / 100.0),
              "start_date" => (Date.current + 30 + index).iso8601
            }
            offer = OfferSubmitter.create_draft!(application: app, fields: fields)
            status = offer_plan.fetch(spec[:email])
            approver = spec[:job] == :sales ? sales_hm_user : hm_user
            offer = advance_offer!(offer, status, application: app, approver: approver)
            offers << offer.reload
            seed_offer_activity!(person, offer, job, anchor + 20.days)
          end

          case spec[:app_status]
          when "rejected"
            SubjectTransitions.reject(subject: app, reason: "Not moving forward after the review")
          when "withdrawn"
            SubjectTransitions.withdraw(subject: app, reason: "Candidate withdrew")
          when "hired"
            # hire_requires_accepted_offer is off, so a hire can land without an
            # accepted offer. Candidates who do have an accepted offer are hired
            # after that acceptance.
            SubjectTransitions.hire(subject: app)
          end
          app.reload
          seed_application_activity!(person, app, spec, job, anchor)
          applications << app
        when :pool
          pool = spec[:pool] == :sales ? sales_pool : platform_pool
          member = seed_project_member!(pool, person, spec[:pool_stage] || "prospect")
          project_members << member
          seed_sourcing_activity!(person, pool, spec, Time.current - (20 + index).days)
        else
          record_timeline!(
            person,
            "profile.noted",
            {
              "lifecycle_stage" => spec[:stage],
              "summary" => "#{spec[:name]} is #{spec[:stage]} (#{spec[:title]}) and is not in an open application."
            },
            Time.current - (15 + index).days
          )
        end

        if spec[:has_communication]
          first = spec[:name].split.first
          if spec[:app_stage].in?(INTERVIEW_OR_LATER)
            subject = "#{first}, your #{spec[:job] == :sales ? 'AE' : 'engineering'} loop"
            body = "Hi #{first} — thanks for making the time. The panel filed scorecards after each conversation, and we'll write with next steps."
          else
            subject = "Thanks for connecting, #{first}"
            body = "Hi #{first} — following up from Big Buck recruiting about the #{spec[:title]} opening."
          end
          MessageSender.send_now!(
            mailbox: mailbox,
            person: person,
            subject: subject,
            body: body,
            message_type: spec[:track] == :application ? "confirmation" : "outreach"
          )
        elsif index % 4 == 0
          Communication.create!(
            person: person,
            mailbox: mailbox,
            direction: "outbound",
            channel: "email",
            subject: "Big Buck — #{spec[:title]}",
            body: "Hello #{spec[:name].split.first}, thanks for your interest in the #{spec[:title]} work. Reply if you want to compare notes.",
            provider_message_id: "seed-msg-#{spec[:key]}",
            thread_id: "seed-thread-#{spec[:key]}",
            message_type: "outreach",
            status: "sent"
          )
          TimelineEvent.create!(
            person_id: person.id,
            event_type: "communication.sent",
            payload: {
              "subject" => "Big Buck — #{spec[:title]}",
              "summary" => "Wrote #{spec[:name].split.first} about the #{spec[:title]} opening."
            },
            occurred_at: Time.current - index.hours
          )
        end
      end
    ensure
      GmailClient.backend = previous_gmail
    end

    # One merge-suggestion pair for duplicate-detection coverage.
    MergeSuggestion.create!(
      person_a_id: people.fetch(0)[:person].id,
      person_b_id: people.fetch(1)[:person].id,
      reason: "similar_name_seed",
      status: "open"
    )

    Result.new(
      organization: org,
      roles: roles,
      dimensions: provisioned[:dimensions],
      department_values: { "engineering" => eng, "sales" => sales },
      location_values: location_values,
      users: {
        "owner" => owner_user,
        "admin" => admin_user,
        "recruiter" => recruiter_user,
        "hiring_manager" => hm_user,
        "sales_hm" => sales_hm_user,
        "interviewer_eng" => eng_interviewer,
        "interviewer_sales" => sales_interviewer,
        "non_user" => non_user
      },
      memberships: {
        "owner" => provisioned[:membership],
        "admin" => admin_membership,
        "recruiter" => recruiter_membership,
        "hiring_manager" => hm_membership,
        "sales_hm" => sales_hm_membership,
        "interviewer_eng" => eng_interviewer_membership,
        "interviewer_sales" => sales_interviewer_membership
      },
      people: people,
      jobs: [ eng_job, sales_job ],
      applications: applications,
      offers: offers,
      projects: [ platform_pool, sales_pool ],
      project_members: project_members,
      interviewer_profiles: interviewer_profiles,
      interviewer_pools: interviewer_pools.map { |pool| InterviewerPool.includes(:members).find(pool.id) },
      calendar_connections: calendar_connections,
      hiring_teams: hiring_teams.map { |team| HiringTeam.includes(:members).find(team.id) },
      rooms: rooms,
      holidays: holidays
    )
  end

  def seed_scorecard_rubrics!
    self.class::LOOP_RUBRICS.each do |key, spec|
      ScorecardRubric.create!(
        key: key,
        name: spec["name"],
        guidance: spec["guidance"],
        attributes_spec: spec["attributes"]
      )
    end
  end

  def seed_interview_loop!(app, spec, index, job:, staff:, anchor:)
    loop_steps = self.class.loop_for(spec[:job])
    company = COMPANIES.find { |row| row[:key] == spec[:company] }&.dig(:name) || "their last team"
    loop_steps.each_with_index do |step, step_index|
      interviewers = step[:interviewers].map { |role| staff.fetch(role) }
      starts = anchor + (step_index * 3).days + 10.hours
      interview = Interview.create!(
        application: app,
        stage_key: "onsite",
        interview_key: step[:key],
        status: "completed",
        starts_at: starts,
        ends_at: starts + step[:minutes].minutes,
        interviewer_user_ids: interviewers.map(&:id)
      )
      rating = RATINGS[(index + step_index) % RATINGS.size]
      interviewers.each_with_index do |interviewer, interviewer_index|
        role = step[:interviewers][interviewer_index]
        ScorecardSubmitter.call(
          interview: interview,
          user: interviewer,
          rating: rating,
          notes: scorecard_note(step, spec, company, rating, role, interviewer),
          attribute_ratings: attribute_ratings_for(step[:rubric], rating, interviewer_index)
        )
      end
      record_timeline!(
        app.person,
        "interview.completed",
        {
          "interview_key" => step[:key],
          "interview_name" => step[:name],
          "job_title" => job.title,
          "summary" => "#{spec[:name].split.first}'s #{step[:name].downcase} for #{job.title} is in, with scorecards from #{interviewers.map(&:name).to_sentence}."
        },
        starts + step[:minutes].minutes
      )
    end
    record_timeline!(
      app.person,
      "note.created",
      {
        "author" => "Riley Recruiter",
        "body" => "#{spec[:name].split.first} finished the #{job.title} loop (#{loop_steps.map { |step| step[:name].downcase }.to_sentence}). The write-ups are on the scorecards, not a placeholder."
      },
      anchor + (loop_steps.size * 3).days + 16.hours
    )
  end

  def scorecard_note(step, spec, company, rating, role, interviewer)
    template = SCORECARD_NOTES.fetch(step[:note_key]).fetch(rating)
    body = template
           .gsub("%{name}", spec[:name].split.first)
           .gsub("%{company}", company)
           .gsub("%{title}", (spec[:title] || "the role").to_s)
    "#{body} #{INTERVIEWER_FOCUS.fetch(role)}"
  end

  def attribute_ratings_for(rubric_key, rating, interviewer_index)
    score = RATING_SCORE.fetch(rating)
    self.class::LOOP_RUBRICS.fetch(rubric_key)["attributes"].each_with_index.to_h do |attribute, attr_index|
      delta = 0
      delta = -1 if rating == "mixed" && attr_index == interviewer_index % 2
      [ attribute["key"], [ score + delta, 1 ].max ]
    end
  end

  def advance_offer!(offer, status, application:, approver:)
    return offer if status == "draft"

    # Owner submits. The hiring manager is a different user, so the step stays
    # pending instead of skipping for self-approval.
    OfferSubmitter.submit!(offer: offer)
    offer.reload
    return offer if status == "pending_approval"

    approval = Approval.find_by!(entity_type: "Offer", entity_id: offer.id, status: "pending")
    if status == "changes_requested"
      OfferApprover.request_changes!(
        approval: approval,
        reason: "Bring the equity in line with the band for this level before we send it.",
        actor_id: approver.id
      )
      return offer.reload
    end

    OfferApprover.approve!(approval: approval, actor_id: approver.id)
    offer.reload
    if status == "rescinded"
      return OfferRescinder.call(offer: offer, reason_key: "headcount_closed", actor_id: approver.id)
    end
    return offer if status == "approved"

    template = OfferTemplate.find_by!(key: "us-ft")
    OfferSender.call(
      offer: offer,
      template: template,
      to_email: application.person.primary_email
    )
    offer.reload
    case status
    when "sent"
      offer
    when "accepted"
      OfferAcceptance.record!(
        offer: offer,
        response: "accepted",
        actor_id: approver.id,
        note: "#{application.person.display_name} accepted. Start date is on the offer."
      )
      offer.reload
    when "declined"
      OfferAcceptance.record!(
        offer: offer,
        response: "declined",
        actor_id: approver.id,
        note: "#{application.person.display_name} took another offer.",
        reason_key: "competing_offer"
      )
      offer.reload
    when "expired"
      offer.current_version.update!(expires_at: 2.days.ago)
      OfferExpirer.send(:expire!, offer.id, Time.current)
      offer.reload
    else
      offer
    end
  end

  def seed_application_activity!(person, app, spec, job, anchor)
    source = spec[:source].to_s.tr("_", " ")
    record_timeline!(
      person,
      "application.submitted",
      {
        "application_id" => app.id,
        "job_title" => job.title,
        "source" => spec[:source],
        "summary" => "#{spec[:name]} applied for #{job.title} via #{source}."
      },
      anchor
    )
    return if app.current_stage_key == "applied" && app.status == "active"

    record_timeline!(
      person,
      "application.moved",
      {
        "application_id" => app.id,
        "to" => app.current_stage_key,
        "status" => app.status,
        "summary" => "#{spec[:name].split.first} is #{app.status} in #{app.current_stage_key} for #{job.title}."
      },
      anchor + 1.day
    )
  end

  def seed_offer_activity!(person, offer, job, at)
    summary = case offer.status
    when "draft" then "Draft offer for #{job.title} is with the recruiter. Not in approval yet."
    when "pending_approval" then "Offer for #{job.title} is waiting on the hiring manager."
    when "changes_requested" then "Hiring manager sent the #{job.title} offer back for a comp change."
    when "approved" then "#{job.title} offer is approved and ready to send."
    when "sent" then "#{job.title} offer went out to #{person.display_name}."
    when "accepted" then "#{person.display_name} accepted the #{job.title} offer."
    when "declined" then "#{person.display_name} declined the #{job.title} offer for a competing role."
    when "expired" then "The #{job.title} offer to #{person.display_name} expired before they signed."
    when "rescinded" then "We rescinded the #{job.title} offer after the headcount closed."
    else "Offer for #{job.title} is #{offer.status}."
    end
    record_timeline!(
      person,
      "offer.#{offer.status}",
      {
        "offer_id" => offer.id,
        "status" => offer.status,
        "job_title" => job.title,
        "summary" => summary
      },
      at
    )
  end

  def seed_sourcing_activity!(person, pool, spec, at)
    stage = spec[:pool_stage] || "prospect"
    record_timeline!(
      person,
      "sourcing.added",
      {
        "project" => pool.name,
        "stage" => stage,
        "summary" => "Added #{person.display_name} to #{pool.name} at #{stage.tr('-', ' ')}."
      },
      at
    )
  end

  def record_timeline!(person, event_type, payload, occurred_at)
    TimelineEvent.create!(
      person: person,
      event_type: event_type,
      payload: payload,
      occurred_at: occurred_at
    )
  end

  def seed_interviewer_profile!(user, time_zone:, working_hours:, daily_limit: 4, weekly_limit: 15, buffer_minutes: 15, paused: false)
    InterviewerProfile.create!(
      user: user,
      time_zone: time_zone,
      working_hours: working_hours,
      daily_limit: daily_limit,
      weekly_limit: weekly_limit,
      buffer_minutes: buffer_minutes,
      paused: paused
    )
  end

  def seed_calendar!(user)
    CalendarConnection.create!(
      kind: "user",
      user_id: user.id,
      calendar_id: "primary:#{user.email}",
      secret_ref: "sm://cal/#{user.email}",
      status: "connected"
    )
  end
end
