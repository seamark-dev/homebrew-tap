# Seamark Homebrew Tap

Homebrew formulae for [Seamark](https://github.com/seamark-dev/seamark) —
local code intelligence, repository memory, and guardrails for coding
agents.

## Install

```bash
brew install seamark-dev/tap/seamark
```

Then, in any repository:

```bash
cd your-project
seamark init
seamark index
seamark orient
```

The formula installs the `seamark` binary plus bash/zsh/fish shell
completions. History mining shells out to `git`, which every Homebrew
install already guarantees (`seamark doctor` verifies it).

### Platforms

Pre-built bottles are published for:

| Platform                    | Bottle                                |
| --------------------------- | ------------------------------------- |
| macOS arm64 (Apple Silicon) | yes                                   |
| macOS x86_64 (Intel)        | yes                                   |
| Linux x86_64                | yes                                   |
| Linux arm64                 | no — builds from source automatically |

Where no bottle exists, Homebrew builds from source. That needs Go ≥ 1.25
and a C compiler (the tree-sitter bindings use CGO); Homebrew installs Go
as a build-time dependency on its own.

## Releasing a new version (maintainers)

Bottles are built by CI from a pull request and published only when a
collaborator applies the `pr-pull` label. Nothing is ever published
automatically.

1. **Release seamark first.** In `seamark-dev/seamark`, follow the normal
   ritual: land the CHANGELOG + `docs/STATUS.md` PR, push the `vX.Y.Z`
   tag, wait for the release workflow, and publish the draft GitHub
   release.

2. **Open the bump PR in this repo.** From any machine with Homebrew and
   this tap installed:

   ```bash
   brew bump-formula-pr seamark-dev/tap/seamark --no-fork \
     --url https://github.com/seamark-dev/seamark/archive/refs/tags/vX.Y.Z.tar.gz
   ```

   This downloads the tarball, computes the `sha256`, and opens a PR.
   `--no-fork` pushes the branch to this repository itself, which the
   publish workflow needs in order to clean up the branch afterwards.

   Manual fallback: edit `url` and `sha256` in `Formula/seamark.rb` by
   hand (`shasum -a 256` on the downloaded tarball) and open a PR.

3. **Wait for CI.** The `brew test-bot` workflow builds the formula on
   all three bottled platforms, runs `brew audit`, runs the full
   `test do` journey (init → index → why → doctor in a fresh git
   fixture), and uploads the bottle archives as workflow artifacts. All
   three jobs must be green.

4. **Apply the `pr-pull` label.** The publish workflow then downloads
   the bottle artifacts, uploads them to a GitHub release on this repo
   (`seamark-X.Y.Z`), rewrites the PR commit with the `bottle do` block,
   pushes it to `main`, and deletes the branch. **Do not merge the PR by
   hand** — merging skips bottle publication.

5. **Verify.**

   ```bash
   brew update
   brew install seamark-dev/tap/seamark
   ```

   The install log must say `Pouring seamark--X.Y.Z...` (a bottle), not
   `Building from source`. `seamark version` must print the new tag.

## How this tap works

- `Formula/seamark.rb` builds seamark from the tagged source tarball
  (`go build` with the release version stamped via ldflags) and installs
  shell completions from the binary itself.
- `.github/workflows/tests.yml` (`brew test-bot`) audits, builds, and
  tests every PR on each bottled platform and uploads bottle artifacts.
- `.github/workflows/publish.yml` (`brew pr-pull`) publishes those
  artifacts when the `pr-pull` label is applied.

The formula's `test do` block intentionally goes beyond `seamark
version`: it creates a temporary git repository, then runs `seamark
init`, `seamark index`, `seamark why helper`, and `seamark doctor`.
Homebrew therefore cannot publish a bottle that runs but cannot index a
real repository.

## License

The formulae in this tap are published under the same
[Apache-2.0](https://github.com/seamark-dev/seamark/blob/main/LICENSE)
license as Seamark itself.
