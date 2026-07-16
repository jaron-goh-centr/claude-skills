---
name: pp-mercury
description: "Mercury business banking CLI — accounts, balances, transactions, recipients, payments, statements. Trigger phrases: `check mercury balance`, `list mercury transactions`, `mercury account activity`, `send payment via mercury`, `use mercury-pp-cli`, `run mercury`. Only for Mercury (mercury.com) banking — not other payment APIs. Read operations run freely; any operation that moves money or creates/edits recipients requires explicit user confirmation first."
author: "Cathryn Lavery"
license: "Apache-2.0"
argument-hint: "<command> [args] | install cli|mcp"
allowed-tools: "Read Bash"
metadata:
  openclaw:
    requires:
      bins:
        - mercury-pp-cli
    install:
      - kind: go
        bins: [mercury-pp-cli]
        module: github.com/mvanhorn/printing-press-library/library/payments/mercury/cmd/mercury-pp-cli
---

# Mercury — Printing Press CLI

## Prerequisites: Install the CLI

This skill drives the `mercury-pp-cli` binary. **You must verify the CLI is installed before invoking any command from this skill.** If it is missing, install it first:

1. Install via the Printing Press installer:
   ```bash
   npx -y @mvanhorn/printing-press install mercury --cli-only
   ```
2. Verify: `mercury-pp-cli --version`
3. Ensure `$GOPATH/bin` (or `$HOME/go/bin`) is on `$PATH`.

If the `npx` install fails (no Node, offline, etc.), fall back to a direct Go install (requires Go 1.26.3 or newer):

```bash
go install github.com/mvanhorn/printing-press-library/library/payments/mercury/cmd/mercury-pp-cli@latest
```

If `--version` reports "command not found" after install, the install step did not put the binary on `$PATH`. Do not proceed with skill commands until verification succeeds.

## Unique Capabilities

These capabilities aren't available in any other tool for this API.

- **`workflow payment-plan`** — Builds a read-only approval plan with body, idempotency key, dry-run command, and execute command before payment or transfer writes.

  _Agents can prepare exact write commands without moving money._

  ```bash
  mercury-pp-cli workflow payment-plan --kind transfer --source-account-id acct_src --destination-account-id acct_dst --amount 25 --agent
  ```
- **`workflow archive`** — Syncs supported Mercury resources into a local SQLite store for offline search and analytics.

  _Reduces API calls and gives agents repeatable context._

  ```bash
  mercury-pp-cli workflow archive --agent
  ```
- **`agent-context`** — Emits machine-readable command metadata for agents and MCP hosts.

  _Improves autonomous command selection and reduces context waste._

  ```bash
  mercury-pp-cli agent-context --agent
  ```

## Command Reference

**account** — Manage bank accounts

- `mercury-pp-cli account <accountId>` — Get account by ID

**accounts** — Manage bank accounts

- `mercury-pp-cli accounts` — Retrieve a paginated list of accounts. Supports cursor-based pagination with limit, order, start_after, and...

**ar** — Manage ar

- `mercury-pp-cli ar cancel-invoice` — Cancel an invoice. This action cannot be undone.
- `mercury-pp-cli ar create-customer` — Create a new customer for the organization
- `mercury-pp-cli ar create-invoice` — Create a new invoice for the organization
- `mercury-pp-cli ar delete-customer` — Delete a customer. This action cannot be undone.
- `mercury-pp-cli ar get-attachment` — Retrieve attachment details including download URL
- `mercury-pp-cli ar get-customer` — Retrieve details of a specific customer by their ID
- `mercury-pp-cli ar get-invoice` — Retrieve details of an invoice by its ID
- `mercury-pp-cli ar get-invoice-pdf` — Downloads a PDF file for the specified invoice. The response includes a Content-Disposition header set to...
- `mercury-pp-cli ar list-customers` — Retrieve a paginated list of customers. Supports cursor-based pagination with limit, order, start_after, and...
- `mercury-pp-cli ar list-invoice-attachments` — Retrieve a list of all attachments for a specific invoice
- `mercury-pp-cli ar list-invoices` — Retrieve a paginated list of invoices. Supports cursor-based pagination with limit, order, start_after, and...
- `mercury-pp-cli ar update-customer` — Update an existing customer
- `mercury-pp-cli ar update-invoice` — Update an existing invoice

**books** — Manage organization books

- `mercury-pp-cli books delete-agent-coa-template` — Delete a specific Chart of Accounts template.
- `mercury-pp-cli books delete-agent-ledger-template` — Delete an existing ledger within an agent-owned Chart of Accounts template.
- `mercury-pp-cli books delete-journal-entries` — Bulk delete journal entries
- `mercury-pp-cli books get-agent-coa-template` — Retrieve details of a specific Chart of Accounts template.
- `mercury-pp-cli books get-agent-coa-templates` — Retrieve a paginated list of all default and agent-owned Chart of Accounts templates. These templates can be used...
- `mercury-pp-cli books get-journal-entries` — List all journal entries
- `mercury-pp-cli books get-journal-entry` — Retrieve a Journal Entry
- `mercury-pp-cli books post-agent-coa-templates` — Create a new agent-owned Chart of Accounts template. These templates can be used when creating new Books instances...
- `mercury-pp-cli books post-agent-ledger-templates` — Create a new ledger within an agent-owned Chart of Accounts template.
- `mercury-pp-cli books post-journal-entries` — Create multiple Journal Entries
- `mercury-pp-cli books put-agent-ledger-template` — Update an existing ledger within an agent-owned Chart of Accounts template.
- `mercury-pp-cli books put-journal-entries` — Bulk update journal entries

**cards** — Manage cards

- `mercury-pp-cli cards create` — Issue a new virtual card.
- `mercury-pp-cli cards get` — Retrieve details of a specific card by its ID.
- `mercury-pp-cli cards list` — Retrieve a paginated list of cards.
- `mercury-pp-cli cards update` — Update a card's nickname or spending limits.

**categories** — Manage expense categories

- `mercury-pp-cli categories create-category` — Create a new custom expense category for the organization.
- `mercury-pp-cli categories list` — Retrieve a paginated list of all available custom expense categories for the organization. Supports cursor-based...

**credit** — Manage credit accounts

- `mercury-pp-cli credit` — Retrieve a list of all credit accounts for the organization.

**events** — Manage API events

- `mercury-pp-cli events get` — Get all events
- `mercury-pp-cli events get-eventid` — Get event by ID

**organization** — Organization information

- `mercury-pp-cli organization` — Retrieve information about your organization including EIN, legal business name, and DBAs.

**recipient** — Manage payment recipients

- `mercury-pp-cli recipient get` — Retrieve details of a specific recipient by ID
- `mercury-pp-cli recipient update` — Edit information about a specific recipient

**recipients** — Manage payment recipients

- `mercury-pp-cli recipients create` — Create a new recipient for making payments
- `mercury-pp-cli recipients get` — Retrieve a paginated list of all recipients. Use cursor parameters (start_after, end_before) for pagination.
- `mercury-pp-cli recipients list-attachments` — Retrieve a paginated list of all recipient tax form attachments across all recipients in the organization. Use...

**request-send-money** — Manage request send money

- `mercury-pp-cli request-send-money get-send-money-approval-request` — Get send money approval request by ID
- `mercury-pp-cli request-send-money list-send-money-approval-requests` — Retrieve a paginated list of send money approval requests for the authenticated organization. Supports filtering by...

**safes** — Manage SAFE (Simple Agreement for Future Equity) requests

- `mercury-pp-cli safes get-request` — Retrieve a specific SAFE request by its ID.
- `mercury-pp-cli safes get-requests` — Retrieve all SAFE (Simple Agreement for Future Equity) requests for your organization.

**statements** — Download account statements


**transaction** — Manage transactions

- `mercury-pp-cli transaction get-by-id` — Retrieve a single transaction by its ID. Returns full transaction details including attachments, check images, and...
- `mercury-pp-cli transaction update` — Update the note and/or category of an existing transaction. Use null values to clear existing data.

**transactions** — Manage transactions

- `mercury-pp-cli transactions` — Retrieve a paginated list of all transactions across all accounts. Supports advanced filtering by date ranges,...

**transfer** — Manage transfer

- `mercury-pp-cli transfer` — Transfer funds between two accounts within the same organization. Supports transfers between depository accounts...

**treasury** — Manage treasury accounts and transactions

- `mercury-pp-cli treasury` — Retrieve a paginated list of all treasury accounts associated with the authenticated organization. Use cursor...

**users** — Manage organization team members

- `mercury-pp-cli users get` — Get all users
- `mercury-pp-cli users get-userid` — Get user by ID

**webhooks** — Manage webhooks

- `mercury-pp-cli webhooks create` — Register a new webhook endpoint to receive event notifications
- `mercury-pp-cli webhooks delete` — Delete a webhook endpoint
- `mercury-pp-cli webhooks get` — Retrieve a paginated list of all webhook endpoints for your organization. Supports filtering by status.
- `mercury-pp-cli webhooks get-webhookendpointid` — Retrieve details of a specific webhook endpoint by ID
- `mercury-pp-cli webhooks update` — Update the configuration of an existing webhook endpoint. A webhook that has been disabled due to consecutive...


### Finding the right command

When you know what you want to do but not which command does it, ask the CLI directly:

```bash
mercury-pp-cli which "<capability in your own words>"
```

`which` resolves a natural-language capability query to the best matching command from this CLI's curated feature index. Exit code `0` means at least one match; exit code `2` means no confident match — fall back to `--help` or use a narrower query.

## Auth Setup

Store your access token:

```bash
mercury-pp-cli auth set-token YOUR_TOKEN_HERE
```

Or set `MERCURY_BEARER_AUTH` as an environment variable.

Run `mercury-pp-cli doctor` to verify setup.

## Agent Mode

Add `--agent` to any command. Expands to: `--json --compact --no-input --no-color --yes`.

- **Pipeable** — JSON on stdout, errors on stderr
- **Filterable** — `--select` keeps a subset of fields. Dotted paths descend into nested structures; arrays traverse element-wise. Critical for keeping context small on verbose APIs:

  ```bash
  mercury-pp-cli account mock-value --agent --select id,name,status
  ```
- **Previewable** — `--dry-run` shows the request without sending
- **Offline-friendly** — sync/search commands can use the local SQLite store when available
- **Non-interactive** — never prompts, every input is a flag
- **Explicit retries** — use `--idempotent` only when an already-existing create should count as success, and `--ignore-missing` only when a missing delete target should count as success

### Response envelope

Commands that read from the local store or the API wrap output in a provenance envelope:

```json
{
  "meta": {"source": "live" | "local", "synced_at": "...", "reason": "..."},
  "results": <data>
}
```

Parse `.results` for data and `.meta.source` to know whether it's live or local. A human-readable `N results (live)` summary is printed to stderr only when stdout is a terminal — piped/agent consumers get pure JSON on stdout.

## Agent Feedback

When you (or the agent) notice something off about this CLI, record it:

```
mercury-pp-cli feedback "the --since flag is inclusive but docs say exclusive"
mercury-pp-cli feedback --stdin < notes.txt
mercury-pp-cli feedback list --json --limit 10
```

Entries are stored locally at `~/.mercury-pp-cli/feedback.jsonl`. They are never POSTed unless `MERCURY_FEEDBACK_ENDPOINT` is set AND either `--send` is passed or `MERCURY_FEEDBACK_AUTO_SEND=true`. Default behavior is local-only.

Write what *surprised* you, not a bug report. Short, specific, one line: that is the part that compounds.

## Output Delivery

Every command accepts `--deliver <sink>`. The output goes to the named sink in addition to (or instead of) stdout, so agents can route command results without hand-piping. Three sinks are supported:

| Sink | Effect |
|------|--------|
| `stdout` | Default; write to stdout only |
| `file:<path>` | Atomically write output to `<path>` (tmp + rename) |
| `webhook:<url>` | POST the output body to the URL (`application/json` or `application/x-ndjson` when `--compact`) |

Unknown schemes are refused with a structured error naming the supported set. Webhook failures return non-zero and log the URL + HTTP status on stderr.

## Named Profiles

A profile is a saved set of flag values, reused across invocations. Use it when a scheduled agent calls the same command every run with the same configuration - HeyGen's "Beacon" pattern.

```
mercury-pp-cli profile save briefing --json
mercury-pp-cli --profile briefing account mock-value
mercury-pp-cli profile list --json
mercury-pp-cli profile show briefing
mercury-pp-cli profile delete briefing --yes
```

Explicit flags always win over profile values; profile values win over defaults. `agent-context` lists all available profiles under `available_profiles` so introspecting agents discover them at runtime.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 2 | Usage error (wrong arguments) |
| 3 | Resource not found |
| 4 | Authentication required |
| 5 | API error (upstream issue) |
| 7 | Rate limited (wait and retry) |
| 10 | Config error |

## Argument Parsing

Parse `$ARGUMENTS`:

1. **Empty, `help`, or `--help`** → show `mercury-pp-cli --help` output
2. **Starts with `install`** → ends with `mcp` → MCP installation; otherwise → see Prerequisites above
3. **Anything else** → Direct Use (execute as CLI command with `--agent`)
## MCP Server Installation

1. Install the MCP server:
   ```bash
   go install github.com/mvanhorn/printing-press-library/library/payments/mercury/cmd/mercury-pp-mcp@latest
   ```
2. Register with Claude Code:
   ```bash
   claude mcp add mercury-pp-mcp -- mercury-pp-mcp
   ```
3. Verify: `claude mcp list`

## Direct Use

1. Check if installed: `which mercury-pp-cli`
   If not found, offer to install (see Prerequisites at the top of this skill).
2. Match the user query to the best command from the Unique Capabilities and Command Reference above.
3. Execute with the `--agent` flag:
   ```bash
   mercury-pp-cli <command> [subcommand] [args] --agent
   ```
4. If ambiguous, drill into subcommand help: `mercury-pp-cli <command> --help`.
