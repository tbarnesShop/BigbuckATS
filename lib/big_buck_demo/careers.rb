# frozen_string_literal: true

module BigBuckDemo
  # Public careers copy in the V1 demo's voice (tbarnesShop/BigBuck-ATS, packages/domain/src/identity/seed.ts
  # and apps/web/src/lib/apply-questions.ts). Brand copy and the V1 role descriptions are verbatim; roles V1
  # never had are written in the same voice: a joke with a real spec baked in, ending on one hard "no".
  module Careers
    # Bump to re-apply brand copy and posting descriptions to an already-seeded demo.
    VERSION = 2

    ACCENT = "#2ec4b6"
    HERO = "/careers-hero.svg"

    BRAND = {
      "careers_headline" => "We make hiring agent-first.",
      "careers_subcopy" => "BigBuck builds hiring software for teams that want agents in the loop — not bolted on. " \
                           "Open roles across engineering, design, and go-to-market.",
      "careers_about_title" => "One record. Every surface.",
      "careers_about_body" => "Hiring and sourcing share the same person, the same permissions, and the same API. " \
                              "Candidates meet a branded careers page; agents meet MCP; operators meet config as code.",
      "careers_culture_title" => "Remote by default. Opinionated on purpose.",
      "careers_culture_body" => "We hire makers who like sharp tools, short feedback loops, and systems that stay honest " \
                                "under load. Bring taste. Bring receipts. Leave the corporate brochure voice at the door.",
      "careers_culture" => [
        { "title" => "Agents welcome",
          "body" => "MCP tools for every role — recruiters, admins, and hiring managers. Assistants should be able to " \
                    "hire here without a special side door." },
        { "title" => "Config as code",
          "body" => "Pipelines, scorecards, and roles live in files you can plan, apply, and roll back. The UI is the " \
                    "day; the repo is the system of record." },
        { "title" => "Candidate-grade pages",
          "body" => "Careers, apply, schedule, and offer links wear the employer brand — not a generic ATS chrome with " \
                    "your logo stuck in the corner." }
      ],
      "careers_accent_color" => ACCENT,
      "careers_hero_image_url" => HERO
    }.freeze

    # Job title => description and the required "demo roast" asked on the apply form.
    ROLES = {
      # —— Verbatim from V1 ——
      "Platform Engineer" => {
        description: "Keep this demo upright when a recruiter opens twelve tabs and a PM “just wants to try something.” " \
                     "You’ll own deploys, queues, and the quiet art of making Postgres look effortless. Strong opinions " \
                     "about connection pools required. Strong opinions about purple gradients: optional, and preferably wrong.",
        roast: "What would you hardcode first to make this careers page “work for now,” and which Postgres constraint " \
               "would eventually punish you for it?"
      },
      "Account Executive" => {
        description: "Sell BigBuck to teams who open with “we just need a simple ATS” and close with a 40-page RFP. You’ll " \
                     "survive discovery calls, translate “agent-first” into something a CHRO will buy, and never promise " \
                     "custom pipeline stages without checking with engineering first. Closing is encouraged. Overpromising " \
                     "is a performance issue.",
        roast: "Write the discovery-call opener you’d use on a prospect who says they “just need a simple ATS.” Include " \
               "one objection you already know is coming."
      },
      "Customer Success Manager" => {
        description: "Get recruiting teams live, then explain—warmly—why their 47 custom stages are why nothing syncs. " \
                     "You’ll write the empathy email, schedule the follow-up, and resist building another spreadsheet " \
                     "“just for now.” Prior experience surviving Kickoff Week preferred. Ability to sigh once per ticket " \
                     "is a soft skill.",
        roast: "A customer just added 47 custom pipeline stages and wonders why nothing syncs. Draft the empathy email. " \
               "You may sigh once."
      },
      "Senior Product Designer" => {
        description: "This careers page is Exhibit A. You’ll fix the spacing, retire “Country (ISO)” as a vibe, and make " \
                     "apply feel like a product instead of a weekend hack. Portfolio should include at least one form you " \
                     "are still slightly ashamed of. “Make it pop” is not a design direction here either.",
        roast: "In a few sentences: redesign this apply form so it doesn’t look like a weekend hack. Roast the spacing, " \
               "the field labels, and anything else that hurt. “Make it pop” is banned."
      },
      "Product Manager, Growth" => {
        description: "Own the talent CRM and decide which requests are roadmap, which are “interesting, thanks,” and which " \
                     "belong in a board deck with three bullets and no dates. You’ll prioritize this demo like it’s a real " \
                     "product (it isn’t, but don’t tell sales). Stakeholder archaeology required. “Synergy” is a reject.",
        roast: "Prioritize three improvements to this demo. For each, say whether it’s “roadmap,” “nice,” or “someone " \
               "will ask in a board meeting.”"
      },
      "Security Engineer" => {
        description: "Guard candidate data, row-level security, and our dignity when someone pastes a production token " \
                     "into Slack. You’ll threat-model the public apply flow, nag about buckets, and write the postmortem " \
                     "before the LinkedIn post writes itself. Paranoia is a plus. Uploading resumes to a free tier is a " \
                     "hard no.",
        roast: "Find three ways this public apply flow could go wrong (resume uploads optional). Rank them by how bad " \
               "the LinkedIn post would be."
      },
      "Software Engineering Intern (Summer 2027)" => {
        description: "You’ll ship real endpoints recruiters pretend to understand and at least one migration we swear is " \
                     "“final.” Half the seed data is named after computer scientists; your summer project is making sure " \
                     "none of them accidentally get offers. Curiosity required. Opinions about ORMs welcome; “just use " \
                     "Mongo” is a reject.",
        roast: "Sketch the API you’d add so recruiters stop asking for “one more CSV export.” Bonus: name the endpoint " \
               "something that won’t embarrass you in OpenAPI."
      },
      # —— New for V2 roles, same voice ——
      "Staff Site Reliability Engineer" => {
        description: "Be the reason the pager stays quiet when three agents and a recruiter all hit “bulk move” at once. " \
                     "You’ll own SLOs, queue depth, and the MySQL replica everyone forgot was there. Runbooks that a " \
                     "sleepy human can follow at 3 a.m. are the bar. “It works on my laptop” is not an availability tier.",
        roast: "Our webhook queue backs up every Monday at 9 a.m. Walk us through your first fifteen minutes on call, " \
               "and name the dashboard you’d delete."
      },
      "Sales Development Representative" => {
        description: "Book meetings with recruiting leaders who have been “evaluating ATS options” since 2019. You’ll " \
                     "research accounts, write openers that don’t start with “Hope this finds you well,” and hand " \
                     "Account Executives calls worth taking. Rejection resilience required. Sequence step 14 is a reject.",
        roast: "Write a two-sentence cold email to a Head of Talent whose team still schedules interviews by reply-all. " \
               "No “quick question” subject lines."
      },
      "Technical Recruiter" => {
        description: "Hire the people who build the hiring software, using the hiring software, while the people who " \
                     "build it watch. You’ll run full-cycle engineering searches, calibrate hiring managers who want “a " \
                     "10x Rust person, but chill,” and keep every candidate informed. Ghosting candidates is a fireable vibe.",
        roast: "A hiring manager rejects the third strong candidate for “culture fit.” Write the message you send them " \
               "before the next debrief."
      },
      "Chief of Staff" => {
        description: "Turn founder thoughts into plans, plans into owners, and owners into dates. You’ll run the operating " \
                     "cadence, write the memo nobody else wants to, and know which meetings can become a doc. Calendar " \
                     "Tetris at a competitive level. “Let’s circle back” is a reject.",
        roast: "Pick one recurring meeting this demo company obviously has. Kill it in writing, and say what replaces it."
      }
    }.freeze

    ROAST_KEY = "demo_roast"
  end
end
