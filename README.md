# th3-skills

Skills for Claude Code, installable via [`npx skills`](https://dev.to/baltz/sharing-skills-with-npx-2nbc).

## Install a skill

```
npx skills@latest add TheeraphatStudent/th3-skills --skill poc-spec-driven-builder
```

## Skills

- [`poc-spec-driven-builder`](skills/poc-spec-driven-builder/SKILL.md) — builds a proof of concept end-to-end: research → SRS → test matrix → implementation → verification, run autonomously without pausing for clarification.
- [`thai-mock-naming`](skills/thai-mock-naming/README.md) — Thai mock names that are unmistakably fake, greppable in a database, and still exercise real Thai text handling. Replaces สมชาย ใจดี / สมหญิง พอใจ with marker names like ทดสอบ นามสมมุติ. Ships a generator and a linter.
- [`doc-style-builder`](skills/doc-style-builder/SKILL.md) — documents any work product (API, deploy, system, release) in one house style: seven document skeletons, a TH Sarabun theme with change highlighting, and Markdown → PDF + DOCX in one command.

- [`podman-disk-reclaim`](skills/podman-disk-reclaim/SKILL.md) — shrinks a bloated Podman machine on Windows: prunes unused images, runs `fstrim`, and compacts the WSL `ext4.vhdx` with diskpart so the space actually returns to the host. One script, `-DryRun` first.

## Related

- [kien-thai (เขียนไทย)](https://github.com/chakrit/kien-thai) by chakrit — a skill for writing Thai that Thai readers find easy to read. Pairs with `thai-mock-naming`: that skill handles the Thai prose in free-text fields, this one handles the identity fields.

## License

MIT — see [LICENSE](LICENSE).
