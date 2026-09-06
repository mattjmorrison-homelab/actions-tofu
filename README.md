# actions-tofu

Two reusable composite actions for OpenTofu repos in this org — currently
`admin-openbao` and `admin-github`, whose CI was otherwise two
near-identical copies of the same pipeline. See `naming.md` in the
`.github` repo for the `actions-` prefix: destination is other repos'
CI, not a machine, the cluster, or a system's policy layer.

Named for the tool it wraps (OpenTofu, via the `tofu` CLI), not
`actions-terraform` — same reasoning as `admin-openbao` over `admin-vault`.

Deliberately **not** a reusable workflow (`workflow_call`). An earlier
version was one, but a reusable workflow that needs its own extra files
(the actual `.sh` scripts) has to check its own repo out a second time
inside the job, and there's no reliable way for it to know its own
commit from inside itself (`github.workflow_sha` resolves to the
*caller's* commit, not this repo's — confirmed by a real failure).
Composite actions don't have this problem: GitHub resolves
`github.action_path` automatically whenever one is referenced via
`uses: owner/repo/path@ref`, regardless of what repo is calling it. The
tradeoff is that job orchestration (`on:`, `permissions:`, the
`check`/`apply` job skeleton) isn't centralized — it's duplicated in
each caller's own workflow file — but that skeleton is small and rarely
changes, unlike the actual script logic these two actions share.

## What's here

- **`fetch-credentials/`** — logs into OpenBao via the pod's own
  Kubernetes ServiceAccount identity (role `github-actions-runner`),
  fetches the Garage `tofu-state` bucket credentials, and optionally
  `admin-github`'s org PAT, exporting all of them as env vars for the
  rest of the job.
- **`find-check-run/`** — looks up the successful `check` run matching a
  PR's head SHA, for the `apply` job to download that exact `tfplan`
  artifact from. Superseded by `upload-plan`/`download-plan` below (no
  callers left once every consumer migrates) — not yet removed.
- **`upload-plan/`** and **`download-plan/`** — write/read a `tfplan` file
  directly to/from the shared Garage `tofu-state` bucket, keyed by
  `plans/<owner>/<repo>/<head-sha>/tfplan`, instead of a public GitHub
  Actions artifact. These repos are public, and a plan file's binary form
  embeds the real value of any attribute Terraform already knows from
  state, even `Sensitive`-flagged ones (that flag only redacts CLI
  display, not what's serialized into the plan) — this keeps that data
  private. `apply` builds the same key directly from the merge event's
  own head SHA, so `find-check-run`'s GitHub-API lookup is no longer
  needed at all.

Each is a plain composite action: `action.yml` (inputs/outputs, thin) +
its own `.sh` file, invoked via `${{ github.action_path }}` so the
actual logic isn't embedded in YAML.

## Using them from another repo

Both callers currently share this shape — see `admin-openbao` or
`admin-github`'s own `.github/workflows/tofu.yml` for the real thing:

```yaml
name: OpenTofu

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

jobs:
  check:
    if: github.event.action != 'closed'
    runs-on: k8s-amd64
    steps:
      - uses: actions/checkout@<sha> # v4.2.2
      - uses: opentofu/setup-opentofu@<sha> # v1.0.8
        with:
          tofu_version: "1.12.0"
          tofu_wrapper: false
      - run: tofu fmt -check -recursive
      - uses: terraform-linters/setup-tflint@<sha> # vX
      - run: tflint --init
      - run: tflint
      - uses: mattjmorrison-homelab/actions-tofu/fetch-credentials@<commit-sha>
        with:
          needs-github-token: "true" # only if this caller's own Terraform uses the github provider
      - run: tofu init
      - run: tofu plan -out=tfplan
      - uses: actions/upload-artifact@<sha> # vX
        with:
          name: tfplan
          path: tfplan
          retention-days: 5

  apply:
    if: github.event.action == 'closed' && github.event.pull_request.merged == true
    runs-on: k8s-amd64
    permissions:
      contents: read
      actions: read
    steps:
      - uses: actions/checkout@<sha> # v4.2.2
        with:
          ref: main
      - id: find_run
        uses: mattjmorrison-homelab/actions-tofu/find-check-run@<commit-sha>
        with:
          head-sha: ${{ github.event.pull_request.head.sha }}
          repo: ${{ github.repository }}
      - uses: actions/download-artifact@<sha> # vX
        with:
          name: tfplan
          run-id: ${{ steps.find_run.outputs.run-id }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
      - uses: mattjmorrison-homelab/actions-tofu/fetch-credentials@<commit-sha>
      - uses: opentofu/setup-opentofu@<sha> # v1.0.8
        with:
          tofu_version: "1.12.0"
          tofu_wrapper: false
      - run: tofu init
      - run: tofu apply -auto-approve tfplan
```

If this caller's own Terraform manages OpenBao itself via the `vault`
provider (e.g. `admin-openbao`), also set a top-level
`env: { VAULT_ADDR: ..., VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }} }` on
the workflow — `fetch-credentials` only handles the Garage/GitHub-token
fetch, not the caller's own Vault provider auth.

The caller's own workflow `name:` must stay `OpenTofu` — `find-check-run`
filters `gh api .../actions/runs` by that exact name to find the
matching `check` run.

The top-level `permissions:` block on the `apply` job is required, not
optional — `find-check-run` needs `actions: read` to list runs and
`download-artifact` needs it to fetch the artifact. Omit it and the run
fails with a permissions error.

**Pin every `uses:` reference to these actions to a commit SHA, not a
branch** — this org requires `sha_pinning_required` on every `uses:`
line. Get the current SHA with:

```sh
gh api repos/mattjmorrison-homelab/actions-tofu/commits/main --jq '.sha'
```

Update every caller's pin after any change here that should actually
take effect — an unpinned or stale-pinned caller keeps running whatever
this repo looked like at that commit, not the latest version.

## Permissions needed to call this from another repo

Checked directly against this org's current settings (2026-08-24) — as
things stand today, **nothing extra needs enabling**, since both the org
and every repo checked are on the permissive defaults:

- Org level (`Settings → Actions → General → Policies`, or
  `gh api orgs/mattjmorrison-homelab/actions/permissions`): policy is
  `allowed_actions: all`, `enabled_repositories: all`. If this ever gets
  tightened to "Allow enterprise, and select non-enterprise, actions and
  reusable workflows," this repo's action paths
  (`mattjmorrison-homelab/actions-tofu/fetch-credentials`,
  `.../find-check-run`) would need adding to that allow-list explicitly,
  or every caller breaks.
- Repo level, on each **caller** (`Settings → Actions → General`, or
  `gh api repos/OWNER/REPO/actions/permissions`): same policy, scoped per
  repo. A caller with a more restrictive setting than the org default
  could block calling out to this repo even if the org-wide policy allows
  it.
- On **this** repo (the callee): since it's public, no `Access` setting
  is relevant — that setting (`Settings → Actions → General → Access`)
  only restricts which other repos/orgs may call a *private* repo's
  actions. If this repo is ever made private, that would need setting to
  allow the calling repos (or the whole org).

If a future caller lives outside `mattjmorrison-homelab` entirely, the
org-level policy above is what would need to change — actions across
orgs need the org owning the *called* action to allow it.
