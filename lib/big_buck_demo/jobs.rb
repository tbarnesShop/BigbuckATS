# frozen_string_literal: true

module BigBuckDemo
  # Job + funnel definitions.
  #
  # A funnel row places `count` candidates on a stage. `phase` describes the interview
  # state at that stage (see BigBuckDemoSeed#run_stage_interviews!):
  #   :none (just arrived) :requested :scheduled :partial :awaiting_feedback :attention :complete
  # `status` is the application status (active/rejected/withdrawn/hired); `offer` is an
  # offer status for candidates on the offer stage. Rows with `hero:` carry a hand-written
  # candidate; everything else is generated.
  module Jobs
    def self.f(count, stage, phase = :none, status = "active", strength = :solid, **opts)
      { count: count, stage: stage, phase: phase, status: status, strength: strength }.merge(opts)
    end

    def self.hero(name, stage, phase, status, strength, **opts)
      f(1, stage, phase, status, strength, hero: name, **opts)
    end

    JOBS = [
      # Flagship careers roles already exist from BigBuckDataset (applied/onsite/offer pipeline).
      # These funnels top them up to a real pyramid; heroes make the top-up idempotent.
      {
        title: "Platform Engineer", family: :eng, pipeline: :eng, dept: "engineering", status: "active", audience: "both",
        openings: 3, locations: %w[sf remote nyc london], salary: [ 160_000, 210_000 ], question_template: "Engineering",
        team: { hm: :hiring_manager, recruiter: :recruiter, interviewers: %i[eng_interviewer eng_ic2], coordinator: :admin },
        funnel: [
          f(28, "applied", :none, "active", :solid, source: "careers"), f(8, "applied", :none, "rejected", :weak, source: "linkedin"),
          f(3, "applied", :none, "withdrawn", :solid, source: "careers"),
          f(10, "onsite", :scheduled, "active", :solid), f(4, "onsite", :requested, "active", :solid),
          f(3, "onsite", :partial, "active", :strong), f(3, "onsite", :awaiting_feedback, "active", :solid),
          f(2, "onsite", :attention, "active", :solid), f(3, "onsite", :complete, "rejected", :mixed),
          hero("Priya Venkatesh", "onsite", :partial, "active", :strong, company: "hooli", title: "Senior Software Engineer", location: "sf", years: 8, source: "linkedin",
               headline: "Owns the billing event pipeline at Lumen Cloud; calm under on-call.",
               notes: [ [ :hiring_manager, "Priya's system design was excellent. Coding loop is booked for Thursday." ],
                        [ :recruiter, "She has one other process. Keep the loop tight." ] ]),
          f(2, "offer", :complete, "active", :strong, offer: "sent"), f(1, "offer", :complete, "hired", :strong, offer: "accepted"),
          f(1, "offer", :complete, "active", :solid, offer: "declined"),
          hero("Samir Okonkwo", "offer", :complete, "active", :strong, offer: "pending_approval", company: "acme", title: "Staff Engineer", location: "remote", years: 11, source: "referral",
               referrer: :eng_interviewer, headline: "Led a zero-downtime migration of a payments monolith.",
               notes: [ [ :recruiter, "Offer packet in approval. Comp is in band; equity refresh needs Harper." ] ])
        ]
      },
      {
        title: "Account Executive", family: :sales, pipeline: :sdr, dept: "sales", status: "active", audience: "both",
        openings: 4, locations: %w[nyc austin remote toronto], salary: [ 110_000, 160_000 ], question_template: "Sales",
        team: { hm: :sales_hm, recruiter: :recruiter, interviewers: %i[sales_interviewer], coordinator: :people_lead },
        funnel: [
          f(24, "applied", :none, "active", :solid, source: "careers"), f(6, "applied", :none, "rejected", :weak, source: "agency"),
          f(2, "applied", :none, "withdrawn", :solid, source: "linkedin"),
          f(8, "onsite", :scheduled, "active", :solid), f(3, "onsite", :requested, "active", :solid),
          f(2, "onsite", :partial, "active", :strong), f(2, "onsite", :awaiting_feedback, "active", :solid),
          f(2, "onsite", :complete, "rejected", :mixed),
          hero("Elena Vargas", "onsite", :scheduled, "active", :strong, company: "dunder", title: "Senior Account Executive", location: "nyc", years: 7, source: "linkedin",
               headline: "Closed mid-market SaaS; consistent 120%+ of quota.",
               notes: [ [ :sales_hm, "Elena's discovery stories are specific. Panel is Thursday." ] ]),
          f(2, "offer", :complete, "active", :strong, offer: "sent"), f(1, "offer", :complete, "hired", :strong, offer: "accepted"),
          f(1, "offer", :complete, "active", :solid, offer: "declined"),
          hero("Noah Bergström", "offer", :complete, "active", :strong, offer: "approved", company: "vandelay", title: "Account Executive", location: "austin", years: 5, source: "referral",
               referrer: :sales_hm, headline: "Enterprise hunter; comfortable with long RFPs.",
               notes: [ [ :recruiter, "Offer approved. Sasha wants to call before we send." ] ])
        ]
      },
      {
        title: "Senior Product Designer", family: :design, pipeline: :design, dept: "design", status: "active", audience: "public",
        openings: 2, locations: %w[sf remote nyc london], salary: [ 150_000, 195_000 ], question_template: "Design",
        team: { hm: :design_hm, recruiter: :recruiter, interviewers: %i[design_ic product_ic], coordinator: :people_lead },
        posting_questions: [ { "key" => "design_challenge", "label" => "What is the most interesting design constraint you have worked within?", "field_type" => "long_text", "required" => false, "options" => [] } ],
        funnel: [
          f(8, "applied", :none, "active", :solid, source: "careers"), f(3, "applied", :none, "rejected", :weak, source: "linkedin"),
          f(1, "applied", :none, "withdrawn", :solid, source: "careers"),
          f(3, "screen", :scheduled, "active", :solid), f(1, "screen", :requested, "active", :solid),
          f(1, "screen", :complete, "active", :solid), f(1, "screen", :complete, "rejected", :weak),
          f(1, "portfolio", :awaiting_feedback, "active", :solid), f(1, "portfolio", :scheduled, "active", :strong),
          f(1, "portfolio", :complete, "rejected", :mixed),
          f(1, "panel", :scheduled, "active", :strong), f(1, "panel", :attention, "active", :solid),
          f(1, "panel", :complete, "rejected", :mixed),
          hero("Maya Okafor", "offer", :complete, "active", :strong, offer: "sent", company: "hooli", title: "Lead Product Designer", location: "sf", years: 9, source: "referral",
               referrer: :design_hm, headline: "Led checkout and onboarding redesigns at Lumen Cloud; ex-agency.",
               notes: [ [ :design_hm, "Maya and I ran a workshop together at a design conference two years ago. Referring her directly; she is exactly the systems-minded designer we have been missing." ],
                        [ :recruiter, "Panel debrief is unanimous. Offer approved by Morgan and sent. She has one other process, so we are keeping a tight loop." ] ]),
          hero("Theo Lindqvist", "panel", :partial, "active", :strong, company: "northwind", title: "Senior Product Designer", location: "berlin", years: 7, source: "linkedin",
               headline: "Design systems lead; shipped a component library used by 12 squads.",
               notes: [ [ :recruiter, "Theo is in the panel loop. Craft session is done and went well; the collaboration interview is booked." ] ]),
          hero("Amara Delgado", "portfolio", :awaiting_feedback, "active", :solid, company: "wonka", title: "Product Designer", location: "austin", years: 5, source: "careers",
               headline: "Consumer product designer with a strong mobile portfolio."),
          f(1, "offer", :complete, "hired", :strong, offer: "accepted"), f(1, "offer", :complete, "active", :strong, offer: "pending_approval"),
          f(1, "offer", :complete, "active", :solid, offer: "declined")
        ]
      },
      {
        title: "Product Manager, Growth", family: :product, pipeline: :product, dept: "product", status: "active", audience: "public",
        openings: 1, locations: %w[nyc remote sf toronto], salary: [ 165_000, 210_000 ], question_template: "Standard screening",
        team: { hm: :product_hm, recruiter: :recruiter, interviewers: %i[product_ic hiring_manager], coordinator: :people_lead },
        funnel: [
          f(4, "applied", :none, "active", :solid, source: "careers"), f(2, "applied", :none, "rejected", :weak, source: "agency"),
          f(2, "screen", :scheduled, "active", :solid), f(1, "screen", :complete, "active", :solid),
          f(1, "hm-screen", :awaiting_feedback, "active", :solid), f(1, "hm-screen", :complete, "rejected", :mixed),
          f(1, "case", :requested, "active", :strong),
          hero("Jonas Kowalski", "case", :scheduled, "active", :strong, company: "acme", title: "Senior Product Manager", location: "nyc", years: 8, source: "linkedin",
               headline: "Owned self-serve growth at Arden Systems; 3x'd trial-to-paid in 18 months.",
               notes: [ [ :product_hm, "Jonas stood out in the hiring manager screen. Case interviews are booked for tomorrow with Ravi and Harper." ] ]),
          f(1, "case", :partial, "active", :solid), f(1, "case", :complete, "rejected", :weak),
          hero("Leila Haddad", "offer", :complete, "active", :strong, offer: "approved", company: "initech", title: "Group Product Manager", location: "remote", years: 10, source: "referral",
               headline: "Pricing and packaging lead; launched usage-based tiers.",
               notes: [ [ :recruiter, "Offer approved. Taylor wants to make a personal call before we send; holding until Thursday." ] ])
        ]
      },
      {
        title: "Customer Success Manager", family: :support, pipeline: :support, dept: "customer-success", status: "active", audience: "both",
        openings: 3, locations: %w[austin remote nyc toronto], salary: [ 95_000, 130_000 ], question_template: "Standard screening",
        team: { hm: :cs_hm, recruiter: :recruiter, interviewers: %i[cs_ic], coordinator: :people_lead },
        funnel: [
          f(4, "applied", :none, "active", :solid, source: "careers"), f(1, "applied", :none, "rejected", :weak, source: "linkedin"),
          f(2, "screen", :scheduled, "active", :solid), f(1, "screen", :complete, "active", :solid),
          f(1, "screen", :complete, "withdrawn", :solid),
          f(1, "scenario", :scheduled, "active", :solid), f(1, "scenario", :partial, "active", :strong),
          f(1, "scenario", :complete, "rejected", :mixed),
          f(1, "offer", :complete, "active", :strong, offer: "changes_requested"),
          hero("Noor Rahman", "offer", :complete, "hired", :strong, offer: "accepted", company: "dunder", title: "Customer Success Manager", location: "austin", years: 6, source: "referral",
               headline: "Managed a $4M mid-market book at 118% net revenue retention.",
               notes: [ [ :cs_hm, "Noor's customer scenario was the best we have run. She starts the first of next month." ] ])
        ]
      },
      {
        title: "Staff Site Reliability Engineer", family: :eng, pipeline: :eng, dept: "engineering", status: "active", audience: "public",
        openings: 1, locations: %w[remote sf berlin london], salary: [ 195_000, 240_000 ], question_template: "Engineering",
        overrides: [ { "op" => "add_interview", "stage" => "onsite", "interview" => { "key" => "reliability-review", "name" => "Incident & reliability review", "required" => true, "rubric_key" => "reliability-review" } } ],
        extra_steps: %w[reliability-review],
        team: { hm: :hiring_manager, recruiter: :recruiter, interviewers: %i[eng_interviewer eng_ic2], coordinator: :admin },
        funnel: [
          f(3, "applied", :none, "active", :solid, source: "linkedin"), f(2, "applied", :none, "rejected", :weak, source: "agency"),
          f(1, "onsite", :requested, "active", :strong),
          hero("Rohan Mbeki", "onsite", :partial, "active", :strong, company: "cyberdyne", title: "Staff SRE", location: "remote", years: 11, source: "outbound", via_pool: "SRE & infrastructure bench",
               headline: "Led reliability for a 400-service platform; SLO program owner.",
               notes: [ [ :sourcer, "Sourced in the SRE bench project; replied to the second email in the sequence and applied through the careers page." ],
                        [ :hiring_manager, "Reliability review is booked for tomorrow. The first three rounds were strong." ] ]),
          f(1, "onsite", :awaiting_feedback, "active", :solid), f(1, "onsite", :complete, "rejected", :mixed),
          f(1, "onsite", :scheduled, "active", :solid, via_pool: "SRE & infrastructure bench"),
          f(1, "offer", :complete, "active", :strong, offer: "sent")
        ]
      },
      {
        title: "Engineering Manager, Payments", family: :eng, pipeline: :eng, dept: "engineering", status: "closed", audience: "public",
        openings: 1, locations: %w[sf nyc austin], salary: [ 220_000, 260_000 ], question_template: "Engineering", close_after: true,
        team: { hm: :hiring_manager, recruiter: :recruiter, interviewers: %i[eng_interviewer], coordinator: :admin },
        funnel: [
          f(3, "applied", :none, "rejected", :weak, source: "linkedin"), f(1, "applied", :none, "withdrawn", :solid, source: "careers"),
          f(2, "onsite", :complete, "rejected", :mixed),
          hero("Ingrid Fischer", "offer", :complete, "hired", :strong, offer: "accepted", company: "gringotts", title: "Engineering Manager", location: "nyc", years: 12, source: "agency",
               headline: "Managed a 14-person payments org through a PCI re-architecture.",
               notes: [ [ :hiring_manager, "Ingrid accepted. Requisition REQ-1007 is filled and the posting is closed." ] ])
        ]
      },
      {
        title: "Sales Development Representative", family: :sdr, pipeline: :sdr, dept: "sales", status: "active", audience: "public",
        openings: 5, locations: %w[austin nyc remote toronto], salary: [ 60_000, 80_000 ], question_template: "Sales",
        team: { hm: :sales_hm, recruiter: :recruiter, interviewers: %i[sales_interviewer], coordinator: :people_lead },
        funnel: [
          f(12, "applied", :none, "active", :solid, source: "careers"), f(4, "applied", :none, "rejected", :weak, source: "careers"),
          f(1, "applied", :none, "withdrawn", :solid, source: "careers"),
          f(4, "screen", :scheduled, "active", :solid), f(2, "screen", :requested, "active", :solid),
          f(2, "screen", :complete, "active", :solid), f(1, "screen", :complete, "rejected", :weak),
          f(1, "role-play", :requested, "active", :solid),
          hero("Mateo Santos", "role-play", :scheduled, "active", :strong, company: "vandelay", title: "Business Development Rep", location: "austin", years: 2, source: "careers",
               headline: "Booked 40 qualified meetings a month at Meridian Freight."),
          f(1, "role-play", :awaiting_feedback, "active", :solid), f(1, "role-play", :complete, "rejected", :mixed),
          f(1, "offer", :complete, "active", :strong, offer: "pending_approval"), f(2, "offer", :complete, "hired", :strong, offer: "accepted"),
          f(1, "offer", :complete, "active", :solid, offer: "expired")
        ]
      },
      {
        title: "Security Engineer", family: :eng, pipeline: :eng, dept: "engineering", status: "paused", audience: "public",
        openings: 1, locations: %w[remote sf london], salary: [ 175_000, 215_000 ], question_template: "Engineering",
        team: { hm: :hiring_manager, recruiter: :recruiter, interviewers: %i[eng_ic2], coordinator: :admin },
        funnel: [
          f(2, "applied", :none, "active", :solid, source: "linkedin"), f(1, "applied", :none, "rejected", :weak, source: "agency"),
          f(1, "onsite", :awaiting_feedback, "active", :solid), f(1, "onsite", :complete, "active", :strong),
          f(1, "offer", :complete, "active", :solid, offer: "rescinded")
        ]
      },
      {
        title: "VP of Marketing", family: :leadership, pipeline: :leadership, dept: "marketing", status: "active", audience: "hidden",
        confidential: true, code_name: "Project Lighthouse", openings: 1, locations: %w[sf nyc], salary: [ 280_000, 340_000 ],
        team: { hm: :owner, recruiter: :recruiter, interviewers: %i[people_lead], coordinator: :people_lead },
        no_posting: true,
        funnel: [
          f(2, "applied", :none, "active", :strong, source: "agency"), f(1, "screen", :scheduled, "active", :strong),
          f(1, "screen", :complete, "rejected", :weak),
          hero("Vera Novak", "exec", :partial, "active", :strong, company: "waystar", title: "SVP Marketing", location: "nyc", years: 16, source: "agency",
               headline: "Scaled marketing from 12 to 60 people; owned a $22M budget.",
               notes: [ [ :owner, "Confidential search: current VP is leaving after Q1. Vera knows only that we are hiring for a senior marketing leader." ] ]),
          f(1, "references", :none, "active", :strong),
          hero("Gabriel Castillo", "offer", :complete, "active", :strong, offer: "pending_approval", company: "bluth", title: "VP Marketing", location: "sf", years: 14, source: "agency",
               headline: "Category-defining brand and demand leader.",
               notes: [ [ :owner, "References done. Executive offer is in two-step approval: hiring manager, then People." ] ])
        ]
      },
      {
        title: "Chief of Staff", family: :leadership, pipeline: :leadership, dept: "people", status: "draft", audience: "public",
        openings: 1, locations: %w[sf], salary: [ 200_000, 250_000 ], posting_status: "draft",
        team: { hm: :owner, recruiter: :recruiter, interviewers: %i[people_lead], coordinator: :people_lead },
        funnel: []
      },
      {
        title: "Technical Recruiter", family: :standard_internal, pipeline: :standard, dept: "people", status: "active", audience: "internal",
        openings: 1, locations: %w[remote nyc], salary: [ 105_000, 135_000 ], question_template: "Standard screening",
        team: { hm: :people_lead, recruiter: :recruiter, interviewers: %i[recruiter], coordinator: :admin },
        funnel: [
          { count: 2, stage: "applied", phase: :none, status: "active", strength: :solid, existing: "employee" },
          { count: 1, stage: "screen", phase: :scheduled, status: "active", strength: :solid, existing: "employee" },
          { count: 1, stage: "team", phase: :complete, status: "active", strength: :strong, existing: "employee" }
        ]
      },
      {
        title: "Software Engineering Intern (Summer 2027)", family: :intern, pipeline: :intern, dept: "engineering", status: "active", audience: "public",
        openings: 6, locations: %w[sf nyc toronto bangalore remote], salary: [ 52_000, 62_000 ], question_template: "Engineering",
        team: { hm: :hiring_manager, recruiter: :sourcer, interviewers: %i[eng_interviewer eng_ic2], coordinator: :people_lead },
        funnel: [
          f(6, "applied", :none, "active", :solid, source: "campus"), f(2, "applied", :none, "rejected", :weak, source: "campus"),
          f(3, "screen", :scheduled, "active", :solid), f(2, "screen", :complete, "active", :solid),
          f(2, "technical", :scheduled, "active", :solid), f(1, "technical", :awaiting_feedback, "active", :solid),
          f(1, "technical", :complete, "rejected", :mixed),
          hero("Aiko Yamamoto", "offer", :complete, "active", :strong, offer: "sent", company: "aperture", title: "Software Engineering Intern", location: "toronto", years: 1, source: "campus",
               headline: "Third-year CS at Waterloo; two prior co-ops and an open-source maintainer."),
          hero("Zara Tanaka", "offer", :complete, "hired", :strong, offer: "accepted", company: "oscorp", title: "Research Assistant", location: "sf", years: 1, source: "campus",
               headline: "Compilers research assistant; won the campus hackathon.")
        ]
      }
    ].freeze

    # Sourcing projects beyond the two the base dataset creates.
    POOLS = [
      { name: "Design leaders, Bay Area", job: "Senior Product Designer", members: 18, sequence: "design-leaders", family: :design },
      { name: "Campus 2027, Engineering", job: "Software Engineering Intern (Summer 2027)", members: 24, sequence: "campus-2027", family: :intern },
      { name: "SRE & infrastructure bench", job: "Staff Site Reliability Engineer", members: 16, sequence: "engineering-cold", family: :eng },
      { name: "Executive search: Project Lighthouse", job: "VP of Marketing", members: 8, sequence: nil, family: :leadership, confidential: true },
      { name: "Silver medalists", job: nil, members: :silver, sequence: "silver-medalists" },
      { name: "Boomerangs & alumni", job: nil, members: :alumni, sequence: "alumni-boomerang" }
    ].freeze
  end
end
