# Follow a change all the way through

The interface is an entry point. Authentication, authorization, business rules, and transactional change recording determine what actually happens.

## From request to change

A credential resolves to a principal. The request establishes tenant and actor context. Permissions and visibility limit access. A domain command validates its own rules before committing changes.

`ChangeWriter` writes the domain record, audit event, and optional outbox event in one database transaction. Passing no event type creates an audit-only change. Model-level audit recording covers other audited model saves.

## Who, for whom, through what

An audit record identifies the resource and action, actor, human on whose behalf an agent acted, credential, source surface, API version, and request ID.

The source surface is request metadata. It is useful for attribution, but it is not an independent proof that a particular desktop client originated a request.

## Redaction is deliberate

Columns have declared data classes. Audit history stores internal changes as-is, hashes PII and sensitive values with keyed HMACs, and omits secrets. Custom-field values follow their field's data class.

This means audit history is not a second plaintext copy of a candidate's private data. A redacted value cannot be treated as a recoverable original.

## Outbox before delivery

An outbox event records something that happened in the domain transaction. A relay fans events into webhook deliveries. Delivery has its own status, retries, and backoff; a committed change is not proof that an external service received a webhook.

Shared lab webhooks are captured locally. They are not transmitted to an arbitrary destination.

## Inspect with the right permission

Live event access requires `audit.read`. The lab only requests live event data for a persona whose effective permissions include that permission. Other personas can read this documentation example:

```json
{
  "action": "project_member.added",
  "actor_type": "agent",
  "actor_id": "<agent-id>",
  "on_behalf_of_id": "<human-id>",
  "resource_type": "ProjectMember",
  "resource_id": "<membership-id>",
  "source_surface": "mcp"
}
```

The example is illustrative, with placeholders. It does not expose a real visitor's credential or history.

## Append-only, with a demo exception

Database triggers enforce append-only audit events. Resetting a registered demo sandbox uses the explicit demo purge mechanism. Production audit retention and database grants remain deployment responsibilities.
