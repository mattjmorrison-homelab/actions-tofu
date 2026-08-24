# actions-tofu

A reusable GitHub Actions workflow (`workflow_call`) for OpenTofu repos in
this org — currently `admin-openbao` and `admin-github`, whose CI was
otherwise two near-identical copies of the same pipeline. See `naming.md`
in the `.github` repo for the `actions-` prefix: destination is other
repos' CI, not a machine, the cluster, or a system's policy layer.

Named for the tool it wraps (OpenTofu, via the `tofu` CLI), not
`actions-terraform` — same reasoning as `admin-openbao` over `admin-vault`.

## What it does

Two jobs, gated on PR lifecycle so a plan is only ever generated once and
the exact same plan file is what gets applied — see the plan/apply
artifact pattern this implements:

- **`check`** — runs on `opened`/`synchronize`/`reopened`. `tofu fmt
  -check`, `tflint`, then `tofu plan -out=tfplan`, uploaded as a workflow
  artifact.
- **`apply`** — runs only when the PR is `closed` *and* merged. Looks up
  the specific `check` run that matches the PR's final head SHA, downloads
  that exact `tfplan` artifact, and applies it directly
  (`tofu apply tfplan`) — never re-planning.

Both jobs authenticate to OpenBao using the calling repo's own pod
identity (Kubernetes-auth login, role `github-actions-runner`), fetching
the Garage `tofu-state` bucket credentials every run. No caller-specific
parameterization needed there — every caller currently shares the same
state bucket and Vault role.

## Layout

The actual scripting lives in `scripts/*.sh`, not inline in the workflow
YAML — the workflow file stays close to pure job/step configuration.
Since the caller's own checkout doesn't include this repo, each job
checks this repo out too, into `.actions-tofu/`, before invoking a
script from it. That second checkout pins `ref: ${{ github.workflow_sha
}}` — GitHub resolves that at runtime to whichever commit of *this* repo
is actually executing, so it always matches the exact version the caller
pinned via its own `uses:` line, with nothing hardcoded here that would
need updating on every change.

## Inputs

| Input | Type | Default | When to set it |
| --- | --- | --- | --- |
| `needs-github-token` | boolean | `false` | Caller's own Terraform uses the `github` provider (e.g. `admin-github`) — fetches `admin-github`'s org PAT from OpenBao and exports it as `GITHUB_TOKEN`. |
| `needs-vault-root-token` | boolean | `false` | Caller's own Terraform manages OpenBao itself via the `vault` provider (e.g. `admin-openbao`) — exposes the caller's `VAULT_TOKEN` secret to the job. Requires the caller to pass `secrets: inherit`. |
| `tofu-version` | string | `"1.12.0"` | Override if a caller needs a different OpenTofu version. |

## Calling it from another repo

```yaml
name: OpenTofu

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

jobs:
  tofu:
    uses: mattjmorrison-homelab/actions-tofu/.github/workflows/tofu.yml@<commit-sha>
    with:
      needs-vault-root-token: true # only if this caller's own Terraform manages Vault
      needs-github-token: true     # only if this caller's own Terraform uses the github provider
    secrets: inherit
```

The caller's own workflow `name:` must stay `OpenTofu` — the `apply`
job's artifact lookup filters `gh api .../actions/runs` by that exact
name to find the matching `check` run.

**Pin to a commit SHA, not a branch** — this org requires
`sha_pinning_required` on every `uses:` reference, including cross-repo
calls to this one. Get the current SHA with:

```sh
gh api repos/mattjmorrison-homelab/actions-tofu/commits/main --jq '.sha'
```

Update every caller's pin after any change here that should actually take
effect — an unpinned or stale-pinned caller keeps running whatever this
file looked like at that commit, not the latest version.

## Permissions needed to call this from another repo

Checked directly against this org's current settings (2026-08-24) — as
things stand today, **nothing extra needs enabling**, since both the org
and every repo checked are on the permissive defaults:

- Org level (`Settings → Actions → General → Policies`, or
  `gh api orgs/mattjmorrison-homelab/actions/permissions`): policy is
  `allowed_actions: all`, `enabled_repositories: all`. If this ever gets
  tightened to "Allow enterprise, and select non-enterprise, actions and
  reusable workflows," this repo's workflow path
  (`mattjmorrison-homelab/actions-tofu/.github/workflows/tofu.yml`) would
  need adding to that allow-list explicitly, or every caller breaks.
- Repo level, on each **caller** (`Settings → Actions → General`, or
  `gh api repos/OWNER/REPO/actions/permissions`): same policy, scoped per
  repo. A caller with a more restrictive setting than the org default
  could block calling out to this repo even if the org-wide policy allows
  it.
- On **this** repo (the callee): since it's public, no `Access` setting
  is relevant — that setting (`Settings → Actions → General → Access`)
  only restricts which other repos/orgs may call a *private* repo's
  reusable workflows. If this repo is ever made private, that would need
  setting to allow the calling repos (or the whole org).

If a future caller lives outside `mattjmorrison-homelab` entirely, the
org-level policy above is what would need to change — reusable workflows
across orgs need the org owning the *called* workflow to allow it.
