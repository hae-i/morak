# Project Overview

This is a Flutter mobile application.

Main technologies:
- Flutter / Dart
- Supabase
- Cloudflare
- Additional services and packages should be inferred from the repository.

The goal of this repository is to maintain a stable, secure, production-ready mobile application.

# General Working Rules

- Preserve existing behavior unless the task explicitly requires a behavior change.
- Do not perform broad refactors unless explicitly requested.
- Prefer small, focused changes over large rewrites.
- Do not modify unrelated files.
- Do not change UI/UX unless explicitly requested.
- Do not add a new dependency unless it is clearly necessary.
- Before adding a dependency, explain why the existing stack cannot reasonably solve the problem.
- Never expose credentials, tokens, secrets, or private configuration values in output.
- If a secret is found in the repository, report its location without printing the secret value.
- Do not assume external dashboard settings are correct when they cannot be verified from the repository.

# Review Priorities

When reviewing or modifying this project, prioritize issues in this order:

1. Security vulnerabilities
2. Authentication / authorization issues
3. Data loss or data corruption
4. Runtime crashes
5. Incorrect application behavior
6. Async / lifecycle bugs
7. Network and API failure handling
8. Performance problems
9. Maintainability
10. Style and minor cleanup

Do not prioritize cosmetic refactoring over real user-facing issues.

# Flutter Guidelines

- Follow Dart null-safety rules.
- Be careful when using BuildContext after async gaps.
- Check `mounted` or `context.mounted` where appropriate.
- Avoid calling `setState` after a widget has been disposed.
- Review lifecycle behavior when using controllers, streams, subscriptions, timers, or listeners.
- Dispose controllers, subscriptions, focus nodes, animation controllers, and other disposable resources properly.
- Avoid unnecessary rebuilds.
- Avoid duplicate network requests caused by widget rebuilds.
- Keep business logic out of large UI widgets when practical.
- Preserve the existing state-management approach unless explicitly asked to change it.
- Do not introduce a new state-management library as part of an unrelated fix.

# Async and Error Handling

Pay special attention to:

- async / await flows
- Future and Stream handling
- race conditions
- duplicate requests
- loading-state bugs
- stale state
- unhandled exceptions
- retries
- timeouts
- navigation after async operations
- error states presented to users

Do not silently swallow exceptions.

User-facing errors should be understandable and should not expose internal implementation details.

# Supabase Guidelines

Treat Supabase authorization as a server-side security concern.

- Never rely only on Flutter UI checks to protect user data.
- Assume Row Level Security (RLS) must protect all user-specific tables.
- Identify code paths that appear to depend on missing or weak RLS policies.
- Distinguish clearly between:
  - problems visible in code
  - Supabase Dashboard / database configuration that cannot be verified from code
- Review authentication session handling.
- Review sign-in, sign-out, token refresh, and expired-session behavior.
- Review database reads, inserts, updates, and deletes for authorization assumptions.
- Review Storage usage and expected bucket policies.
- Check whether user data could be read or modified by another user.
- Prefer parameterized and typed queries where applicable.

# Supabase Secrets

- Supabase anon/public keys may be present in client applications when used as intended with proper RLS.
- A Supabase `service_role` key must never be embedded in Flutter client code.
- Server-side secrets must remain on trusted server infrastructure.
- If a privileged key appears in client code or committed configuration, classify it as Critical.
- Never reproduce the actual value of a discovered key in review output.

# Cloudflare Guidelines

Review Cloudflare Worker/API integrations for:

- authentication
- authorization
- request validation
- CORS behavior
- rate limiting
- timeout handling
- API failure handling
- secret management
- unexpected public endpoints
- replay or abuse risks where relevant

Secrets used by Cloudflare Workers should be stored in Cloudflare environment variables / secrets, not in Flutter client code.

Do not assume Worker environment variables or Cloudflare Dashboard settings are correct unless they are represented in code or configuration available in this repository.

# API and Network Rules

- Validate API responses before using them.
- Handle non-2xx responses.
- Handle malformed or missing response fields.
- Handle timeout and connectivity failures.
- Avoid unlimited retry loops.
- Avoid duplicate API calls where possible.
- Do not log sensitive request or response data.

# Data and Privacy

Pay attention to:

- personally identifiable information
- user-generated content
- authentication tokens
- API tokens
- database identifiers
- uploaded files
- logs
- analytics events

Do not expose sensitive information in:
- application logs
- crash reports
- debug output
- error messages
- source control

# Code Review Behavior

When asked to review the entire project:

1. First inspect the repository structure.
2. Identify the application's main flows and high-risk areas.
3. Do not deeply inspect every file equally.
4. Prioritize authentication, database access, Cloudflare/API calls, state management, async code, and persistence.
5. Report findings before making changes unless explicitly asked to modify code.

Classify findings as:

- Critical
- High
- Medium
- Low

For each significant finding provide:
- problem
- impact
- evidence
- relevant file path
- relevant class/function where possible
- recommended direction

Avoid reporting hypothetical issues without reasonable evidence from the code.

# Editing Rules

When implementing a fix:

- Fix only the requested issue unless another change is required for correctness.
- Avoid opportunistic cleanup.
- Keep diffs small and understandable.
- Preserve public APIs where practical.
- Preserve current UI behavior unless explicitly asked otherwise.
- Explain any unavoidable behavioral change.

# Validation

After code changes, run appropriate checks when available.

At minimum, prefer:

```bash
flutter analyze
```

Also run relevant tests when practical:

```bash
flutter test
```

If generated code is used, follow the project's existing generation workflow rather than inventing a new one.

If a command cannot be run because of missing dependencies, credentials, platform requirements, or environment limitations, state that clearly.

Never claim a test or validation command passed unless it was actually executed successfully.

# Configuration Files

Be careful when modifying:

- `.env` files
- Supabase configuration
- Cloudflare configuration
- Android signing configuration
- iOS signing configuration
- Firebase or push-notification configuration
- build scripts
- CI/CD files

Do not replace or delete configuration values unless explicitly required.

# Large Changes

For significant architecture changes, migrations, or large refactors:

- analyze the current structure first
- explain the proposed approach before implementation
- identify migration risks
- avoid rewriting large areas of working code without a clear benefit

If the user asks only for analysis, do not modify the repository.

# Communication

Keep explanations concrete and tied to the actual code.

Prefer:
- exact file paths
- class/function names
- specific failure scenarios

Avoid:
- vague best-practice lectures
- unnecessary rewrites
- speculative issues presented as facts

When external configuration cannot be verified from the repository, explicitly label it:

`Cannot verify from repository; check external configuration.`