# An agent is someone acting for someone

An agent is a first-class principal: it has its own identity, lifecycle, scopes, and credentials. It belongs to a human's organization membership. A recruiter is a useful example, but other member roles can own agents too.

This gives the system a durable answer to two different questions: **who performed this action, and who were they acting for?**

## Ownership is a relationship

An agent's `owner_membership_id` connects it to a member of the organization. The membership supplies the human owner, role, and organizational scope. The agent supplies a distinct actor identity and its own scopes.

Integration credentials are different. They represent an organization-level integration with explicit scopes, without borrowing a human's membership.

## Permission is an intersection

For an agent credential:

```text
effective permissions = owner's role permissions ∩ agent scope permissions
```

When a personal credential acts as an owned agent, that credential's scopes impose another intersection. A browser session acting as an agent remains bounded by the owner's role and agent scopes.

Permission vocabulary is only one layer. Tenant boundaries, membership scope, person visibility, confidential-object rules, and domain constraints still apply.

## Freedom lives above the boundary

The client can be a tool explorer, an assistant in a different application, or a future conversational agent. Changing the model or client does not move permission enforcement into a prompt.

An agent can retrieve context and perform allowed operations through the same services as a person. It cannot acquire the owner's permissions merely by asking for them. A hiring manager's agent does not become an org-wide recruiter.

The V1 lab demonstrates live MCP tools. It does not run a language model, autonomously decide whom to hire, or simulate an assistant's answer. A conversational layer is planned for V2.

[Try in the lab: inspect the current agent →](/session?surface=mcp&operation=gql_whoami&step=identity)

## Lifecycle and credentials

Agents may be active, paused, or revoked. An agent is inactive if its owning membership is inactive. The authenticator checks these relationships on requests.

Bearer credentials can expire or be revoked. Plaintext credentials are returned once at issuance; the database stores a digest. The lab stores API and agent credentials on the Node host and keeps only an opaque reference in its signed, HTTP-only browser session. The server forwards these credentials to Rails; they expire with the sandbox generation. The existing UI session still uses its own HTTP-only bearer session.

The identity API prohibits agents from creating or changing agents and credentials. Human ownership is not a mechanism for agents to recursively expand their authority.

## Accountability without impersonation

An agent write records the agent as the actor and the human as `on_behalf_of`. Audit rows also identify the credential, source surface, API version, request, and resource.

```json
{
  "actor_type": "agent",
  "actor_id": "<agent-id>",
  "on_behalf_of_id": "<owner-user-id>",
  "credential_id": "<credential-id>",
  "source_surface": "mcp"
}
```

This is a labeled documentation example, not a live audit row. Live audit history requires its own permission.

## Where the guarantee stops

These controls constrain access and record changes. They do not guarantee the quality of a model's reasoning, the fairness of a hiring decision, or legal compliance. A future agent still needs a well-designed human workflow around the tools.
