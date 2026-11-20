# Power with an address and a boundary

Every authenticated request resolves a credential into a principal: organization, human membership, optional agent, and effective permissions.

## Role and scope are different

A role defines the member's permission vocabulary. A membership scope can constrain the teams or records they work with. Credential and agent scopes can narrow permissions further.

A hiring manager's access is not the same as a recruiter’s. An Owner has the broad product role, but still belongs to one organization and remains subject to the demo policy.

## The same rule behind every interface

REST controllers authorize actions. GraphQL fields and mutations declare permissions and use visibility-aware resolvers. MCP tools, CLI commands (including `bigbuck api`), and the UI all forward credentials to the same Rails API.

The UI may hide an unavailable control, but the server remains responsible for refusing an unauthorized request.

[Try in the lab →](/session?surface=mcp&operation=gql_whoami)

## Visibility is not just read access

Public, restricted, confidential, and private people have different visibility. Confidential jobs and pools have their own requirements. Getting permission to read one class of object does not automatically disclose every related record.

The role/scope inspector in the lab displays permissions resolved by Rails, rather than calculating authority from a role label in the browser.

## Domain constraints still apply

Moving an application must follow the pipeline's allowed transitions. Versioned mutations can reject a stale expected version. Offer approval checks who may approve. Duplicate memberships and invalid typed custom-field values can also be refused.

Read the error, refresh the record, and decide whether the request should change. Retrying the same invalid input is not progress.

## Extra rules in shared demos

The lab blocks delete, archive, erasure, equivalent destructive actions, and identity changes that could bypass restrictions. These are additional limits on registered lab organizations, not changes to product roles.

An Owner attempting a forbidden operation receives `demo_action_blocked`. A user without a necessary product permission may receive `insufficient_permission`. A refreshed workspace invalidates the old session.

```json
{
  "code": "demo_action_blocked",
  "title": "This action is blocked in shared demo workspaces to preserve sample records and identity."
}
```

This is a documentation excerpt showing the error fields, not the full problem response envelope.

## Try the failure path

Choose Owner, inspect an archive tool, and attempt it on a sample record. Then choose a hiring manager and try creating a person. The first is a shared-demo boundary; the second is a role boundary.

[Prepare an archive request →](/session?surface=api&operation=archiveCustomField)

Preparing an example never executes it.
