---
name: podman-disk-reclaim
description: Use this skill when Podman eats too much disk on Windows — the Podman machine's ext4.vhdx keeps growing, "podman storage too big", C:/D: drive filling up, too many container images, or the user asks to prune, clean up, shrink, or compact Podman. Prunes unused images (stopped containers and volumes only on request), runs fstrim inside the machine, then compacts the WSL vhdx with diskpart so the space actually returns to Windows. Pruning alone does NOT shrink the vhdx on the host; this skill does both in one command.
---

# Podman Disk Reclaim

A Podman machine on Windows is a WSL2 distro backed by a dynamically growing `ext4.vhdx`. The file grows as images are pulled and never shrinks on its own. `podman system prune` frees space *inside* the VM, but Windows still sees the same huge file. Getting the space back takes four steps: prune, `fstrim`, shut WSL down, then compact the vhdx.

`scripts/reclaim.ps1` runs all four steps.

## Workflow

### 1. Measure first (always)

```powershell
pwsh -File scripts/reclaim.ps1 -DryRun     # or: powershell -File ...
```

This prints the vhdx size on the host, `podman system df`, and the planned steps. It changes nothing. Compare the vhdx size with the **SIZE** column:

- **vhdx much bigger than in-use size:** compaction alone wins most of the space back. Suggest `-SkipPrune` if the user wants to keep every image.
- **RECLAIMABLE high on Images:** a default run (prune unused images, then compact) is the right call.

### 2. Confirm before deleting

Image pruning is destructive. Re-pulling is cheap for public images but not for locally built ones. Before a real run, show the user what will be removed and get a yes. Ask separately before using:

- `-Containers`: removes **stopped** containers along with their writable layers (for example a stopped dev database).
- `-Volumes`: removes volumes no container references. Combined with `-Containers`, this also removes those containers' volumes, which is **data loss**.

### 3. Run elevated

`diskpart` needs Administrator rights. If the current shell is not elevated, hand the user the exact command to run in an Administrator PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File <repo>\skills\podman-disk-reclaim\scripts\reclaim.ps1
```

Warn the user that the script calls `wsl --shutdown`, which **stops every WSL distro** (Ubuntu, Docker Desktop, and others), not only Podman.

### 4. Report

The script ends with `VHDX on host: X GB -> Y GB (freed Z GB)`. Report that line together with the before and after output of `podman system df`.

## Flags

| Flag | Effect |
|---|---|
| `-DryRun` | Show sizes and plan, change nothing |
| `-SkipPrune` | Compact only, delete nothing |
| `-SkipCompact` | Prune only, no admin needed, host file stays the same size |
| `-Containers` | Also prune stopped containers |
| `-Volumes` | Also prune unused volumes |
| `-Machine <name>` | Target a machine other than `podman-machine-default` |

## Notes

- **Do not** recreate the machine with a smaller `--disk-size` to save space. The WSL disk size is a cap, not allocated space. Compaction is what shrinks the file.
- Only Windows with the WSL backend is supported. On macOS or Linux, run `podman system prune -a`, because those VM disks are sparse already.
- `Optimize-VHD` is missing on Windows Home (no Hyper-V module), so the script uses `diskpart`, which is available on every edition.
