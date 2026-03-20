<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

# Project Governance

This document describes the governance model for **{{PROJECT_NAME}}**.

---

## Project Governance Model

{{PROJECT_NAME}} follows a **Benevolent Dictator For Life (BDFL)** governance model.
This model is well-suited for solo maintainers and small project teams where rapid,
consistent decision-making is more valuable than formal consensus processes.

The BDFL has final authority on all project decisions, including technical direction,
release schedules, contributor access, and community standards.

> **Transition clause:** When the core team exceeds three active maintainers, this
> project should transition to a **consensus-based governance model** with documented
> voting procedures. That transition should itself be recorded as an Architecture
> Decision Record (ADR) in `docs/decisions/`.

---

## Decision Making

### Day-to-day decisions

- The BDFL makes final decisions on all matters.
- Routine decisions (bug fixes, dependency updates, minor improvements) may be made
  by any maintainer with commit access.
- Maintainers are expected to use good judgement and seek input on non-trivial changes.

### Proposing changes

- Contributors can propose changes by opening issues or pull requests.
- Significant changes (new features, breaking changes, architectural shifts) should
  be discussed in an issue before implementation begins.
- The BDFL will provide a clear accept/reject decision with reasoning.

### Architecture Decision Records (ADRs)

- Significant technical decisions are documented as ADRs in `docs/decisions/`.
- ADR statuses: `proposed`, `accepted`, `deprecated`, `superseded`, `rejected`.
- ADRs provide a historical record of why decisions were made and what alternatives
  were considered.
- See `.machine_readable/META.a2ml` for the machine-readable ADR index.

---

## Roles

### BDFL (Benevolent Dictator For Life)

- The project creator and ultimate decision-maker.
- Sets the project's technical direction and long-term vision.
- Has final say on all matters, including maintainer appointments and removals.
- Responsible for ensuring the project adheres to RSR standards.

### Maintainer

- Has commit access to the repository.
- Reviews and merges pull requests.
- Triages issues and manages releases.
- Upholds code quality, security standards, and the Code of Conduct.
- Listed in [MAINTAINERS.md](MAINTAINERS.md).

### Contributor

- Anyone who submits pull requests, opens issues, or participates in discussions.
- Does not have direct commit access.
- Contributions are reviewed by maintainers before merging.
- All contributors must follow the [Code of Conduct](CODE_OF_CONDUCT.md).

### Bot

- Automated agents managed via your bot orchestration system.
- Perform automated code review, security scanning, dependency updates, and
  standards enforcement.
- Bot actions are subject to the same quality and review standards as human
  contributions.
- Configure your bots in `.machine_readable/bot_directives/`.

---

## Becoming a Maintainer

A contributor may be nominated to become a maintainer when they demonstrate:

1. **Sustained quality contributions** -- a track record of well-crafted pull requests
   that follow project conventions and require minimal revision.
2. **Understanding of RSR standards** -- familiarity with the Repository Structure
   Requirements, security policies, and CI/CD workflows used across the project.
3. **Constructive participation** -- helpful issue triage, thoughtful code review
   comments, and mentoring of other contributors.
4. **Reliability** -- consistent engagement over a meaningful period (typically 3+
   months of active contribution).

### Process

1. An existing maintainer nominates the candidate by opening a private discussion
   with the BDFL.
2. The BDFL reviews the candidate's contribution history and community interactions.
3. The BDFL approves or declines the nomination, with reasoning provided to the
   nominator.
4. If approved, the new maintainer is added to [MAINTAINERS.md](MAINTAINERS.md) and
   granted appropriate repository access.

---

## Removing a Maintainer

A maintainer may be removed under the following circumstances:

- **Inactivity**: No meaningful contributions or reviews for 12 or more consecutive
  months. The maintainer will be contacted before removal and offered the option to
  move to emeritus status voluntarily.
- **Code of Conduct violation**: Behaviour that violates the
  [Code of Conduct](CODE_OF_CONDUCT.md), as determined through the enforcement
  process described therein.
- **BDFL discretion**: The BDFL may remove a maintainer for other reasons (e.g.,
  repeated disregard for project standards, loss of trust). Reasoning will be
  documented privately.

Removed maintainers are moved to the Emeritus section of
[MAINTAINERS.md](MAINTAINERS.md) unless removal was due to a serious Code of Conduct
violation.

---

## Code of Conduct

All participants in this project are expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md). The Code of Conduct applies to all project
spaces, including issues, pull requests, discussions, and any forum where the project
is represented.

Enforcement of the Code of Conduct is described in that document. The BDFL serves as
the final arbiter in conduct disputes.

---

## Amendments

This governance document may be amended by the BDFL at any time. All amendments will
be:

1. Documented as an ADR in `docs/decisions/` explaining the rationale for the change.
2. Committed to the repository with a clear commit message.
3. Communicated to existing maintainers and contributors via the project's usual
   channels.

Substantive changes (e.g., changing the governance model itself) should be discussed
with the community before adoption, even though the BDFL retains final authority.

---

<sub>Copyright (c) {{CURRENT_YEAR}} {{OWNER}}. Licensed under PMPL-1.0-or-later.</sub>
