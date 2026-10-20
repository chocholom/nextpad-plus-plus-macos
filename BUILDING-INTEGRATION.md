# Rebuild and maintain Mirek's macOS integration

Repository: <https://github.com/chocholom/nextpad-plus-plus-macos>.
Maintained branch: `integration/macos-parity-20261020`.
Upstream: <https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos>.

## Frozen installed version

Tag **`mirek-integration-2026.10.20.1`** identifies source commit
`a25e53bfb051f1f22dc9662059c8818309ad7154`, matching the installed app's
`NextpadIntegrationSourceCommit`. Its build number is `2026.10.20.1`.
The tag includes the correction for empty windows when opening files.

The [GitHub release](https://github.com/chocholom/nextpad-plus-plus-macos/releases/tag/mirek-integration-2026.10.20.1)
provides the universal app ZIP, an offline Git source bundle, build metadata and
the feature/validation report. The source bundle contains complete history.
The maintained branch also includes this guide and the recorded
[build environment](docs/build-environment-2026-10-20.json).

## Clone and configure remotes

```sh
git clone --origin fork --branch integration/macos-parity-20261020 \
  https://github.com/chocholom/nextpad-plus-plus-macos.git nextpad-macos
cd nextpad-macos
git remote add upstream https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos.git
git config remote.pushDefault fork
```

Here `fork` is your repository and `upstream` is the original project. A clone
normally calls its remote `origin`; `--origin fork` makes these instructions
unambiguous. Both remotes are read over HTTPS; pushing requires your GitHub
credentials. GitHub CLI authentication is one option: `gh auth login` followed by
`gh auth setup-git`.

To rebuild the exact installed source, use a separate checkout:

```sh
git worktree add --detach ../nextpad-installed mirek-integration-2026.10.20.1
cd ../nextpad-installed
```

To work on the maintained version, stay on `integration/macos-parity-20261020`.
New documentation commits on that branch do not change the frozen tag.

## Build and validate

Requirements: macOS, Xcode or its command-line developer tools, CMake 3.20+,
Ninja and Python 3. The dependencies Scintilla, Lexilla, Boost.Regex, language
resources and API dictionaries are tracked in this repository. No sibling
Notepad++ checkout, Wine, Git LFS download or external runtime library is needed.

For a Mac already using Homebrew, CMake and Ninja can be installed with
`brew install cmake ninja`. Check that `xcrun clang++ --version` succeeds before
building. The [environment record](docs/build-environment-2026-10-20.json) lists
the versions used for the installed build.

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DNPP_BUILD_TESTS=ON
cmake --build build -j 6
cmake --build build --target npp_tests -j 6
ctest --test-dir build --output-on-failure
python3 tests/run_native.py
python3 tests/run_file_open.py
```

The CMake configuration builds both **arm64 and x86_64**. The two GUI regression
runners at the frozen tag run on **Apple Silicon** and require a logged-in macOS
desktop session. They use private settings and bundle IDs. Headless search tests
do not require a GUI. Validation of the installed source passed 87 native checks,
all six search suites, and real cold/warm file-open checks that inspect Scintilla
buffer hashes. Intel was compiled but not runtime-tested.

Optionally check an existing UTF-8 file without changing it:

```sh
python3 tests/run_file_open.py /absolute/path/to/example.csv
```

This checks the file through an isolated test app and records its hash, not its
text. Production app launch is exercised through its real `main`, AppDelegate and
macOS file-open events. A successful process launch alone is insufficient.

## Package

Commit source changes before packaging so the embedded commit identifies the
source used. Choose an output directory that does not already contain a package:

```sh
python3 tools/package-integration.py \
  --output ../nextpad-release-2026.10.20.1 \
  --build-number 2026.10.20.1
```

This produces `Nextpad++ Integration.app`, a ZIP and `artifact.json`. It checks
both architectures, ad-hoc signs the app and records its source commit and ZIP
SHA-256. Source rebuilds with different SDKs or toolchains may produce different
binary hashes. The frozen release's original archive has SHA-256:

```text
bc7115c5ea0080c6c0f792bb5ed01ac750874eb25b581a396ebc7de1cf7e2b95
```

Quit the existing app normally before copying the rebuilt `.app` into
`/Applications`. Keep the bundle ID `org.nextpadplusplus.mac.integration` and
settings profile `Nextpad++ Integration` to use the same configuration and file
associations. The package uses those identities automatically. Homebrew's app
is a separate upstream build.

## Update against upstream

Keep each validated tag. Perform an upstream update on a new branch:

```sh
git switch integration/macos-parity-20261020
git status --short
git fetch fork --tags
git merge --ff-only fork/integration/macos-parity-20261020
git fetch upstream --tags
python3 tools/compare-upstream.py --ref upstream/main --patches
git switch -c integration/upstream-20261101
git merge --no-ff upstream/main
```

Start with a clean working tree. Choose a new date/branch name for each update.
For a release-only update, use the fetched upstream release tag in place of
`upstream/main` in both the comparison and merge commands.

Resolve conflicts by preserving the behavior described in
[the report](docs/macos-integration-2026-10-20.md) and
[the manifest](docs/integration-manifest.json), then stage the resolved files and
finish the merge with `git commit`. The included PRs overlap in several files;
selecting one whole side can discard required implementations. In particular,
keep `FindWindow.existingWindow` together with its window-focus caller.
`git merge --abort` abandons an unresolved merge and returns to its starting point.

Run the full build, headless tests and both GUI runners above. Adapt tests if
upstream intentionally changes internal APIs, and review the report's manual QA
items. Commit ancestry and patch IDs are evidence of inclusion; they do not
establish that a feature still behaves correctly. If GitHub CLI is available,
`--github` adds current PR merge status to the comparison.

Once validated, push the update branch for review:

```sh
git push -u fork integration/upstream-20261101
```

To adopt the validated update on the maintained branch:

```sh
git switch integration/macos-parity-20261020
git merge --ff-only integration/upstream-20261101
git push fork integration/macos-parity-20261020
git tag -a mirek-integration-2026.11.01.1 -m 'Validated upstream integration'
git push fork mirek-integration-2026.11.01.1
```

Use that same new version as `--build-number` when packaging. Update the feature
report, manifest and validation record as part of each release. Upstream's own
in-app updater downloads upstream builds; use this fork's packages to retain
changes that have not yet landed upstream.

## Recover without a network connection

With the release's source bundle saved locally:

```sh
git clone --branch integration/macos-parity-20261020 \
  Nextpad++-Integration-source.bundle nextpad-offline
cd nextpad-offline
```

This bundle is frozen at the installed source commit. Add the `fork` and
`upstream` remotes above once network access is available, then fetch their
branches and tags to continue development.
