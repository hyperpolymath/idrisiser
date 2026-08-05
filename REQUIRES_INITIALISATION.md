<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# REQUIRES INITIALISATION

**This repository is not finished being set up.** 32 substitution token(s) across 21 file(s) still have no value.

## Why this is not already done

This repo was created from `hyperpolymath/rsr-template-repo`. The mint
(`just repo-init`) fills every token that has a single mechanical answer —
owner, repo, author, dates, licence, branch — and it has done so here.

The tokens below are the ones it *deliberately cannot* answer. They need a
decision or a fact that exists only in your head: what this project is for,
what command builds it, which port the service listens on, whether a PGP key
is held at all. The template's own token vocabulary says as much — you cannot
sensibly answer "required invariants" in a thirty-second bootstrap.

They were left **visibly unfilled on purpose**. The alternatives were both
worse: inventing plausible values would put confident falsehoods into a
security policy and an architecture document, and silently deleting the
sections would hide the fact that a decision is owed. A visible gap is
honest; a fabricated answer is not.

## Do not delete this file until every item below is resolved

This file is the only marker that the work is outstanding. Deleting it early
does not finish the setup, it just conceals it — and the next person or agent
to arrive will reasonably assume the repo is complete.

- **If you are a person:** delete this file yourself once the last item is done.
- **If you are an agent:** resolve what you legitimately can, leave the rest,
  and delete this file only when no token below remains anywhere in the tree.
  Do not delete it to make a gate go green.

Re-running the estate top-up tool will remove this file automatically once
nothing is outstanding, so the safest way to finish is to fix the tokens and
let the check confirm it.

## What is needed, and where it goes

### `{{ARGS}}`

Arguments for the justfile recipe this appears in.

Appears in:

- `Justfile`

### `{{AUTHOR_EMAIL_ALT}}`

Appears in:

- `.github/.mailmap`

### `{{AUTHOR_ORG}}`

Author's organisation. NOTE: no filled instance of this exists anywhere in the estate — consider deleting the field instead.

Appears in:

- `.machine_readable/contractiles/k9/examples/project-metadata.k9.ncl`

### `{{BUILD_CMD}}`

The exact command that builds this project.

Appears in:

- `QUICKSTART-DEV.adoc`

### `{{BUILD_OUTPUT_PATH}}`

Where the build artefact lands.

Appears in:

- `QUICKSTART-MAINTAINER.adoc`

### `{{CONDUCT_TEAM}}`

Name of the conduct body. If there is no committee, rewrite the sentence rather than substituting a plural noun into 'a {{CONDUCT_TEAM}} member'.

Appears in:

- `.github/CODE_OF_CONDUCT.md`

### `{{CONSUMER1}}`

A downstream repo that consumes this one.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{CONSUMER2}}`

A second downstream consumer.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{DEP1}}`

First named dependency, in .machine_readable/INTENT.contractile.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{DEP2}}`

Second named dependency, in .machine_readable/INTENT.contractile.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{DEPS}}`

Prose summary of runtime/build dependencies.

Appears in:

- `QUICKSTART-MAINTAINER.adoc`

### `{{LANG_STACK}}`

The language stack, in prose.

Appears in:

- `QUICKSTART-DEV.adoc`

### `{{LICENSE}}`

SPDX identifier for this repo's licence.

Appears in:

- `container/Containerfile`
- `container/manifest.toml`
- `docs/developer/ABI-FFI-README.adoc`

### `{{MONOREPO_OR_STANDALONE}}`

Literally 'monorepo' or 'standalone'.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{MUST_INVARIANTS}}`

The invariants this project guarantees. Not answerable in a bootstrap; it is the point of the repo.

Appears in:

- `QUICKSTART-DEV.adoc`

### `{{ONE_PARAGRAPH_ANTI_PURPOSE}}`

A paragraph on what this deliberately is NOT for.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{ONE_PARAGRAPH_PURPOSE}}`

A paragraph on what this is for.

Appears in:

- `.machine_readable/INTENT.contractile`

### `{{PGP_FINGERPRINT}}`

Full fingerprint of the security-contact PGP key. NOTE: no key is published anywhere in this estate — if none is held, delete the PGP block rather than inventing one.

Appears in:

- `.github/SECURITY.md`

### `{{PGP_KEY_URL}}`

Public URL the PGP key can be fetched from. Same caveat as PGP_FINGERPRINT.

Appears in:

- `.github/SECURITY.md`
- `.well-known/security.txt`

### `{{PORT}}`

Port the container service listens on.

Appears in:

- `container/Containerfile`
- `container/compose.toml`
- `container/deploy.k9.ncl`
- `container/entrypoint.sh`
- `container/manifest.toml`
- `container/vordr.toml`

### `{{PROJECT_DESCRIPTION}}`

One-line description, matching the forge description.

Appears in:

- `container/Containerfile`
- `container/manifest.toml`

### `{{PROJECT_DOMAIN}}`

Taxonomy value for the subject domain.

Appears in:

- `.machine_readable/anchors/ANCHOR.a2ml`

### `{{PROJECT_KIND}}`

Taxonomy value (library, service, tool, lab…).

Appears in:

- `.machine_readable/anchors/ANCHOR.a2ml`

### `{{PROJECT_PURPOSE}}`

One line: what this exists to do.

Appears in:

- `.machine_readable/anchors/ANCHOR.a2ml`
- `guix.scm`

### `{{PROJECT_UNIQUE_STRENGTH}}`

What this does that its alternatives do not.

Appears in:

- `.machine_readable/agent_instructions/methodology.a2ml`

### `{{REGISTRY}}`

Container registry to publish to.

Appears in:

- `container/compose.toml`
- `container/ct-build.sh`
- `container/deploy.k9.ncl`

### `{{RESPONSE_TIME}}`

Initial-response SLA for a security or conduct report. Promise only what a solo maintainer can actually meet.

Appears in:

- `.github/CODE_OF_CONDUCT.md`

### `{{SECURITY_EMAIL}}`

Address for private vulnerability reports. Two competing values exist in the estate (`6759885+hyperpolymath@users.noreply.github.com` and `security@hyperpolymath.org`) — pick one deliberately.

Appears in:

- `.github/SECURITY.md`
- `.well-known/security.txt`

### `{{SERVICE_NAME}}`

Container service name.

Appears in:

- `container/.gatekeeper.yaml`
- `container/Containerfile`
- `container/compose.toml`
- `container/ct-build.sh`
- `container/deploy.k9.ncl`
- `container/entrypoint.sh`
- `container/manifest.toml`
- `container/vordr.toml`

### `{{TEST_CMD}}`

The exact command that runs its tests.

Appears in:

- `QUICKSTART-DEV.adoc`

### `{{VERSION}}`

Version/tag for the container image.

Appears in:

- `container/deploy.k9.ncl`
- `container/manifest.toml`
- `container/vordr.toml`

### `{{WEBSITE}}`

Project homepage URL, or delete the field if there is none.

Appears in:

- `.github/SECURITY.md`
- `.well-known/security.txt`

---

Generated by the estate top-up pass. Rationale and the governing rulings are
in `hyperpolymath/standards`; the token vocabulary is
`.machine_readable/ai/PLACEHOLDERS.adoc` in `rsr-template-repo`.
