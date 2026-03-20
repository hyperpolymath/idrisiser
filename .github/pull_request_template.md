<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
## Summary

<!-- Briefly describe what this PR does and why. Link to related issues with "Closes #N". -->

## Changes

<!-- List the key changes introduced by this PR. -->

-

## RSR Quality Checklist

<!-- Check all that apply. PRs that fail required checks will not be merged. -->

### Required

- [ ] Tests pass (`just test` or equivalent)
- [ ] Code is formatted (`just fmt` or equivalent)
- [ ] Linter is clean (no new warnings or errors)
- [ ] No banned language patterns (no TypeScript, no npm/bun, no Go/Python)
- [ ] No `unsafe` blocks without `// SAFETY:` comments
- [ ] No banned functions (`believe_me`, `unsafeCoerce`, `Obj.magic`, `Admitted`, `sorry`)
- [ ] SPDX license headers present on all new/modified source files
- [ ] No secrets, credentials, or `.env` files included

### As Applicable

- [ ] `.machine_readable/STATE.a2ml` updated (if project state changed)
- [ ] `.machine_readable/ECOSYSTEM.a2ml` updated (if integrations changed)
- [ ] `.machine_readable/META.a2ml` updated (if architectural decisions changed)
- [ ] Documentation updated for user-facing changes
- [ ] `TOPOLOGY.md` updated (if architecture changed)
- [ ] `CHANGELOG` or release notes updated
- [ ] New dependencies reviewed for license compatibility (PMPL-1.0-or-later / MPL-2.0)
- [ ] ABI/FFI changes validated (`src/interface/abi/` and `src/interface/ffi/` consistent)

## Testing

<!-- Describe how you tested these changes. -->

## Screenshots

<!-- If applicable, add screenshots or terminal output demonstrating the change. -->
