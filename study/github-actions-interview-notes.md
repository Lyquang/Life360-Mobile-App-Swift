# GitHub Actions CI - Interview Notes

## 1. Pipeline overview

FamilyTracker separates CI by workload and cost:

| Workflow | Runner | Responsibility |
| --- | --- | --- |
| `iOS CI` | `macos-15` | Resolve SPM, unsigned Simulator build, networking and localization contract tests |
| `Code Quality` | `ubuntu-latest` | SwiftLint baseline and full-history Gitleaks scan |

Both workflows run on pushes and pull requests for `main`, skip documentation-only
changes, cancel superseded runs and operate with `contents: read`. GitHub-maintained
actions are pinned to full commit SHAs. Downloaded tools are pinned by version and
verified with SHA-256 before execution.

## 2. Why this design

### Why not run everything on macOS?

Xcode requires macOS, but SwiftLint and Gitleaks have official Linux binaries. Moving
those checks to Ubuntu gives faster scheduling and significantly lower private-repo
cost while keeping the Xcode job focused. Public repositories currently receive free
standard-runner usage.

### Why an unsigned generic Simulator build?

The CI objective is compile-time and contract validation, not distribution. A generic
iOS Simulator build does not require certificates, provisioning profiles, a booted
device or repository secrets. `CODE_SIGNING_ALLOWED=NO` prevents a Personal Team or
capability configuration from making pull-request builds nondeterministic.

### Why cache SPM sources but not DerivedData?

The cache key includes OS, Xcode version and `Package.resolved`. Cloned package sources
are expensive to download but relatively stable. DerivedData is much larger and tightly
coupled to compiler flags and source state, so caching it offers less reliable value.

### Why no `xcodebuild test`?

The project currently has one app target and no XCTest bundle; the shared scheme's
TestAction is empty. CI instead executes the two real standalone contract suites. Adding
an XCTest target is a separate project-file change, not something the pipeline should
pretend already exists.

### Why a small non-strict SwiftLint baseline?

Default SwiftLint produced 269 findings, including 25 errors. The initial app-source
policy enables high-signal correctness and formatting rules and currently reports 11
warnings with no errors. Standalone contract harnesses are compiled by their scripts.
`warning_threshold: 20` prevents uncontrolled regression while allowing the team to
clean the baseline and tighten rules incrementally.

### Why scan full Git history?

A credential removed from the current tree may remain usable from an old commit.
Checkout therefore uses `fetch-depth: 0`. Two historical findings are exact-allowlisted
because manual review confirmed the value was a deliberately truncated fixture. New
values in the same file are still detected.

## 3. Failure diagnostics

The build writes an `.xcresult` bundle in runner temporary storage. It is uploaded only
when the job fails and retained for five days. This preserves compiler diagnostics while
avoiding artifact storage on healthy runs. `set -o pipefail` ensures a failed
`xcodebuild` is not hidden by `xcbeautify`.

## 4. Supply-chain controls

- Workflow permissions are read-only; checkout credentials are not persisted.
- `pull_request_target` is not used, so untrusted pull-request code does not receive a
  privileged base-repository token.
- Action versions use immutable commit SHAs, with release tags retained as comments.
- SwiftLint and Gitleaks archives are downloaded over HTTPS and checksum-verified.
- Dependabot reviews Swift packages and GitHub Actions weekly.
- OAuth client IDs in `Info.plist` are identifiers, not secrets. No CI secret is needed
  for the current unsigned build.

## 5. STAR interview answer

**Situation:** The iOS repository compiled locally but had no automated gate, no native
test target and dependencies that required a recent Xcode image.

**Task:** Create a secure, cost-conscious CI pipeline without changing app behavior or
requiring signing credentials.

**Action:** I inventoried the project and shared scheme, matched Xcode 26.2 on
`macos-15`, disabled signing, cached only SPM source checkouts, ran the existing contract
suites and moved lint/secret scanning to Linux. I pinned actions to full SHAs, verified
tool checksums, constrained token permissions and retained `.xcresult` only on failure.

**Result:** Every pull request can now prove that the app compiles and its networking and
localization contracts pass. Quality checks cover high-signal Swift issues and the full
Git history without adding macOS minutes. The remaining deliberate gap is a real XCTest
target, documented as follow-up work rather than represented by a misleading test step.

## 6. Việc tôi cần tự làm trên GitHub

After the workflows have run once on GitHub:

1. Open **Settings -> Rules -> Rulesets** (or Branch protection), target `main`, require a
   pull request and require these status checks: `Build & Contract Tests` and
   `SwiftLint & Secret Scan`.
2. Open **Settings -> Actions -> General** and keep default workflow permissions at
   **Read repository contents and packages permissions**.
3. Open **Settings -> Code security and analysis** and enable Dependabot alerts,
   Dependabot security updates, secret scanning and push protection where available.
4. Confirm the first Dependabot run recognizes `swift` from the nested
   `Package.resolved`. If GitHub reports no manifest, set its directory to
   `/FamilyTracker.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`.

No repository Actions secret is required for the current pipeline. Distribution through
TestFlight would be a separate workflow requiring App Store Connect credentials and
signing assets.

### Pull-request smoke test

1. Push these files to a branch and open a pull request into `main` containing a Swift
   or workflow change.
2. Confirm both `Build & Contract Tests` and `SwiftLint & Secret Scan` appear and pass.
   A Markdown-only pull request should intentionally skip both workflows.
3. To verify diagnostics later, make a temporary branch with a compile error. Open the
   failed `iOS CI` run and download `FamilyTracker-xcresult-<run-id>` from **Artifacts**.
   Remove the temporary error afterward.
4. Add future CI credentials only under **Settings -> Secrets and variables -> Actions**,
   scope them to the workflow that needs them, and never print them. There are no secrets
   to add for this build-only pipeline.
