# 23 — Org Structure: Dimensions and Variables

## Goal

Every company describes itself differently. One has departments and teams; another has business units, functions and pods; a third hires by discipline and level across legal entities in four countries. Big Buck should not hard-code any of these. It should let each company define its own way of slicing the organization, including attributes we never anticipated, and then use those slices everywhere: permissions, reporting, template selection, approvals and message variables.

This replaces the fixed `departments` and `locations` tables and settles the open question in [`recruiting-as-code.md`](./recruiting-as-code.md#open-questions) about whether departments are configuration or HRIS data: each dimension decides.

## The model in one paragraph

A company defines **dimensions** (Department, Discipline, Level, Business unit, Region, Cost center, anything). Each dimension has **values**, optionally arranged in a tree (Engineering → Platform → Infrastructure). Each dimension can declare **attributes** its values carry, which are ordinary typed custom fields (a department's head, a cost center code, a level's salary band id). Requisitions, jobs, postings, users and other records are **tagged** with dimension values. Because everything is keyed, the same dimension powers access rules ("recruiters see Engineering and below"), reports ("time to hire by Discipline"), default pipeline templates ("Backend jobs use `engineering-hiring`") and template variables (`{{ job.department.head.name }}`).

## Concepts

### Dimension
| Field | Meaning |
|---|---|
| `key`, `label`, `pluralLabel` | `discipline`, "Discipline", "Disciplines". Labels are free, so "Department" can be called "Function" |
| `hierarchical` | Values form a tree |
| `ordered` | Values have a meaningful order (levels: IC1 < IC2 < IC3) |
| `multiple` | A record can carry more than one value (a job open in two regions) |
| `appliesTo` | Which records can be tagged: `requisition`, `job`, `posting`, `user`, `person`, `project` |
| `requiredFor` | Which of those must have a value (a job cannot open without a Department) |
| `valuesSource` | Where values come from: `config` (in files, reviewed by pull request), `ui` (admins edit them in Big Buck), `hris` (synced from Workday, BambooHR, Rippling and the like; read-only in Big Buck) |
| `attributes` | Typed fields every value of this dimension carries |
| `priority` | Tie-breaker when several dimensions point at different templates |
| `system` | Seeded by Big Buck (`department`, `location`); renameable and extendable, not deletable |

### Dimension value
| Field | Meaning |
|---|---|
| `key`, `label` | `platform`, "Platform" |
| `parent` | For hierarchical dimensions |
| `position` | For ordered dimensions |
| `status` | `active` or `archived`; values in use are archived, never deleted |
| `externalRef` | The HRIS id, for synced dimensions |
| attribute values | Stored as typed custom field values, so they are validated, filterable and reportable |

### Attributes: "variables we don't have"
Attributes are how a company adds data Big Buck never shipped. They reuse the custom field system ([`data-model.md`](./data-model.md#custom-field-definitions)), so every type works: text, number, select, date, and **references** to users, pipelines or other dimension values. Examples:

| Dimension | Attribute | Type | Used for |
|---|---|---|---|
| Department | `head` | reference → user | Approval routing, email signature variables |
| Department | `cost-center` | text | Exports to finance |
| Business unit | `legal-entity` | reference → Legal entity value | Offer letter templates |
| Level | `band` | text | Compensation visibility rules |
| Level | `interview-loop-size` | number | Guards ("onsite needs this many scorecards") |
| Discipline | `default-sequence` | reference → sequence | Sourcing defaults |
| Location | `timezone`, `country` | system attributes | Scheduling, compliance rules per country |

### Organization variables
Some values belong to the company, not to a dimension: the careers site URL, the benefits page, the recruiting inbox, the standard interview prep guide. These are an organization **variable set**: typed key-value pairs available to templates and automations as `{{ org.vars.benefits-url }}`. They are configuration like everything else, so they are versioned and can live in files.

### Tagging
Records carry dimension values by dimension key:

```json
{
  "title": "Staff Platform Engineer",
  "dimensions": {
    "department": "platform",
    "discipline": "backend",
    "level": "ic6",
    "region": ["us-east", "emea"]
  }
}
```

Rules:
- any dimension can apply to people (`appliesTo: [person, …]`). Of the two seeded dimensions, `location` does by default and `department` does not, because a candidate is not yet in a department (a company can turn it on). Company-defined dimensions choose for themselves; the discipline and level examples below include `person`
- values are addressed by key in the API and in files; ids exist but integrations never need them
- a requisition's values are copied to the jobs created from it and can be changed per job
- `requiredFor` is enforced when a record is created and when a job is opened
- archived values stay on old records and cannot be added to new ones

## What dimensions drive

| Area | How it uses dimensions |
|---|---|
| **Permissions** | A membership can be scoped to dimension values, alone or combined: "recruiter for Department = Engineering, including sub-departments", or "Engineering *and* Region = EMEA". Scoped access covers requisitions, jobs and their applications. This is the "resource scope" layer in [`permissions.md`](./permissions.md#3-resource-scope) |
| **Candidates and prospects** | People can be tagged too ("Discipline: Backend, Level: IC5" on a sourced prospect). Big Buck then suggests matching people when a job with the same tags opens, filters talent pools by them, and reports on pipeline supply by discipline |
| **Reporting** | Every report and export can group or filter by any dimension, at any depth of a tree |
| **Default pipeline template** | Templates claim dimension values (`defaultFor: { discipline: [backend] }`); the most specific claim wins ([`job-pipelines.md`](./job-pipelines.md#default-template-selection)) |
| **Approvals** | Approval steps can name a dimension attribute: "offer approved by the job's `department.head`" |
| **Variables** | Message templates, automations and offer letters can use `{{ job.department.label }}`, `{{ job.dimensions.level.attributes.band }}` and `{{ org.vars.* }}` |
| **Careers site** | Postings filter by any dimension tagged on them (`appliesTo: posting`) |
| **Guards** | Stage guards can read attributes: `scorecards_submitted: { min: "{{ job.dimensions.level.attributes.interview-loop-size }}" }` |

## Where values come from

Each dimension picks its source, because the right answer differs:

| Source | Good for | Behavior |
|---|---|---|
| `config` | Small, deliberate lists: disciplines, levels, regions | Values live in the dimension's file; changes go through `plan` and `apply` and show their impact ("12 open jobs use `frontend`") |
| `ui` | Lists recruiting ops change often and do not want in git | Admins edit in Big Buck; each change is still a config revision |
| `hris` | Departments, cost centers, legal entities that the HR system owns | A scheduled sync creates, renames and archives values using `externalRef`; Big Buck never edits them; attributes not in the HRIS can still be filled in Big Buck |

Removing or merging a value that is in use requires a target (`reassignTo`), exactly like removing a pipeline stage that holds applications.

## Configuration files

```yaml
apiVersion: bigbuck/v1
kind: Dimension
metadata:
  key: discipline
  name: Discipline
spec:
  pluralLabel: Disciplines
  hierarchical: true
  appliesTo: [requisition, job, posting, user, person]
  requiredFor: [job]
  valuesSource: config
  priority: 10
  attributes:
    - key: default-sequence
      label: Default sourcing sequence
      type: reference
      references: sequence
  values:
    - key: engineering
      label: Engineering
      children:
        - key: backend
          label: Backend
          attributes: { default-sequence: senior-backend-outreach }
        - key: frontend
          label: Frontend
    - key: design
      label: Design
```

```yaml
apiVersion: bigbuck/v1
kind: Dimension
metadata:
  key: department
  name: Department
spec:
  system: true
  hierarchical: true
  appliesTo: [requisition, job, user]
  requiredFor: [requisition, job]
  valuesSource: hris        # values come from the HRIS; this file defines the shape only
  priority: 20
  attributes:
    - key: head
      label: Department head
      type: reference
      references: user
    - key: cost-center
      label: Cost center
      type: text
```

```yaml
apiVersion: bigbuck/v1
kind: Dimension
metadata:
  key: level
  name: Level
spec:
  ordered: true
  appliesTo: [requisition, job, person]
  valuesSource: config
  attributes:
    - key: band
      label: Compensation band
      type: text
      visibleTo: [recruiting-admin, finance-approver]
    - key: interview-loop-size
      label: Onsite interviews
      type: number
  values:
    - { key: ic4, label: "IC4 · Senior", attributes: { band: B4, interview-loop-size: 4 } }
    - { key: ic5, label: "IC5 · Staff", attributes: { band: B5, interview-loop-size: 5 } }
    - { key: ic6, label: "IC6 · Senior Staff", attributes: { band: B6, interview-loop-size: 5 } }
```

```yaml
apiVersion: bigbuck/v1
kind: VariableSet
metadata:
  key: org
  name: Organization variables
spec:
  variables:
    - { key: careers-url, type: url, value: "https://acme.example/careers" }
    - { key: benefits-url, type: url, value: "https://acme.example/benefits" }
    - { key: recruiting-inbox, type: email, value: "recruiting@acme.example" }
```

## API

| Action | Endpoint |
|---|---|
| List dimensions | `GET /dimensions` |
| Read one, with its values as a tree | `GET /dimensions/{key}?include=values` |
| Add a value (`ui` dimensions only) | `POST /dimensions/{key}/values` |
| Edit a value or its attributes | `PATCH /dimensions/{key}/values/{value_key}` |
| Archive or merge a value | `POST /dimensions/{key}/values/{value_key}/archive` with `reassign_to` |
| Tag records | `dimensions` object on requisitions, jobs, postings, users |
| Filter by a value and its descendants | `filter[dimensions.department]=engineering&filter[dimensions.department][descendants]=true` |
| Organization variables | `GET /variables`, and through config files |

Events: `dimension.value_created`, `dimension.value_updated`, `dimension.value_archived`, plus the normal `updated` events on tagged records.

## Tables

`dimensions`, `dimension_values`, `dimension_value_closure` (ancestor and descendant pairs, so "Engineering and everything under it" is one indexed join), `entity_dimension_values`, `membership_scopes` and `membership_scope_conditions`. Attributes reuse `custom_field_definitions` and `custom_field_values`. The implemented columns are in [`db/structure.sql`](../db/structure.sql).

## Decisions (2026-10-24)

1. **People can be tagged with dimensions.** Any dimension can include `person` in `appliesTo`; the seeded `location` dimension does out of the box.
2. **Permission scopes can combine dimensions in v1.** Within one scope, values of the same dimension are alternatives and different dimensions must all match; a membership can hold several scopes ([`permissions.md`](./permissions.md#3-resource-scope)).
3. **Who may define dimensions or edit their values** is a permission (`dimension.manage`), set by each company like every other setting ([`permissions.md`](./permissions.md#every-setting-is-a-permission)).
