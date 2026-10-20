# Nextpad++ macOS integration — 2026-10-20

The build combines 22 reviewed upstream PRs with 11 new focused PRs. It remains a native AppKit/Objective-C++ application using Scintilla and Lexilla. The work extends Nextpad instead of replacing its working native editor shell or porting the Windows UI.

## Build and source

- Package: `Nextpad++-Integration-universal.zip`, containing **Nextpad++ Integration.app**.
- Architectures: **arm64 and x86_64**. Functional native tests ran on arm64; Intel was compiled, not run.
- Signing: **ad-hoc signed; not notarized**.
- App identifier: `org.nextpadplusplus.mac.integration`.
- Separate configuration: `~/Library/Application Support/Nextpad++ Integration`; preferences also use the integration bundle identifier.
- Base: Nextpad commit `ba956f5536ad063a4ea339e7c9569db5388af766`; Notepad++ reference `f68849b21529bfe8acbccf0255c4cc421402d6bc`.
- Components: **Scintilla 5.6.6 / Lexilla 5.5.3**; 34 original Notepad++ API dictionaries are bundled.
- [Combined source](https://github.com/chocholom/nextpad-plus-plus-macos/tree/integration/macos-parity-20261020). The exact packaged source commit, ZIP SHA-256 and build number are recorded in `artifact.json` and the app's Info.plist.

Tracked source files in both original repositories were left unchanged. This working copy, its tests and this report are under `out/nextpad-macos-20261020/source` in the Notepad++ workspace. The task began on October 15; the final package and validation are dated October 20.

## New upstream PRs

| PR | Change |
| --- | --- |
| [#424](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/424) | Fix selections, search results and status legibility |
| [#426](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/426) | Preserve loaded EOL mode through theme changes |
| [#427](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/427) | API XML completion and real parameter hints |
| [#428](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/428) | Rectangular sorting and Unicode multiple-selection case conversion |
| [#429](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/429) | CLI forwarding and settings-directory startup |
| [#430](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/430) | Boost-compatible Function List parsers |
| [#431](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/431) | VoiceOver tab accessibility |
| [#432](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/432) | Named session state and unsaved text |
| [#433](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/433) | File and directory exclusion filters |
| [#434](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/434) | Shared plugin and macro command map |
| [#435](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/435) | Scintilla 5.6.6 and Lexilla 5.5.3 |

The EOL follow-up #426 is stacked on #372. File filters #433 are stacked on #403, which depends on #377. Their existing commits and authorship are retained; merge the bases first and rebase the follow-ups. Other new feature branches were prepared against upstream main. Some existing PRs touch the same files, so upstream merge order may still require rebasing.

## Existing PRs included

| PR | Change |
| --- | --- |
| [#372](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/372) | Detect line endings and apply new-document EOL preference |
| [#374](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/374) | Reserve non-overlapping plugin marker and indicator IDs |
| [#357](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/357) | Option-Shift arrow word selection |
| [#293](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/293) | Assignable plus/minus shortcuts |
| [#407](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/407) | Middle-click tab close |
| [#405](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/405) | Clear unsaved-tab indicators |
| [#398](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/398) | Theme-aware side panels |
| [#399](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/399) | Shared-document themed Document Map |
| [#375](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/375) | Remember light/dark editor themes and follow appearance |
| [#377](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/377) | Cancelable Find in Files and legacy text encodings |
| [#379](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/379) | Save edits from User Defined Language dialog |
| [#381](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/381) | Native fonts and cancellable tab-close tracking |
| [#387](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/387) | Correct lexer keyword-list slots |
| [#395](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/395) | Merge updated models into existing user XML |
| [#393](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/393) | Distinct C/Objective-C/TypeScript styles and theme layers |
| [#391](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/391) | Tab tear-off and cross-window movement |
| [#411](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/411) | Restore recently closed file |
| [#414](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/414) | Exit-on-last-tab preference |
| [#365](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/365) | Custom default tab colours |
| [#389](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/389) | UDL nesting, colours, fonts and extension precedence |
| [#401](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/401) | Lexer substyles and Style Configurator keywords |
| [#403](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/pull/403) | One Boost search engine and headless tests |

The three draft stacks were included after integration validation: #389 after #379, #401 after #387, and #403 after #377. The combined branch resolves their overlaps with appearance themes, style layers, marker IDs, tab movement and recently closed tabs.

## Behavior added or corrected

**Line endings.** Files use their detected LF/CRLF/CR mode; new documents use the preference. Applying themes/preferences cannot reset the loaded mode. Regression tests press Enter and compare saved bytes for all three modes, test clones, and exercise all default preferences. Mixed-EOL files follow the first line break rather than being normalized silently.

**Search and editing.** Multiple-selection upper/lowercase uses Scintilla's native operations. Other case modes preserve independent Unicode selections and undo. Rectangular sorting uses the selected display columns and moves whole rows. Search-result copying removes generated metadata while preserving source colons and Unicode; zero-hit runs produce a new history header and honor purge; result widths track content. Status text follows editor zoom.

**Completion and parsers.** Completion combines document words with original API XML dictionaries, user overrides and language aliases. Real signatures, overload navigation and active-parameter highlighting replace placeholder hints. Function List uses Boost expressions directly and maps captures correctly around Unicode text. This is API/dictionary completion, not semantic completion from a language server.

**Named sessions.** Version 3 retains panes/shared documents, stream and rectangular selections, virtual space, scrolling, folds, bookmarks, language, encoding, selected tabs, pinning, colours and unsaved/untitled text. Restoring a conflicting snapshot preserves the current modified buffer. Existing session files remain readable.

**CLI and accessibility.** A second invocation forwards relative paths and flags to the running instance. Line/column/language are applied by the normal opener. Settings-directory overrides are set before configuration is read; the toolbar reader no longer collides with Objective-C `+load`. macOS-injected argument values are skipped. Tabs expose selection, state, position/count and close actions to accessibility clients.

**Native plugin bridge.** Imported macros and NPPM_MENUCOMMAND share a command map for actions already implemented by Nextpad. Plugin default shortcuts use the host mapping. This does not make Windows DLL plugins loadable on macOS.

**Issue #267.** Persisted SCI_LINESCROLLDOWN and SCI_LINESCROLLUP assignments were verified through real Cocoa key events in this build. No additional scrolling implementation was needed.

## Validation

- **83 native AppKit checks pass.** They construct real editors/windows/panels, use Scintilla, save/reopen temporary files, exercise accessibility actions and launch a second copy of the actual CLI binary.
- **6/6 search suites pass:** editor regex, Boost backend, shared buffer search, file-search core and both standalone regex harnesses. These cover cancellation, legacy encodings, replacement round trips, invalid/complex regexes and concurrent searching, alongside new file-filter tree tests.
- **37 XML resources parse:** English localization, both models and all 34 completion dictionaries.
- **Universal binary and code signature verified** during packaging.
- Native tests use a separate bundle ID and temporary configuration. The runner restores the clipboard if no intervening user change occurred.

The logs distributed beside the package are `native-validation.log` and `headless-validation.log`. Normal builds still emit pre-existing nullability/deprecation warnings; no compiler or test failures remain in the delivered build.

Automated coverage verifies the accessibility API, not spoken VoiceOver interaction. Human QA remains useful for VoiceOver speech/navigation, interactive tear-off/drop gestures, close-button mouse tracking, custom colour-picker interactions and mixed monitor/older macOS layouts. Intel and older supported macOS versions were not available for runtime validation. These limits are distinct from the code and automated behavior included above.

## Still missing or separate projects

- Full Notepad++ plugin compatibility: Windows DLL binaries, Win32 UI/message assumptions and many NPPM APIs still require native ports or further bridge work. This work does not port NppExec (#368).
- A redesigned automatic update/installation flow (#417). The integration retains the existing updater; an upstream update may replace the integration, so compare the release first.
- iPadOS/iOS ports (#91/#106), and JSTool on Linux (#420).
- Full Notepad++ file-format/config interchange. In particular, old macOS `config.xml` EOL preference numbers and Windows' numeric convention still differ; document EOL detection/editing is fixed independently.
- Exhaustive feature parity and edge cases in every UDL/parser/plugin. The manifest records what was included and what was actually checked; it is not a claim that all Notepad++ behavior is identical.

## Comparing a future release

`docs/integration-manifest.json` records all 33 PR head commits, their patch bases, dependencies and issue associations. Do not use issue closure or a release number alone as proof that a fix shipped.

From the source checkout:

```sh
git fetch origin --tags
python3 tools/compare-upstream.py --ref <release-tag> --patches --github
```

Use `--repo /path/to/another/checkout` for a separate upstream checkout, and `--json` for machine-readable results. Fetching the integration branch into that checkout makes the frozen PR commits available for patch comparison. The script checks commit ancestry, optional stable patch IDs and the actual PR merge commit. A squash, reimplementation or refactor can remain unconfirmed even when the behavior exists. A closed PR can also have been superseded.

After inspecting inclusion evidence, rerun the behavior checks against the candidate release, adapting the harness if its internal API changed. A compile failure in the harness alone is not proof of a user-visible regression. Pay particular attention to exact EOL bytes, zero-hit search history, unsaved-session conflicts, lexer/UDL style fidelity and the second-process CLI path.

## Reproducing this build

Requirements: macOS with a logged-in GUI session for the native runner, Xcode command-line tools, CMake and Ninja.

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DNPP_BUILD_TESTS=ON
cmake --build build -j 6
cmake --build build --target npp_tests -j 6
ctest --test-dir build --output-on-failure
python3 tests/run_native.py
python3 tools/package-integration.py --output ../release
```

`-settingsDir=/absolute/path` overrides configuration files. `NEXTPAD_SETTINGS_DIR` is also available for isolated automation. NSUserDefaults follows the bundle ID, so configuration-file overrides alone do not create a separate preferences domain.

The initial temporary staging directory was pruned between interrupted runs. Surviving edits were moved into this durable workspace; missing files were reconstructed from the recorded index, published PRs and official archives. All reconstructed custom vendor merges match their recorded hashes. The final source was rebuilt and its complete reachable object graph checked before publication, followed by the validation above.
