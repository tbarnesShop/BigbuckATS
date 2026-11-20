# Privacy and compliance are mechanics

Recruiting systems retain personal data, process requests, and make information available to different people. Big Buck implements several mechanics for those responsibilities. This page describes behavior, not legal advice or a certification.

## Data classes

Columns are classified as internal, PII, sensitive, secret, or dynamic. Audit redaction uses those declarations. New columns need deliberate classification; development/test checks catch unclassified columns.

Custom fields carry their own data class, so extensibility does not require treating every custom value as harmless text.

## Consent and notices

People can have append-only consent records and notice receipts. These preserve the context of consent rather than silently replacing history.

Recording a consent value does not establish that every use of the data is lawful. The surrounding policy, notice, and operational process matter.

## Retention and holds

Retention policies evaluate candidate records and their activity. Existing applications, employee status, legal holds, and configured rules affect what may happen. A legal hold refuses erasure.

The automated retention sweep skips registered lab organizations. Their lifecycle is the hourly sandbox reset, which preserves a consistent demonstration baseline.

## Access and erasure requests

The product supports data-subject requests, access packets, and completion/rejection workflows with policy-derived due dates.

Erasure handles more than the primary person row: custom values, uploaded documents, staged import CSV, and relevant cached responses are part of the implementation. Anonymization and deletion have different behavior, and legal holds are checked.

Erasure cannot be executed in shared demo workspaces. Read the endpoint contract and implementation behavior without destroying shared sample data.

## Interoperability does not remove the boundary

Moving a workflow into MCP or CLI does not exempt it from visibility, authorization, legal holds, or audit behavior. Export is a distinct capability and is not implied by every read permission.

## What is not claimed

The proof of concept is not a claim of SOC 2 certification, penetration-test completion, production hardening, or universal compliance with privacy law. SAML/SCIM and several provider integrations remain planned. See [Reference and limitations](/docs/limitations).
