Title: chore(flutter): analyzer cleanup phase 1, keep CI fast; restore fatal-warnings later

Goal
- Systematically reduce analyzer warnings to prepare re-enabling `--fatal-warnings` in CI.
- Keep changes mechanical and safe; avoid business logic changes.

Phase 1 Scope (low-risk, high-volume)
- Unused imports and unnecessary imports (dart:async, redundant package imports in tests).
- prefer_const_constructors and prefer_const_literals_to_create_immutables in obvious UI spots.
- Deprecated `withOpacity` → `withValues` where applicable.
- depend_on_referenced_packages in tests: add dev_dependencies or change imports to flutter_riverpod where needed.

Approach
1) Lint categories targeting
   - target rules: unnecessary_import, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use (withOpacity), depend_on_referenced_packages in tests.
2) Batch mechanical edits
   - Apply const constructors/literals in widgets and common dialogs.
   - Replace `color.withOpacity(x)` with `color.withValues(alpha: x)` (Flutter 3.22+ pattern).
   - Remove redundant imports; add missing dev_dependencies for tests.
3) Keep CI non-blocking for analyze
   - Continue recording analyzer output as artifact.
   - After warnings fall below threshold, flip back to `--fatal-warnings` in a follow-up.

Verification
- flutter analyze shows reduced warning count (attach before/after stats in PR summary).
- flutter test passes locally and in CI.

Notes
- Break into small commits by folder (widgets/, screens/, tests/) to ease review.
- Avoid changing behavior; if a change might affect layout, isolate and call out in PR.

Checklist
- [ ] Remove unused/unnecessary imports across lib/ and test/
- [ ] Add const constructors/literals in targeted widgets
- [ ] Replace deprecated withOpacity usages
- [ ] Fix depend_on_referenced_packages in tests (pubspec dev_dependencies)
- [ ] Update CI plan comment and attach analyzer delta

