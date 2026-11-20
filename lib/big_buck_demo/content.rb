# frozen_string_literal: true

module BigBuckDemo
  # Static demo content. Placeholders: %{name} first name, %{company}, %{title}.
  module Content
    VERSION = 2

    DEPARTMENTS = [
      [ "design", "Design" ], [ "product", "Product" ], [ "customer-success", "Customer Success" ],
      [ "marketing", "Marketing" ], [ "people", "People" ]
    ].freeze

    EXTRA_COMPANIES = [
      { key: "vandelay", name: "Meridian Freight", domain: "meridianfreight.example", industry: "Logistics", employee_band: "501-1000" },
      { key: "soylent", name: "Greenfield Foods", domain: "greenfieldfoods.example", industry: "Food Tech", employee_band: "51-200" },
      { key: "wonka", name: "Juniper & Co", domain: "juniperco.example", industry: "Consumer", employee_band: "201-500" },
      { key: "cyberdyne", name: "Parallax AI", domain: "parallax.example", industry: "AI", employee_band: "1000+" },
      { key: "tyrell", name: "Helix Biosciences", domain: "helixbio.example", industry: "Biotech", employee_band: "1000+" },
      { key: "oscorp", name: "Aldine Therapeutics", domain: "aldine.example", industry: "Pharma", employee_band: "501-1000" },
      { key: "massive", name: "Quarry Research", domain: "quarryresearch.example", industry: "Research", employee_band: "501-1000" },
      { key: "dunder", name: "Ledgerline", domain: "ledgerline.example", industry: "SaaS", employee_band: "201-500" },
      { key: "bluth", name: "Harbor Goods", domain: "harborgoods.example", industry: "E-commerce", employee_band: "51-200" },
      { key: "gringotts", name: "Copperleaf Pay", domain: "copperleaf.example", industry: "Fintech", employee_band: "201-500" },
      { key: "aperture", name: "Stratus Grid", domain: "stratusgrid.example", industry: "Cloud", employee_band: "1000+" },
      { key: "waystar", name: "Northlight Media", domain: "northlight.example", industry: "Media", employee_band: "501-1000" }
    ].freeze

    # key, name, email, role, department scope, time zone, hours, title, team label
    STAFF = [
      { key: :design_hm, email: "morgan.reyes@bigbuck.test", name: "Morgan Reyes", role: "hiring_manager", dept: "design", tz: "America/Los_Angeles", hours: :standard, title: "Head of Design" },
      { key: :design_ic, email: "devon.okafor@bigbuck.test", name: "Devon Okafor", role: "hiring_manager", dept: "design", tz: "America/New_York", hours: :standard, title: "Staff Product Designer" },
      { key: :product_hm, email: "taylor.brooks@bigbuck.test", name: "Taylor Brooks", role: "hiring_manager", dept: "product", tz: "America/Chicago", hours: :standard, title: "Director of Product" },
      { key: :product_ic, email: "ravi.menon@bigbuck.test", name: "Ravi Menon", role: "hiring_manager", dept: "product", tz: "Asia/Kolkata", hours: :late, title: "Senior Product Manager" },
      { key: :cs_hm, email: "casey.whitfield@bigbuck.test", name: "Casey Whitfield", role: "hiring_manager", dept: "customer-success", tz: "America/Denver", hours: :standard, title: "VP Customer Success" },
      { key: :cs_ic, email: "sofia.marquez@bigbuck.test", name: "Sofia Marquez", role: "hiring_manager", dept: "customer-success", tz: "America/New_York", hours: :standard, title: "Senior CSM" },
      { key: :eng_ic2, email: "elliot.wu@bigbuck.test", name: "Elliot Wu", role: "hiring_manager", dept: "engineering", tz: "America/Los_Angeles", hours: :standard, title: "Staff Engineer" },
      { key: :sourcer, email: "jordan.mercer@bigbuck.test", name: "Jordan Mercer", role: "recruiter", dept: nil, tz: "America/New_York", hours: :standard, title: "Technical Sourcer" },
      { key: :people_lead, email: "nadia.haddad@bigbuck.test", name: "Nadia Haddad", role: "admin", dept: nil, tz: "Europe/London", hours: :eu, title: "Head of People" }
    ].freeze

    REQUISITIONS = [
      { code: "REQ-1001", title: "Platform Engineer", type: "full_time", headcount: 3, status: "open", job: "Platform Engineer", owner: :hiring_manager },
      { code: "REQ-1002", title: "Account Executive", type: "full_time", headcount: 4, status: "open", job: "Account Executive", owner: :sales_hm },
      { code: "REQ-1003", title: "Senior Product Designer", type: "full_time", headcount: 2, status: "open", job: "Senior Product Designer", owner: :design_hm },
      { code: "REQ-1004", title: "Product Manager, Growth", type: "full_time", headcount: 1, status: "open", job: "Product Manager, Growth", owner: :product_hm },
      { code: "REQ-1005", title: "Customer Success Manager", type: "full_time", headcount: 3, status: "open", job: "Customer Success Manager", owner: :cs_hm },
      { code: "REQ-1006", title: "Staff Site Reliability Engineer", type: "full_time", headcount: 1, status: "open", job: "Staff Site Reliability Engineer", owner: :hiring_manager },
      { code: "REQ-1007", title: "Engineering Manager, Payments", type: "full_time", headcount: 1, status: "filled", job: "Engineering Manager, Payments", owner: :hiring_manager },
      { code: "REQ-1008", title: "Sales Development Representative", type: "full_time", headcount: 5, status: "open", job: "Sales Development Representative", owner: :sales_hm },
      { code: "REQ-1009", title: "Security Engineer", type: "full_time", headcount: 1, status: "approved", job: "Security Engineer", owner: :hiring_manager },
      { code: "REQ-1010", title: "VP of Marketing", type: "full_time", headcount: 1, status: "open", job: "VP of Marketing", owner: :owner },
      { code: "REQ-1011", title: "Chief of Staff", type: "full_time", headcount: 1, status: "pending_approval", job: "Chief of Staff", owner: :owner },
      { code: "REQ-1012", title: "Technical Recruiter", type: "full_time", headcount: 1, status: "open", job: "Technical Recruiter", owner: :people_lead },
      { code: "REQ-1013", title: "Software Engineering Intern, Summer 2027", type: "intern", headcount: 6, status: "open", job: "Software Engineering Intern (Summer 2027)", owner: :hiring_manager },
      { code: "REQ-1014", title: "Data Analyst", type: "full_time", headcount: 1, status: "draft", job: nil, owner: :product_hm },
      { code: "REQ-1015", title: "Support Engineer (EMEA)", type: "contract", headcount: 2, status: "closed", job: nil, owner: :cs_hm }
    ].freeze

    # --- Interview steps ------------------------------------------------------
    STEPS = {
      "screen" => { name: "Recruiter screen", minutes: 30, rubric: "recruiter-screen", note: "screen" },
      "coding" => { name: "Coding", minutes: 60, rubric: "coding", note: "coding" },
      "system-design" => { name: "System design", minutes: 60, rubric: "system-design", note: "system-design" },
      "onsite" => { name: "Onsite panel", minutes: 180, rubric: "onsite", note: "onsite-eng" },
      "reliability-review" => { name: "Incident & reliability review", minutes: 60, rubric: "reliability-review", note: "reliability-review" },
      "portfolio" => { name: "Portfolio review", minutes: 45, rubric: "portfolio", note: "portfolio" },
      "craft" => { name: "Craft session", minutes: 60, rubric: "craft", note: "craft" },
      "collab" => { name: "Cross-functional collaboration", minutes: 45, rubric: "collab", note: "collab" },
      "hm-screen" => { name: "Hiring manager screen", minutes: 45, rubric: "hm-screen", note: "hm-screen" },
      "product-sense" => { name: "Product sense", minutes: 60, rubric: "product-sense", note: "product-sense" },
      "execution" => { name: "Execution & metrics", minutes: 60, rubric: "execution", note: "execution" },
      "scenario" => { name: "Customer scenario", minutes: 45, rubric: "scenario", note: "scenario" },
      "team-match" => { name: "Team match", minutes: 30, rubric: "team-match", note: "team-match" },
      "role-play" => { name: "Outbound role-play", minutes: 45, rubric: "role-play", note: "role-play" },
      "manager-chat" => { name: "Manager conversation", minutes: 30, rubric: "manager-chat", note: "manager-chat" },
      "ceo-conversation" => { name: "CEO conversation", minutes: 60, rubric: "ceo-conversation", note: "ceo-conversation" },
      "deep-dive" => { name: "Functional deep dive", minutes: 90, rubric: "deep-dive", note: "deep-dive" }
    }.freeze

    NEW_RUBRICS = {
      "reliability-review" => [ "Incident & reliability review", "How they reason about failure, on-call, and recovery.", [ %w[incident-response Incident\ response], %w[observability Observability], %w[judgment Judgment] ] ],
      "portfolio" => [ "Portfolio review", "Storytelling, craft, and evidence of impact in past work.", [ %w[storytelling Case-study\ storytelling], %w[craft Visual\ craft], %w[impact Evidence\ of\ impact] ] ],
      "craft" => [ "Craft session", "Live design exercise: framing, craft, and iteration.", [ %w[framing Problem\ framing], %w[craft Craft\ and\ polish], %w[iteration Iteration] ] ],
      "collab" => [ "Cross-functional collaboration", "Working with engineering and product under constraints.", [ %w[communication Communication], %w[partnership Partnering], %w[feedback Giving\ and\ taking\ feedback] ] ],
      "hm-screen" => [ "Hiring manager screen", "Scope, level, and product leadership.", [ %w[motivation Motivation], %w[scope Scope\ and\ level], %w[leadership Leadership] ] ],
      "product-sense" => [ "Product sense", "User insight, prioritization, and vision.", [ %w[user-insight User\ insight], %w[prioritization Prioritization], %w[vision Vision] ] ],
      "execution" => [ "Execution and metrics", "Metrics, tradeoffs, and delivery.", [ %w[metrics Metrics], %w[tradeoffs Tradeoffs], %w[delivery Delivery] ] ],
      "scenario" => [ "Customer scenario", "Role-play of a difficult customer conversation.", [ %w[empathy Empathy], %w[diagnosis Diagnosis], %w[ownership Ownership] ] ],
      "team-match" => [ "Team match", "Will this person grow with this team.", [ %w[collaboration Collaboration], %w[coachability Coachability], %w[motivation Motivation] ] ],
      "role-play" => [ "Outbound role-play", "Cold call and first-meeting role-play.", [ %w[opener Opening], %w[discovery Discovery], %w[resilience Resilience] ] ],
      "manager-chat" => [ "Manager conversation", "Drive, coachability, and ramp expectations.", [ %w[drive Drive], %w[coachability Coachability], %w[motivation Motivation] ] ],
      "ceo-conversation" => [ "CEO conversation", "Vision, leadership, and judgment at executive level.", [ %w[vision Vision], %w[leadership Leadership], %w[judgment Judgment] ] ],
      "deep-dive" => [ "Functional deep dive", "Functional depth, operating cadence, and hiring signal.", [ %w[depth Functional\ depth], %w[operating Operating\ cadence], %w[hiring-signal Hiring\ signal] ] ]
    }.freeze

    NOTES = {
      "reliability-review" => {
        "strong_yes" => "%{name} walked a real %{company} outage from page to postmortem, named the missing alert, and fixed the process, not the person. Exactly the staff-level reliability instinct we need.",
        "yes" => "Good incident framing and sensible SLO thinking. %{name} knew what to cut first when everything was on fire.",
        "mixed" => "Strong on tooling, thin on the human side of on-call. %{name} had no story for burnout or handoffs.",
        "no" => "Could not describe how they would detect the failure in the scenario. Not the reliability depth a %{title} needs."
      },
      "portfolio" => {
        "strong_yes" => "%{name}'s case studies show the whole arc: the problem, the dead ends, the metric that moved. The %{company} checkout work is the best example we have seen this quarter.",
        "yes" => "Two solid case studies with clear ownership. %{name} can explain why they made each call, and the %{company} project shows shipped impact. Advance.",
        "mixed" => "Visually polished, but the case studies read as deliverables, not decisions. I could not tell what %{name} personally owned at %{company}.",
        "no" => "The portfolio is mostly team work with no clear contribution. %{name} could not walk through a tradeoff or a result. Below the bar for a %{title}."
      },
      "craft" => {
        "strong_yes" => "%{name} reframed the brief in the first five minutes, sketched three directions, and killed two of them with reasons. Pixel and interaction detail were both excellent.",
        "yes" => "Good framing and a clean final direction. %{name} iterated well on my feedback; empty and error states were an afterthought but easily coached.",
        "mixed" => "Jumped to a screen before understanding the user. Craft is strong, but %{name} did not revisit the approach when I pushed back.",
        "no" => "No clear problem statement and the layout fell apart under constraints. %{name} struggled to explain the reasoning."
      },
      "collab" => {
        "strong_yes" => "Asked the engineer and PM sharp questions, found the cut that saved two weeks, and gave feedback kindly. Exactly who we want partnering with eng at this level.",
        "yes" => "%{name} partners well and was honest about a past disagreement at %{company}. Comfortable with critique.",
        "mixed" => "Good ideas, but %{name} framed engineering as a constraint instead of a partner. Needs coaching on influence.",
        "no" => "Defensive when the PM challenged the scope. I would worry about %{name} in a cross-functional squad."
      },
      "hm-screen" => {
        "strong_yes" => "%{name} has run roadmaps through two reorgs at %{company} and talks about tradeoffs like an owner. Wants the scope we have. Strong advance.",
        "yes" => "Clear on why this role and why now. The %{title} scope lines up and %{name} asked good questions about our customers.",
        "mixed" => "Good generalist instincts, but the %{company} work was mostly execution. Unsure %{name} has led prioritization end to end.",
        "no" => "%{name} described features shipped, not problems solved. Not the product leadership this role needs."
      },
      "product-sense" => {
        "strong_yes" => "%{name} segmented the users first, picked the underserved one, and proposed a smaller bet than I expected. Great instinct for what not to build.",
        "yes" => "Solid user framing and a sensible MVP. %{name} defended the prioritization when challenged.",
        "mixed" => "Listed ideas without choosing. %{name} needed prompting to tie the proposal to a user problem.",
        "no" => "Solution first, user second. The proposal did not survive basic questions on who it was for."
      },
      "execution" => {
        "strong_yes" => "Picked a north-star metric, named the counter-metric, and laid out a rollout with a kill switch. %{name} has clearly shipped at scale.",
        "yes" => "Good metrics and a realistic plan. %{name} caught the instrumentation gap before I pointed at it.",
        "mixed" => "Plan was reasonable but the success metrics were vague. %{name} could not say how they would know it failed.",
        "no" => "No measurable definition of success and no rollout plan. The execution story from %{company} stayed vague."
      },
      "scenario" => {
        "strong_yes" => "%{name} calmed the angry customer in the role-play, diagnosed the real issue in three questions, and set clear next steps. Natural fit for %{title}.",
        "yes" => "Empathetic and organised. %{name} owned the follow-up and escalated at the right moment.",
        "mixed" => "Warm, but %{name} jumped to a fix before diagnosing. Needs structure under pressure.",
        "no" => "Argued with the customer and missed the escalation path. Not ready for a %{title} seat."
      },
      "team-match" => {
        "strong_yes" => "%{name} asked the team great questions about onboarding and coaching, and the team loved them. Easy yes on culture add.",
        "yes" => "Good rapport with the team. %{name} is motivated by customer outcomes and open to feedback.",
        "mixed" => "Fine conversation, but %{name} was lukewarm on the support-to-success path we described.",
        "no" => "%{name} was more interested in flexibility than the work itself. The team did not see a fit."
      },
      "role-play" => {
        "strong_yes" => "%{name} opened with a pattern interrupt, uncovered a real pain in two minutes, and earned the meeting. Best role-play this month.",
        "yes" => "Good opener and decent discovery. %{name} handled the first objection calmly.",
        "mixed" => "Energy is there but %{name} pitched before asking. Coachable; I would need to see more.",
        "no" => "Read from a script and folded on the first objection. %{name} struggled to keep control of the call."
      },
      "manager-chat" => {
        "strong_yes" => "%{name} has the drive we look for and owns their numbers at %{company}. Wants coaching and asked how we ramp new reps.",
        "yes" => "Positive attitude, realistic about the grind. %{name} would fit the team's pace.",
        "mixed" => "Motivated, but %{name} was vague about past quota attainment at %{company}.",
        "no" => "%{name} is looking for a title bump rather than the work. Low urgency."
      },
      "ceo-conversation" => {
        "strong_yes" => "%{name} had a point of view on our market, challenged two of my assumptions, and was right about one. I would trust them with the function.",
        "yes" => "Clear, credible operator. %{name} understands the stage we are at and where we are likely to stumble.",
        "mixed" => "Impressive background, but %{name} spoke in frameworks. I want specifics on the first 90 days.",
        "no" => "No real view on our business. %{name} is a mismatch for the stage."
      },
      "deep-dive" => {
        "strong_yes" => "%{name} walked the panel through a plan, the metrics, and a hiring sequence with real numbers. The %{company} results held up in two back-channel calls.",
        "yes" => "Strong functional depth and a good operating rhythm. A few gaps in paid channels that %{name} acknowledged openly.",
        "mixed" => "Depth in brand, less in demand gen. %{name} would need a strong deputy.",
        "no" => "The plan was generic and %{name} could not defend the budget."
      }
    }.freeze

    FOCUS = {
      design_hm: "I was looking at craft and whether I want them leading a surface.",
      design_ic: "I was looking at how they work with a peer in the file.",
      product_hm: "I was listening for judgment on what not to build.",
      product_ic: "I was looking at how they use data to make the call.",
      cs_hm: "I was listening for ownership of customer outcomes.",
      cs_ic: "I was looking at how they handle a hard conversation.",
      eng_ic2: "I was looking at depth and operational maturity.",
      owner: "I was looking at judgment and how they would represent us externally.",
      people_lead: "I was looking at values and how they build teams.",
      sourcer: "I was checking how they came to the role and their level."
    }.freeze

    # Stage definitions per pipeline template. interviews are step keys.
    def self.stage(key, name, type, steps = [])
      interviews = steps.map { |k| { "key" => k, "name" => STEPS.fetch(k)[:name], "required" => true, "rubric_key" => STEPS.fetch(k)[:rubric] } }
      { "key" => key, "name" => name, "type" => type, "interviews" => interviews }
    end

    PIPELINES = {
      design: { key: "bigbuck-design", name: "Design", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("portfolio", "Portfolio review", "review", %w[portfolio]), stage("panel", "Design panel", "interview", %w[craft]),
          stage("offer", "Offer", "offer") ],
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("portfolio", "Portfolio review", "review", %w[portfolio]), stage("panel", "Design panel", "interview", %w[craft collab]),
          stage("offer", "Offer", "offer") ]
      ] },
      product: { key: "bigbuck-product", name: "Product", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("hm-screen", "Hiring manager screen", "interview", %w[hm-screen]),
          stage("case", "Product case", "interview", %w[product-sense execution]), stage("offer", "Offer", "offer") ]
      ] },
      support: { key: "bigbuck-support", name: "Customer Success", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("scenario", "Scenario & team", "interview", %w[scenario team-match]), stage("offer", "Offer", "offer") ]
      ] },
      sdr: { key: "bigbuck-sdr", name: "SDR (high volume)", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("role-play", "Role-play & manager", "interview", %w[role-play manager-chat]), stage("offer", "Offer", "offer") ]
      ] },
      leadership: { key: "bigbuck-leadership", name: "Leadership", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("exec", "Executive panel", "interview", %w[ceo-conversation deep-dive]),
          stage("references", "References", "review"), stage("offer", "Offer", "offer") ]
      ] },
      standard: { key: "bigbuck-standard", name: "Standard", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("team", "Team interview", "interview", %w[hm-screen team-match]), stage("offer", "Offer", "offer") ]
      ] },
      intern: { key: "bigbuck-intern", name: "Internship", versions: [
        [ stage("applied", "Applied", "apply"), stage("screen", "Recruiter screen", "screen", %w[screen]),
          stage("technical", "Technical interview", "interview", %w[coding]), stage("offer", "Offer", "offer") ]
      ] }
    }.freeze

    # Per-family interviewer roles (symbols resolve to staff users).
    ROLES = {
      design: { "screen" => %i[recruiter], "portfolio" => %i[design_hm], "craft" => %i[design_hm design_ic], "collab" => %i[product_ic recruiter] },
      product: { "screen" => %i[recruiter], "hm-screen" => %i[product_hm], "product-sense" => %i[product_hm product_ic], "execution" => %i[product_ic hiring_manager] },
      support: { "screen" => %i[recruiter], "scenario" => %i[cs_hm cs_ic], "team-match" => %i[cs_ic] },
      sdr: { "screen" => %i[recruiter], "role-play" => %i[sales_interviewer sales_hm], "manager-chat" => %i[sales_hm] },
      leadership: { "screen" => %i[recruiter], "ceo-conversation" => %i[owner], "deep-dive" => %i[people_lead owner] },
      standard: { "screen" => %i[recruiter], "hm-screen" => %i[people_lead], "team-match" => %i[recruiter people_lead] },
      intern: { "screen" => %i[recruiter], "coding" => %i[eng_interviewer eng_ic2] },
      eng: { "screen" => %i[recruiter], "coding" => %i[eng_interviewer], "system-design" => %i[hiring_manager],
             "reliability-review" => %i[eng_ic2 hiring_manager], "onsite" => %i[hiring_manager eng_interviewer recruiter] },
      sales: { "screen" => %i[recruiter], "discovery" => %i[sales_interviewer], "role-play" => %i[sales_interviewer sales_hm],
               "onsite" => %i[sales_hm sales_interviewer recruiter] }
    }.freeze

    QUESTION_TEMPLATES = {
      "Standard screening" => [
        { "key" => "work_authorization", "label" => "Are you legally authorized to work in the country where this role is based?", "field_type" => "select", "required" => true, "options" => [ "Yes", "No", "I will need sponsorship" ] },
        { "key" => "notice_period", "label" => "What is your notice period or earliest start date?", "field_type" => "text", "required" => false, "options" => [] },
        { "key" => "salary_expectations", "label" => "What are your compensation expectations?", "field_type" => "text", "required" => false, "options" => [] }
      ],
      "Engineering" => [
        { "key" => "github_profile", "label" => "Link to your GitHub or a project you are proud of", "field_type" => "url", "required" => false, "options" => [] },
        { "key" => "primary_languages", "label" => "Which languages do you work in most?", "field_type" => "multi_select", "required" => true, "options" => %w[Ruby TypeScript Go Python Java Rust Kotlin] },
        { "key" => "hardest_problem", "label" => "Describe the hardest production problem you have solved.", "field_type" => "long_text", "required" => true, "options" => [] }
      ],
      "Design" => [
        { "key" => "portfolio_url", "label" => "Portfolio link", "field_type" => "url", "required" => true, "options" => [] },
        { "key" => "design_tools", "label" => "Tools you use daily", "field_type" => "multi_select", "required" => false, "options" => %w[Figma Framer Sketch Principle Protopie] },
        { "key" => "favorite_project", "label" => "Which project in your portfolio should we look at first, and why?", "field_type" => "long_text", "required" => true, "options" => [] }
      ],
      "Sales" => [
        { "key" => "years_in_sales", "label" => "Years of quota-carrying experience", "field_type" => "number", "required" => true, "options" => [] },
        { "key" => "crm_tools", "label" => "CRM and outreach tools you have used", "field_type" => "multi_select", "required" => false, "options" => %w[Salesforce HubSpot Outreach Salesloft Apollo] },
        { "key" => "best_quarter", "label" => "Tell us about your best quarter.", "field_type" => "long_text", "required" => false, "options" => [] }
      ]
    }.freeze

    OFFER_TEMPLATES = [
      { key: "intl-ft", name: "International full-time", expires: 10,
        body: "Dear {{ candidate.display_name }}, Big Buck is delighted to offer you the position of {{ job.title }} with an annual salary of {{ offer.fields.base_salary }} {{ offer.fields.currency }}, starting on {{ offer.fields.start_date }}. This offer is subject to local employment law and standard right-to-work checks." },
      { key: "intern", name: "Internship", expires: 5,
        body: "Hi {{ candidate.display_name }}, we would love to have you join Big Buck as a {{ job.title }}. The internship is paid at {{ offer.fields.base_salary }} {{ offer.fields.currency }} annualised, beginning {{ offer.fields.start_date }}. Reply to this letter to accept." },
      { key: "exec", name: "Executive", expires: 14,
        body: "Dear {{ candidate.display_name }}, on behalf of the Big Buck leadership team I am pleased to extend an offer for the role of {{ job.title }}. Base salary is {{ offer.fields.base_salary }} {{ offer.fields.currency }} with a target start date of {{ offer.fields.start_date }}. Equity and benefits are described in the attached summary." },
      { key: "contractor", name: "Contractor agreement", expires: 7,
        body: "Hello {{ candidate.display_name }}, Big Buck would like to engage you as a contractor for the {{ job.title }} work at a rate equivalent to {{ offer.fields.base_salary }} {{ offer.fields.currency }} per year, starting {{ offer.fields.start_date }}." }
    ].freeze

    SIGN_OFF = "\n\n— The Big Buck recruiting team"

    MESSAGE_TEMPLATES = [
      { key: "application-received", type: "confirmation", subject: "We got your application, {{ person.display_name }}",
        body: "Hi {{ person.display_name }},\n\nThanks for applying to Big Buck. A real person on our recruiting team reads every application, and you will hear from us within five business days either way.\n\nIn the meantime, you can see our open roles at any time on our careers page." },
      { key: "application-received", locale: "de", type: "confirmation", subject: "Wir haben Ihre Bewerbung erhalten, {{ person.display_name }}",
        body: "Hallo {{ person.display_name }},\n\nvielen Dank für Ihre Bewerbung bei Big Buck. Wir melden uns innerhalb von fünf Werktagen bei Ihnen." },
      { key: "phone-screen-request", type: "scheduling", subject: "Let's find 30 minutes, {{ person.display_name }}",
        body: "Hi {{ person.display_name }},\n\nYour background stood out and we would like to set up a 30 minute conversation to talk about the role and what you are looking for next. Use the link below to pick a time that suits you, or reply with a few windows that work." },
      { key: "interview-invite", type: "scheduling", subject: "Your Big Buck interview is confirmed",
        body: "Hi {{ person.display_name }},\n\nYour interview is on the calendar. You will get a separate invite with the video link and the names of the people you will be speaking with. Each conversation is a working session, not a quiz, so bring your own questions too." },
      { key: "interview-reminder", type: "reminder", subject: "Tomorrow: your Big Buck interview",
        body: "Hi {{ person.display_name }},\n\nJust a friendly reminder that your interview is tomorrow. If something has come up, reply to this email and we will find another time, no problem." },
      { key: "interview-prep", type: "interview_prep", subject: "How to prepare for your interview",
        body: "Hi {{ person.display_name }},\n\nHere is what to expect: a short introduction, a working session on a realistic problem, and time for your questions. There is nothing to memorise. We care about how you think and how you work with others." },
      { key: "rejection-after-screen", type: "rejection", subject: "Your application to Big Buck",
        body: "Hi {{ person.display_name }},\n\nThank you for taking the time to speak with us. After careful consideration we have decided not to move forward right now. This was a close call, and we would be glad to hear from you again as we grow." },
      { key: "rejection-after-onsite", type: "rejection", subject: "Update on your interview loop",
        body: "Hi {{ person.display_name }},\n\nThank you for investing so much time with our team. The panel found this a difficult decision and, after discussing it at length, we are not able to extend an offer at this time. The feedback we heard about you was thoughtful and specific, and we would like to stay in touch." },
      { key: "rejection-application", type: "rejection", subject: "About your Big Buck application",
        body: "Hi {{ person.display_name }},\n\nThank you for your interest in Big Buck. We reviewed your application carefully and will not be moving forward for this role. We keep applications on file and may reach out if something closer to your experience opens up." },
      { key: "offer-extended", type: "offer", subject: "Your offer from Big Buck",
        body: "Hi {{ person.display_name }},\n\nIt is our pleasure to extend you an offer. Your offer letter is attached to this email with the details. Please take whatever time you need to review it, and reach out with any questions. We hope to welcome you to the team." },
      { key: "offer-followup", type: "offer", subject: "Checking in on your offer",
        body: "Hi {{ person.display_name }},\n\nJust checking in to see whether you have had a chance to review the offer, and whether there is anything we can answer or help with. Happy to set up a call with the team." },
      { key: "reference-request", type: "reference", subject: "A reference request for {{ person.display_name }}",
        body: "Hello,\n\n{{ person.display_name }} has given your name as a reference. Would you have 15 minutes this week to share your experience working together?" },
      { key: "referral-thanks", type: "referral", subject: "Thank you for the referral",
        body: "Hi {{ person.display_name }},\n\nThank you for recommending someone to Big Buck. We have reached out and will keep you updated as they move through the process." },
      { key: "cold-engineering-intro", type: "sequence", subject: "{{ person.display_name }}, platform work at Big Buck",
        body: "Hi {{ person.display_name }},\n\nI lead technical recruiting at Big Buck. We are building the infrastructure behind a hiring platform used by thousands of recruiters, and your background caught my eye. Open to a short chat about what we are working on?" },
      { key: "cold-engineering-followup", type: "sequence", subject: "Re: platform work at Big Buck",
        body: "Hi {{ person.display_name }},\n\nBumping this in case it got buried. We are a small team shipping fast, with real ownership for senior engineers. Happy to share the roadmap if useful." },
      { key: "cold-engineering-breakup", type: "sequence", subject: "Closing the loop",
        body: "Hi {{ person.display_name }},\n\nI will stop reaching out so I do not clutter your inbox. If the timing changes, you can reply here and I will pick the thread back up." },
      { key: "design-leaders-intro", type: "sequence", subject: "Your work caught our eye, {{ person.display_name }}",
        body: "Hi {{ person.display_name }},\n\nOur design team is small and senior, and we are hiring for a role that shapes how thousands of recruiters work. I saw your portfolio and wanted to reach out personally." },
      { key: "design-leaders-followup", type: "sequence", subject: "A quick note on the design role",
        body: "Hi {{ person.display_name }},\n\nOne more note: the role reports to our Head of Design and partners directly with product and engineering. If it sounds interesting I would love to set up a conversation." },
      { key: "silver-medalist-checkin", type: "sequence", subject: "Staying in touch, {{ person.display_name }}",
        body: "Hi {{ person.display_name }},\n\nYou made a strong impression when you interviewed with us. We did not have the right opening then, but we do now. Would you be open to catching up?" },
      { key: "campus-intro", type: "sequence", subject: "Summer 2027 at Big Buck",
        body: "Hi {{ person.display_name }},\n\nWe are opening our Summer 2027 engineering internship program and would love to see you apply. Interns work on real features and ship to production in their first month." },
      { key: "campus-nurture", type: "sequence", subject: "Meet the Big Buck engineering interns",
        body: "Hi {{ person.display_name }},\n\nHere is what last summer's interns shipped, in their own words. If you have questions about the program, I am happy to connect you with one of them." },
      { key: "alumni-welcome-back", type: "sequence", subject: "Things have changed at Big Buck, {{ person.display_name }}",
        body: "Hi {{ person.display_name }},\n\nIt has been a while. We have grown the team and have a few roles that look a lot like the ones you excelled in. Want to catch up over coffee or a call?" },
      { key: "legacy-outreach", type: "outreach", subject: "Opportunities at Big Buck", archived: true,
        body: "Hi {{ person.display_name }},\n\nWe are hiring across several teams. Reply if you would like to talk." }
    ].freeze

    SEQUENCES = [
      { key: "engineering-cold", name: "Engineering cold outreach", shared: true, template: false, status: "active", steps: [
        { "type" => "email", "template_key" => "cold-engineering-intro" }, { "type" => "wait", "days" => 3 },
        { "type" => "email", "template_key" => "cold-engineering-followup" }, { "type" => "wait", "days" => 4 },
        { "type" => "task", "title" => "Send a LinkedIn note and call if a number is on file", "due_in_days" => 2 },
        { "type" => "wait", "days" => 5 }, { "type" => "email", "template_key" => "cold-engineering-breakup" }
      ] },
      { key: "design-leaders", name: "Design leaders, personal touch", shared: true, template: false, status: "active", steps: [
        { "type" => "email", "template_key" => "design-leaders-intro" }, { "type" => "wait", "days" => 4 },
        { "type" => "task", "title" => "Review their portfolio and add a personal note", "due_in_days" => 1 },
        { "type" => "wait", "days" => 2 }, { "type" => "email", "template_key" => "design-leaders-followup" }
      ] },
      { key: "silver-medalists", name: "Silver medalist check-in", shared: true, template: false, status: "active", steps: [
        { "type" => "email", "template_key" => "silver-medalist-checkin" }, { "type" => "wait", "days" => 7 },
        { "type" => "task", "title" => "Call to catch up and share the new opening", "due_in_days" => 3 }
      ] },
      { key: "campus-2027", name: "Campus Summer 2027 nurture", shared: true, template: false, status: "active", steps: [
        { "type" => "email", "template_key" => "campus-intro" }, { "type" => "wait", "days" => 14 },
        { "type" => "email", "template_key" => "campus-nurture" }
      ] },
      { key: "alumni-boomerang", name: "Alumni boomerang", shared: true, template: false, status: "active", steps: [
        { "type" => "email", "template_key" => "alumni-welcome-back" }, { "type" => "wait", "days" => 10 },
        { "type" => "task", "title" => "Coffee chat invite", "due_in_days" => 4 }
      ] },
      { key: "referral-thank-you", name: "Referral thank-you (template)", shared: true, template: true, status: "active", steps: [
        { "type" => "email", "template_key" => "referral-thanks" }
      ] }
    ].freeze

    # --- Candidate name pools (disjoint from the base dataset) ------------------
    FIRST = %w[Maya Daniel Sofia Amara Tomas Leila Mateo Ingrid Kwame Noor Isla Rohan Camila Jonas Mei Andre Zainab
               Luca Yara Idris Hana Felix Anika Bruno Thandi Dmitri Elif Gabriel Mina Oscar Rhea Tariq Vera Joaquin
               Nia Stefan Aiko Callum Dalia Emeka Freya Gideon Hiro Imani Jorge Katya Lior Magnus Nadine Obi Petra
               Rafael Selin Teodor Uzma Viktor Wanjiru Ximena Yusuf Zara].freeze
    LAST = %w[Okafor Reyes Lindqvist Haddad Novak Mbeki Castillo Fischer Adeyemi Kowalski Tanaka Moreau Rahman Santos
              Petrov Osei Ivanova Navarro Bauer Hossain Marin Kaplan Sorensen Abara Delgado Yilmaz Costa Duarte
              Eriksson Farah Gutierrez Ibrahim Jovanovic Kamara Laurent Mahlangu Nakamura Oyelaran Pereira Quispe
              Rossi Silva Tembo Usman Varga Wojcik Xiong Yamamoto Zielinski Bianchi Cardoso Dubois Engel Fontaine
              Gallo Horvat Ilunga Jensen Kuznetsov].freeze

    # --- Resume banks ---------------------------------------------------------
    FAMILIES = {
      eng: {
        ladder: [ "Software Engineer", "Senior Software Engineer", "Staff Engineer", "Engineering Manager" ],
        skills: [ "Ruby on Rails", "TypeScript", "Go", "PostgreSQL", "Kubernetes", "AWS", "Distributed systems", "Observability", "gRPC", "Terraform" ],
        bullets: [
          "Cut p99 API latency from %{n}0ms to 120ms by reworking the caching layer and removing N+1 queries across the core services.",
          "Led the migration of a monolith to %{n} services with zero customer-visible downtime and a staged rollout plan.",
          "Built the on-call runbook and alerting that reduced pages by %{n}0% quarter over quarter.",
          "Designed an event pipeline processing %{n}M events per day with at-least-once delivery and idempotent consumers.",
          "Mentored %{n} engineers through promotion and introduced a design review practice used by the whole org.",
          "Owned the payments reconciliation service end to end, including the backfill that recovered $%{n}00K in missed revenue.",
          "Introduced contract tests between services, catching breaking changes before they reached staging.",
          "Reduced CI time from %{n}0 to 12 minutes by parallelising the test suite and caching dependencies."
        ]
      },
      design: {
        ladder: [ "Product Designer", "Senior Product Designer", "Lead Product Designer", "Design Manager" ],
        skills: [ "Figma", "Prototyping", "Design systems", "User research", "Interaction design", "Accessibility (WCAG)", "Information architecture", "Workshop facilitation" ],
        bullets: [
          "Redesigned onboarding end to end, lifting activation by %{n}% across %{n}0k weekly signups.",
          "Built and maintained a design system of %{n}0+ components adopted by %{n} product squads.",
          "Ran %{n}0 customer interviews to reframe the roadmap, which retired two planned features and saved a quarter of work.",
          "Partnered with engineering to ship a rebuilt checkout that reduced drop-off by %{n}%.",
          "Introduced weekly critique and a shared definition of done, halving design rework.",
          "Led accessibility remediation to WCAG 2.1 AA across the core product with no dedicated headcount.",
          "Mentored %{n} designers and hired the first two researchers on the team."
        ]
      },
      product: {
        ladder: [ "Product Manager", "Senior Product Manager", "Group Product Manager", "Director of Product" ],
        skills: [ "Roadmapping", "Experimentation", "SQL", "Product analytics", "Customer discovery", "Pricing", "Stakeholder management", "Growth loops" ],
        bullets: [
          "Owned the self-serve funnel and raised signup-to-paid conversion from %{n}% to %{n}7% through %{n}0 shipped experiments.",
          "Defined and launched a usage-based pricing tier that contributed $%{n}.2M in ARR in its first year.",
          "Built the discovery practice for a %{n}-person squad: weekly customer calls, an opportunity tree, and a shared insights repo.",
          "Sunset three low-usage features, freeing %{n} engineers for the highest-impact bets.",
          "Partnered with data science to launch a churn-prediction model that improved retention by %{n} points.",
          "Rebuilt the planning cadence so roadmap commitments hit %{n}0% on-time delivery."
        ]
      },
      support: {
        ladder: [ "Customer Success Associate", "Customer Success Manager", "Senior CSM", "Customer Success Lead" ],
        skills: [ "Onboarding", "Renewals", "Gainsight", "Zendesk", "Executive business reviews", "Escalation management", "SQL basics", "Product training" ],
        bullets: [
          "Managed a book of %{n}0 mid-market accounts totalling $%{n}.4M ARR with %{n}% net revenue retention.",
          "Built the onboarding playbook that cut time-to-value from %{n}0 to 21 days.",
          "Led executive business reviews for the top %{n} accounts and turned two at-risk renewals into expansions.",
          "Created the escalation path between support, success, and engineering, reducing repeat escalations by %{n}0%.",
          "Trained %{n} new CSMs and shipped the internal onboarding course they still use."
        ]
      },
      sales: {
        ladder: [ "Sales Development Representative", "Account Executive", "Senior Account Executive", "Sales Manager" ],
        skills: [ "Outbound prospecting", "Discovery", "Salesforce", "Outreach", "MEDDICC", "Negotiation", "Forecasting", "Cold calling" ],
        bullets: [
          "Attained %{n}0%+ of quota for %{n} consecutive quarters, ranking in the top 10% of the team.",
          "Booked %{n}0 qualified meetings per month through a mix of cold calls, email sequences, and social selling.",
          "Closed a $%{n}00K multi-year deal with a security-conscious enterprise buyer by running a joint evaluation plan.",
          "Built a repeatable outbound motion into a new vertical that produced $%{n}00K pipeline in the first quarter.",
          "Coached %{n} new reps and shared the objection-handling guide that became team standard."
        ]
      },
      leadership: {
        ladder: [ "Senior Director", "VP", "Head of Function", "Chief of Staff" ],
        skills: [ "Strategy", "Team building", "Budget ownership", "Brand", "Demand generation", "Board communication", "Operating cadence" ],
        bullets: [
          "Scaled the function from %{n} to %{n}0 people while holding cost per hire flat.",
          "Owned a $%{n}M annual budget and reallocated 20% to the highest-ROI channels mid-year.",
          "Launched the category narrative adopted across sales, product, and recruiting.",
          "Introduced a quarterly operating review used by the executive team to track company-wide goals."
        ]
      },
      intern: {
        ladder: [ "Software Engineering Intern", "Research Assistant", "Teaching Assistant" ],
        skills: [ "Python", "TypeScript", "React", "Data structures", "Git", "SQL" ],
        bullets: [
          "Built a course-scheduling app used by %{n}00 students, deployed on a free-tier cloud stack.",
          "Placed top %{n} at a university hackathon with a team of four, shipping a working prototype in 24 hours.",
          "Teaching assistant for Data Structures; ran weekly office hours for %{n}0 students.",
          "Contributed %{n} merged pull requests to an open-source developer tool."
        ]
      }
    }.freeze

    SCHOOLS = [
      "University of California, Berkeley", "Georgia Tech", "University of Toronto", "Carnegie Mellon University",
      "University of Waterloo", "Imperial College London", "TU Munich", "IIT Bombay", "University of Texas at Austin",
      "Northeastern University", "University of Michigan", "ETH Zurich", "NYU", "McGill University", "Arizona State University"
    ].freeze
    DEGREES = [ "B.S. Computer Science", "B.A. Interaction Design", "B.S. Information Systems", "M.S. Human-Computer Interaction", "B.S. Economics", "B.A. Business", "M.B.A.", "B.S. Mathematics" ].freeze

    REJECTION_REASONS = [
      "Not moving forward after the review",
      "Skills not aligned with the role requirements",
      "Another candidate was a stronger fit on scope",
      "Compensation expectations outside the band",
      "Role closed before the process finished"
    ].freeze
  end
end
