---
name: poc-spec-driven-builder
description: Use this skill whenever the user wants Claude Code to build a proof of concept (PoC), prototype, or "prove this idea works" — even if they just describe an idea informally and don't say "PoC" or "skill." Also trigger for "build this from scratch," "design then build," or any request to validate technical feasibility before full development. This skill runs the whole pipeline autonomously and without pausing to ask the user clarifying questions — (1) research best practices for the idea's domain/stack, (2) write a lightweight SRS (requirements spec), (3) derive a full test-case matrix that covers every SRS requirement BEFORE any implementation code is written, (4) build to make the tests pass, (5) report results, open questions, and what a full build would still need. Use this instead of jumping straight into code whenever the user's request implies "is this feasible" / "prove this works" / "make sure it's grounded in best practice" rather than "just write me code."
---

# PoC Spec-Driven Builder

Turns a loosely-described idea into a working, evidence-backed proof of concept — research → spec (SRS) → test matrix → implementation → verification — run end-to-end without interrupting the user for clarification. Ambiguity is resolved by making the most reasonable assumption and logging it, not by asking.

This mirrors how modern AI coding agents are meant to work: specs and tests are the source of truth the agent builds *to*, not decisions made ad hoc while writing code. A PoC only proves something if what it's proving was written down first.

## Core principle: never block on questions

Default behavior for this skill is autonomous execution. When something is unspecified:
1. Pick the most conventional, lowest-risk, industry-standard choice for that domain.
2. Write it into the SRS's **Assumptions** section with a one-line rationale.
3. Keep going.

Only break this rule if the user's message contains an explicit, irreversible constraint that's actually contradictory (e.g., they named two mutually exclusive databases) — then state the conflict plainly and pick one anyway, noting it's an assumption to revisit, rather than stopping.

## Workflow

### Step 0 — Scope the idea (silent, no output yet)
Read the user's request and restate it internally as: what capability is being proven, for whom, and what's explicitly out of scope. A PoC proves ONE core technical uncertainty — not a full product. If the request bundles several unproven ideas, identify the riskiest/most load-bearing one as the PoC's focus and note the others as "not in scope for this PoC" in the SRS.

### Step 1 — Research best practices
Before designing anything, research the domain the idea lives in:
- Search for established patterns, common pitfalls, and reference architectures for this category of problem (e.g., "real-time collaboration conflict resolution," "OAuth device-code flow," "vector search reranking").
- Identify the standard/boring technology choices for this stack unless the user specified otherwise — PoCs should use mature, well-documented tools, not novel ones, because the goal is to isolate risk in the *idea*, not in unfamiliar tooling.
- Note any known failure modes or gotchas specific to this kind of system; these become edge-case test cases in Step 3.

Keep this research proportional — a few searches for a small PoC, more for something with real architectural uncertainty. Summarize findings in 3-6 bullet points; this becomes the "Background / Prior Art" section of the SRS.

### Step 2 — Write the SRS (before any code)
Produce a lightweight Software Requirements Specification as a markdown file (`SRS.md`) in the project. Keep it tight — a PoC spec is a page or two, not an enterprise document. Required sections:

```markdown
# SRS: <project name>

## 1. Purpose
One paragraph: what technical question this PoC answers, and why it's uncertain enough to need proving.

## 2. Scope
- In scope: the specific capability being demonstrated
- Out of scope: everything adjacent that this PoC deliberately does not attempt

## 3. Background / Prior Art
Bullet points from Step 1's research — patterns used, tools chosen, why.

## 4. Functional Requirements
Numbered, testable, one behavior each:
- FR-1: <system> shall <specific behavior> when <condition>
- FR-2: ...
Every requirement must be phrased so a test can pass or fail against it. Reject vague ones ("shall be user-friendly") — rewrite until measurable.

## 5. Non-Functional Requirements
Only the ones that matter for THIS PoC's core question (performance, data volume, latency, concurrency, security boundary). Skip categories that aren't relevant — don't pad.

## 6. Assumptions
Every unspecified decision made autonomously, with a one-line rationale. This is the log of everything that wasn't asked about.

## 7. Success Criteria
The concrete, binary condition(s) under which this PoC is considered to have proven (or disproven) the idea.
```

Fundamentals to hold to while writing this, regardless of domain:
- Every requirement is falsifiable — if you can't imagine a test failing it, rewrite it.
- Prefer fewer, sharper requirements over broad coverage — a PoC that nails the risky 20% beats one that shallowly covers 100%.
- State success criteria before any design decisions that could bias what "success" means later.

### Step 3 — Derive the full test matrix from the SRS (still before implementation)
For **every** FR and relevant NFR, write at least one test case before writing implementation code. Produce `TEST_PLAN.md` (or actual test files if the stack/framework is already clear — prefer real executable tests over a prose plan when feasible):

```markdown
## Test Matrix

| Test ID | Requirement | Scenario | Type | Expected Result |
|---------|-------------|----------|------|------------------|
| T-1     | FR-1        | Happy path: ... | unit/integration | ... |
| T-2     | FR-1        | Edge case: ... | unit | ... |
| T-3     | FR-2        | ... | ... | ... |
```

Coverage rules:
- Every FR gets at least a happy-path test AND at least one edge/failure-path test (empty input, boundary value, invalid state, concurrent access — whichever apply).
- Pull edge cases from Step 1's "known failure modes" research, not just from imagination.
- Every NFR that's testable gets a test (e.g., a latency budget gets a timed test, not just a comment).
- Requirements with no corresponding test are a spec bug — go back and add the test, don't skip it.
- If the stack supports it, write these as actual runnable test files (pytest/jest/etc.) in a `tests/` directory so Step 4 has something to run against, not just prose to eyeball.

### Step 4 — Build to the tests
Implement the minimum code that satisfies the test matrix, in requirement order (build what T-1's requirement needs, confirm it passes, move to the next). Do not add functionality that isn't backed by an FR/NFR in the SRS — scope creep in a PoC defeats the point of isolating one risky question. If mid-build you discover the spec was wrong or incomplete, update `SRS.md` and `TEST_PLAN.md` first, then continue — the spec stays the source of truth, not an artifact you drift away from.

Run the test suite (or walk through the test matrix manually if no test framework applies to this stack) before declaring anything done.

### Step 5 — Report
Close out with:
- Pass/fail status against every requirement in the SRS (a simple table is fine).
- Whether the PoC's Success Criteria (SRS §7) were met — answer the actual technical question, don't just say "done."
- The Assumptions log (SRS §6) surfaced explicitly, since these are exactly the decisions a real build would need a human to confirm or override.
- What's deliberately NOT proven (out-of-scope items) and what a next iteration or full build would need to address.

## Fundamentals checklist (apply throughout, not just at the end)

- **One core uncertainty per PoC.** If you're proving three unrelated things, you have three PoCs — say so and either scope down or run them as separate phases.
- **Boring technology by default.** Novelty is a variable to control for, not to introduce, unless the novel tool IS the thing being proven.
- **Spec before code, tests before implementation.** Never write implementation logic before the corresponding requirement and test exist on paper.
- **Assumptions are logged, not silent.** A reader of the SRS should be able to find every place Claude guessed instead of being told.
- **Small and disposable.** PoC code optimizes for answering the question fast and clearly, not for production hardening, unless an NFR explicitly says otherwise.
- **Falsifiable success.** If there's no way the PoC could have failed, it didn't prove anything.
