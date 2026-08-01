# Contributing to CAD Viewer & Editor

## Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Install dependencies: `flutter pub get`
4. Make your changes following the coding conventions in `docs/RULES.md`

## Code Style
- Run `dart format` before committing
- Run `flutter analyze --fatal-infos` — must pass without warnings
- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add doc comments for public APIs
- `models/` must stay pure Dart (no Flutter imports)

## Documentation Requirements
- Every new feature must update: `docs/REQUIREMENTS.md` (if a requirement changes), `docs/CHANGELOG.md`, and relevant skills in `docs/skills/`.
- New architecture decisions go in `docs/ADR.md`.
- Documentation discrepancies go in `docs/CORRECTIONS.md`.

## Testing
- New features must include tests (see `docs/TESTING.md`).
- Run `flutter test` before submitting.
- Keep global coverage ≥ 70% (`flutter test --coverage`).

## Commit Messages
Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `chore:` for maintenance tasks
- `refactor:` for code restructuring
- `test:` for adding tests

## Pull Request Process
1. Ensure `flutter analyze` and `flutter test` pass
2. Update documentation and skills if needed
3. Update CHANGELOG.md if applicable
4. Submit PR with a clear description of changes

## Code Review
All submissions require review. Maintainers will review PRs within a reasonable timeframe. Review checklist includes: undo/redo guarantees for all edit operations, error handling (RULES.md B), and performance budget (PERFORMANCE.md).

## Phases
See `docs/ROADMAP.md` for the versioned roadmap and `docs/TODO.md` for detailed tasks.

## Requirements
See `docs/REQUIREMENTS.md` for functional and non-functional requirements.
