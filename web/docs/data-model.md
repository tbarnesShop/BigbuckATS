# One person, many recruiting relationships

A person is a durable relationship. An application is one attempt to connect that person with a job. Keeping them separate lets a CRM relationship outlive a single hiring process.

## Organization is the boundary

Tenant-owned records carry an organization ID. Request identity establishes the organization; changing a URL does not grant access to a different tenant. Database composite foreign keys help keep related tenant records aligned.

Users can have memberships in organizations. A membership connects a user, a role, and any membership scope. An agent belongs to a membership, rather than becoming an independent organization administrator.

## People and applications

A person has contact points, affiliations, documents, consent information, and timeline activity. The same person can have multiple applications.

An application connects a person to a job and tracks progress through a pipeline. Stage changes are commands with transition rules. The person remains in the talent network after an application ends.

```json
{
  "person": {
    "display_name": "Nova Example",
    "email": "nova@example.test"
  }
}
```

Send this body to `POST /v1/people`. The live reference describes the documented contract; the explorer shows the actual response.

[Try in the lab →](/session?surface=api&operation=createPerson&step=person)

## Pools are relationships without a vacancy

A project is the API name for a talent pool. A project member connects a person to that pool. Pool membership can have its own pipeline and can later convert into a job application.

```json
{
  "member": {
    "person_id": "<person-id>"
  }
}
```

Use `POST /v1/projects/{id}/members` to connect the records. A duplicate membership is an error to inspect, not a reason to invent a success.

## Interviews and offers

Interviews belong to the hiring workflow and connect scheduling, interviewers, rubrics, and scorecards. Offers have versions and a lifecycle including approval and acceptance. Access to an offer does not automatically imply access to compensation.

## Versioned customization

Custom fields have typed definitions, definition versions, and typed values. Values record the definition version under which they were written. Type changes have impact previews and conversion rules.

Pipeline templates are also versioned. Publishing configuration does not mean every existing hiring workflow silently adopts it.

## Records across interfaces

REST IDs and GraphQL IDs refer to the same domain records. In Connect mode the record inspector and UI view stay in one sandbox. In Compare mode each surface has its own copy, so IDs differ even when the seed personas and people look familiar.
