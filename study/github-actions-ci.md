# GitHub Actions CI Research - FamilyTracker iOS

> Current configuration: all pull requests targeting `main` trigger iOS CI and
> Code Quality, including documentation-only changes. Documentation-only pushes
> to `main` still use the original `paths-ignore` filter. The original design
> notes below describe the earlier configuration.

Date: 2026-10-12

## 1. Repository inventory

| Item | Current state | CI implication |
| --- | --- | --- |
| Repository | Public, default branch `main` | Standard GitHub-hosted runners are currently free |
| Xcode container | `FamilyTracker.xcodeproj`; no standalone `.xcworkspace` | Use `xcodebuild -project` |
| Shared scheme | `FamilyTracker` | Safe for CI; scheme is committed |
| Native targets | One application target: `FamilyTracker` | There is no XCTest or UI-test target |
| Deployment target | iOS 16.0, Swift 5.0 | Task description says iOS 17+, but project metadata is authoritative for CI |
| Local Xcode | Xcode 26.2, build `17C52` | Match Xcode 26.2 in CI |
| Project format | `objectVersion = 77`, `LastUpgradeCheck = 2620` | Prefer the same Xcode generation as local builds |
| Signing | Automatic, Personal Team configured | CI overrides with `CODE_SIGNING_ALLOWED=NO` |
| Entitlements | APS development, location push and Wi-Fi info are present | Do not alter them in this CI task; unsigned simulator build succeeds |
| SPM lockfile | `FamilyTracker.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Hash this file for the SPM cache key |
| Direct SPM packages | Pulse 5.2.3, Socket.IO 16.1.1, GoogleSignIn 10.0.0 | Cache cloned package sources, not DerivedData |
| Tests | Standalone Swift executables under `Tests/`; no Xcode test target | Build app, then run the two deterministic shell test scripts |
| SwiftLint | No `.swiftlint.yml`; not installed locally | Use pinned official Linux binary in quality workflow |
| Existing CI | No `.github` workflows | Status-check names can be designed cleanly |
| Root npm lockfile | Empty `package-lock.json`, added with Google OAuth work | Removed after approval; npm Dependabot is intentionally not configured |

`Tests/LocalizationUITests.swift` is not part of the app project. Its helper script
generates a temporary project with XcodeGen and expects a pre-booted simulator and an
installed app. It is intentionally excluded from the first CI version because it is
more expensive and less deterministic than the two standalone contract suites.

## 2. Package and configuration findings

`Package.resolved` contains 11 resolved pins including transitive dependencies. The
three direct package references are declared in `project.pbxproj`. The cache should use:

```text
${RUNNER_TEMP}/SourcePackages
key = spm-${runner.os}-xcode-26.2-${hashFiles('**/Package.resolved')}
```

The build must pass the same directory through
`-clonedSourcePackagesDirPath`. Caching all DerivedData is avoided because it is much
larger and is more likely to become invalid across Xcode/compiler changes.

Google Sign-In does not use `GoogleService-Info.plist`. `GIDClientID` and the reverse
URL scheme are committed in `Info.plist`. An OAuth client ID is an application
identifier, not a client secret; it cannot authorize server access on its own. CI
therefore needs no Google secret or generated placeholder. A future client secret,
service-account JSON, private key or refresh token must never be committed and would
need GitHub Secrets. `.gitignore` should proactively cover `GoogleService-Info.plist`,
`Secrets.xcconfig` and user-local xcconfig variants without ignoring the existing
public `Info.plist`.

## 3. Runner and Xcode selection

Use `macos-15`, not a floating beta image. The current official image inventory lists:

- Xcode 26.2 at `/Applications/Xcode_26.2.app`.
- iOS 26.2 SDK/runtime.
- iPhone 17 simulator for iOS 26.2.
- `xcbeautify` 3.2.1 and SwiftLint 0.65.1 preinstalled.

Source: [GitHub macOS 15 runner image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md).

The workflow should call `sudo xcode-select -s` directly. This removes a third-party
setup action from the supply chain. Since there is no Xcode test target, the build can
use `generic/platform=iOS Simulator`; this destination does not depend on a booted
device. If an XCTest target is added later, use the verified `iPhone 17, OS=26.2`
destination or discover a device dynamically using `simctl`.

GitHub documents `macos-15` and `macos-latest` as standard arm64 runner labels and
notes that public repositories receive unlimited standard-runner usage:
[GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## 4. Proposed workflow design

### macOS build job

Trigger on pushes and pull requests targeting `main`, while ignoring Markdown-only,
`study/**` and `api-docs/**` changes. Use workflow-level `contents: read`, concurrency
by workflow and ref, and a 12-minute timeout.

Steps:

1. Checkout with credentials not persisted.
2. Select Xcode 26.2 and print `xcodebuild -version`.
3. Restore cloned SPM sources using `actions/cache`.
4. Resolve package dependencies using the shared scheme and cache path.
5. Run `xcodebuild build` for generic iOS Simulator with signing disabled,
   `set -o pipefail`, `xcbeautify`, DerivedData in runner temp and an `.xcresult`.
6. Run `bash scripts/test_networking.sh` and `bash scripts/test_localization.sh`.
7. Write a concise `$GITHUB_STEP_SUMMARY`.
8. Upload `.xcresult` only when the job fails, with five-day retention. Failure-only
   upload minimizes artifact storage while retaining compiler diagnostics when useful.

There is deliberately no `xcodebuild test`: the shared scheme has an empty TestAction
and the project has no test bundle. Calling it would provide a misleading green result.

### Ubuntu quality job

Use `ubuntu-latest`, a 6-minute timeout and `contents: read`. Checkout uses
`fetch-depth: 0` because Gitleaks must inspect full history.

- Download official SwiftLint 0.65.1 Linux binary and verify its published SHA-256.
- Run a small `only_rules` policy without `--strict` initially.
- Download official Gitleaks 8.30.1 Linux binary, verify SHA-256, then scan Git history
  with full redaction.

Using verified upstream binaries keeps lightweight checks on Linux and avoids both a
Docker pull and third-party wrapper actions. Versions are explicit and reviewable.

## 5. SwiftLint baseline

SwiftLint 0.65.1 was downloaded from the official release and its macOS archive hash
was verified before measuring the repository.

| Policy | Total | Warnings | Errors |
| --- | ---: | ---: | ---: |
| Default SwiftLint rules | 269 | 244 | 25 |
| Proposed light rules (`FamilyTracker/`) | 11 | 11 | 0 |

The default result is dominated by trailing whitespace (84), line length (72), and
short identifier names (47), including legitimate image-code variables. Enabling all
rules now would make CI noisy and encourage blanket suppressions.

The initial lint scope is the shipping app source under `FamilyTracker/`; standalone
contract harnesses are compiled and executed by their dedicated scripts. Initial rules:
`force_cast`, `force_try`, `unused_import`, `duplicate_imports`,
`empty_count`, `empty_string`, `control_statement`, `comma`, and `colon`. Exclude
`.build`, `Build`, `DerivedData`, `Pods`, `Carthage`, and `SourcePackages`. Run
non-strict with a warning threshold above the current 11; tighten rule-by-rule later.

Source/version: [SwiftLint 0.65.1 release](https://github.com/realm/SwiftLint/releases/tag/0.65.1).

## 6. Secret scan finding

Gitleaks 8.30.1 scanned all seven current commits and reported two findings. Both are
the same `generic-api-key` detection at line 162 of historical
`GOOGLE_OAUTH2_MOBILE_API_DOC.md`, in commits `8dd7ff6a` and `31d5de76`. Manual review
confirmed the value is a deliberately truncated sample Google ID token ending in
ellipsis, not a usable token.

Recommended handling: add the two exact Gitleaks fingerprints to `.gitleaksignore`
with a comment explaining the reviewed truncated fixture. Do not add a broad regex for
JWTs, do not suppress the whole documentation path, and do not rewrite/force-push Git
history. This keeps future real JWT findings actionable.

## 7. Dependabot

Configure weekly updates for:

- `swift`, directory `/`, to discover the committed SPM resolution used by the Xcode project.
- `github-actions`, directory `/`, to update pinned workflow actions.

Do not add npm because the lockfile has no packages and the iOS repo has no
`package.json`. GitHub lists `swift` as the supported ecosystem value and
`Package.resolved` as the recommended SPM dependency file:
[Dependabot options](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference),
[dependency graph ecosystems](https://docs.github.com/en/enterprise-cloud@latest/code-security/reference/supply-chain-security/dependency-graph-supported-package-ecosystems).

## 8. Supply-chain choices

- Do not use `pull_request_target`.
- Pin GitHub-maintained actions to full commit SHA with a release comment.
- Set `persist-credentials: false` on checkout.
- Prefer `xcode-select` over a setup action.
- Verify SHA-256 for downloaded SwiftLint and Gitleaks binaries.
- Give workflows only `contents: read`; no write token and no repository secrets are
  exposed to pull requests.

## 9. Cost estimate

The repository is currently public, so standard GitHub-hosted macOS and Linux jobs are
free. If it becomes private, current list pricing is $0.062/minute for standard macOS
and $0.006/minute for standard Linux, approximately 10.3 times different. GitHub Free
currently includes 2,000 standard-runner minutes per month.

Sources: [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
and [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing).

Example for 20 PR updates plus 10 pushes to `main` per month: 30 macOS runs. At an
expected 4-8 minutes each, that is 120-240 macOS runtime minutes. Linux quality checks
should remain under two minutes per run. `paths-ignore` and concurrency cancellation
reduce duplicate spend; actual duration should be reviewed after the first ten runs.

## 10. Local verification

Verified successfully on the current machine:

- `xcodebuild -project FamilyTracker.xcodeproj -list`: one app target and one scheme.
- CI-equivalent unsigned generic Simulator build with Xcode 26.2, cloned package path,
  DerivedData path and `.xcresult`: pass.
- `bash scripts/test_networking.sh`: pass.
- `bash scripts/test_localization.sh`: pass, including 243 translations.
- SwiftLint baseline measurements above.
- Gitleaks full-history scan and manual review above.

Local `xcbeautify` is absent, so local verification used `xcodebuild -quiet`. The
official `macos-15` runner currently includes `xcbeautify` 3.2.1; CI should still check
that the command exists and fall back to raw `xcodebuild` output if the image changes.
The final implementation was also parsed with the local Ruby YAML parser. `actionlint`
was not installed locally; the workflow shell commands, lint, secret scan and unsigned
build were exercised directly instead.

## 11. Risks and follow-ups

- The task description says iOS 17+, while the project deploys to iOS 16.0. CI must not
  silently change product support; use the project value and resolve separately.
- Personal Team limitations do not matter for unsigned simulator builds, but the
  repository currently contains APS/location-push entitlements despite the stated
  capability limitation. CI will not modify or validate device signing.
- A future XCTest target is desirable for media policy, DTO decoding and retry logic,
  but adding it modifies `project.pbxproj` and should be a separate approved task.
- Runner image inventories evolve. Pinning `macos-15` and Xcode 26.2 is reproducible
  now, while Dependabot plus periodic maintenance must handle eventual image removal.

## 12. Approved implementation choices

The implementation was approved with these decisions: no Conventional Commit title
gate, remove the empty root npm lockfile, start SwiftLint non-strict from the measured
11-warning baseline, exact-allowlist the two reviewed Gitleaks fingerprints, and defer
XCTest target/project-file changes. The resulting workflows are
`.github/workflows/ci.yml` and `.github/workflows/quality.yml`.
