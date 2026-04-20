# Contributing to ClawDeck

Thank you for your interest in contributing to ClawDeck.

## Getting Started

1. Clone the repository: `git clone https://github.com/SweetSophia/clawdeck.git`
2. Create a branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run checks: `bin/ci`
5. Commit with a clear message
6. Push your branch and open a Pull Request

## Development Setup

Preferred local setup:

```bash
docker compose up --build
```

Native setup is also supported:

```bash
bundle install
bin/rails db:prepare
bin/dev
```

## Code Style

- Follow existing code patterns
- Run `bin/rubocop` before committing
- Write tests for new features
- Update docs when behavior or architecture changes

## Checks

Core validation command:

```bash
bin/ci
```

Useful individual commands:

```bash
bin/rubocop
bin/bundler-audit
bin/importmap audit
bin/brakeman --no-pager
bin/rails test
bin/rails test:system
```

If your host environment does not have the full Ruby/Bundler toolchain available, use Docker-based commands instead.

## Pull Request Guidelines

- Keep PRs focused on a single change
- Add or update tests when behavior changes
- Update related docs in the same PR
- Reference related issues in the PR description when relevant

If you touch API or agent behavior, also review:
- `docs/AGENT_INTEGRATION.md`
- `docs/api/OPENAPI_REFERENCE.md`
- `docs/sdk/GO_AGENT_SDK.md`

## Reporting Issues

- Search existing issues first
- Include steps to reproduce
- Include Ruby/Rails versions when relevant
- Include relevant logs or screenshots

## Questions

Open a GitHub issue or discussion in the repository.

Thanks for helping improve ClawDeck.
