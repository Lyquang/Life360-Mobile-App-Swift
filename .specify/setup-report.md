# Kết quả setup Spec Kit — 2026-11-13

## Phạm vi và approval

Phase A chỉ đọc; người dùng đã duyệt Phase B bằng “tôi duyệt”. Phạm vi là cấu hình
workflow, không triển khai feature, refactor app, đổi dependency app, CI, nhánh,
commit hoặc push. Working tree đã có thay đổi Place Search và cleanup trước setup;
chúng được bảo toàn. Không tạo feature mẫu hoặc tự ghi duyệt cho feature đang làm dở.

## Repository discovery

| Hạng mục | Bằng chứng hiện tại |
| --- | --- |
| Nền tảng | Native iOS, deployment target 16.0, 203 Swift source files |
| Ngôn ngữ/toolchain | Swift language mode 5; Xcode 26.2, Apple Swift compiler 6.2.3 |
| UI/navigation/state | SwiftUI + UIKit/MapKit; MVVM-C; Coordinator navigation; Combine/ObservableObject/@Published/MainActor |
| Kiến trúc | App/DI → Presentation → Domain UseCases/repository protocols → Data/Core |
| Packages/build | SPM/Xcode; XcodeGen project.yml có sẵn, không regenerate project |
| Native dependencies | GoogleSignIn 10.0.0, Pulse 5.2.3, Socket.IO 16.1.1 theo Package.resolved; MapKit/CoreLocation/Motion |
| Networking/server state | URLSessionAPIClient, Endpoint, typed DTO/mapper/repository, TokenRefreshCoordinator; không có server-state library riêng |
| Storage/auth | Keychain cho token; UserDefaults preferences/search cache và feature-specific cache/offline buffer |
| Form/validation | SwiftUI Form/FTTextField và logic UseCase/DTO theo feature; không phát hiện thư viện form/validation riêng |
| Styling/reuse | FTDesignSystem, common components, CachedMediaImage, MediaImageLoader, L10n và vi/en |
| Tests/lint | Standalone Swift/shell contract suites, XCTest source, localization UI harness; SwiftLint allowlist, không có formatter riêng được xác nhận |
| Platform configuration | Info.plist, entitlements, location/background/privacy và localized purpose strings có sẵn |

Code-quality findings chỉ được báo cáo: Domain AuthUseCases còn import UIKit,
AddPlaceSheet còn display literals, một số composition/ViewModel file lớn cần review
theo scope. Chưa kết luận file lớn là lỗi; không sửa chúng. API Location index có link
Study chưa tồn tại trong checkout. App scheme có TestAction nhưng 0 TestableReference;
XCTest source không chứng minh đã chạy.

## Integration đã cài

- uv 0.13.8, standalone user install tại `$HOME/.local/bin`, không sửa shell profile.
- specify-cli **1.4.0** từ GitHub tag v1.4.0,
  commit `0019fa14d12f45edabc2cc3176c9168a68bd0f97`, do uv tool quản lý ngoài repo.
- Native init được chạy trong thư mục tạm để review; integration Codex được cài
  qua CLI và core managed files được refresh có kiểm soát sau backup.
- Integration Codex native, default Codex, Bash helpers, sequential numbering,
  9 native skills. Không cài git extension hay thêm server/plugin bên ngoài.
- Preset native `familytracker-mobile` 1.0.0, đúng 1.4.0, gồm 3 template append và
  5 command prepend. Nguồn là `.specify/mobile-preset/`, installed copy được CLI quản lý.
- Bundled workflow `speckit` 1.0.1 có overlay local; thứ tự được CLI xác minh:
  specify → review-spec → plan → review-plan → tasks → mobile-analysis →
  mobile-approval → implement → mobile-verification-documentation → mobile-convergence.
- `.spec/` giữ nguyên bằng local creation helper override. Core scripts/templates
  giữ provenance chính thức; supporting templates bổ sung không thay native artifacts.

Local override trong bản pinned luôn replace; vì vậy append/prepend dùng preset
manifest, không gắn frontmatter rồi giả định local override sẽ compose. Python hệ
thống thiếu PyYAML; `.specify/env.sh` chọn Python của CLI đã có dependency đó.
Không cần repo venv và không cài package vào Python hệ thống.

## File được tạo hoặc cập nhật trong setup

```text
AGENTS.md
AI_RULES.md
TOOLING.md
PROGRESS.md
.spec/README.md
scripts/test_specify.sh
.agents/skills/
  speckit-{specify,clarify,plan,tasks,analyze,implement,converge,checklist,constitution}/SKILL.md
.specify/
  .gitignore
  env.sh
  README.md
  setup-report.md
  init-options.json
  integration.json
  integrations/{codex,speckit}.manifest.json
  memory/constitution.md
  mobile-preset/
    preset.yml
    templates/{spec,plan,tasks}-template.md
    commands/speckit.{specify,clarify,analyze,implement,converge}.md
  presets/
    .registry
    familytracker-mobile/                 # CLI-installed copy of the preset above
  scripts/bash/
    common.sh
    create-new-feature.sh
    check-prerequisites.sh
    setup-plan.sh
    setup-tasks.sh
    resolve-template.sh
  templates/
    {constitution,checklist,spec,plan,tasks}-template.md
    overrides/
      scripts/create-new-feature.sh
      {interview,progress,verification,study}-template.md
  workflows/
    workflow-registry.json
    speckit/workflow.yml
    overlays/speckit/familytracker-mobile.yml
```

Brace notation chỉ gộp tên file thật để đọc ngắn. Không liệt kê thay đổi app/CI có
trước task như kết quả của setup. `.spec/templates/` được giữ nguyên như legacy;
nguồn template active là core + preset + local supporting overrides.

## Engineering và API workflow

Constitution/AI_RULES bao phủ Clean Code, DRY/KISS/YAGNI, UI và logic reuse, state
ownership, performance bằng bằng chứng, API correctness, scope safety, approval,
vi/en, accessibility, lifecycle/concurrency và location/battery/privacy.

Backend docs được nhận trong api-docs/ hoặc attachment, tham chiếu nguồn/revision
thật, mapping endpoint/event → DTO/mapper/repository → UI → verification. Authority
và Pending/Conflict/blocking questions được ghi rõ; không tự đoán production data,
đổi Backend, test unsafe hoặc copy toàn bộ contract sang mỗi feature.

SMALL/STANDARD/COMPLEX và logical roles được cấu hình bằng instructions, không
phải chín agent hay chín command mới. Tasks có native IDs; progress giữ phase/
approval/API/refactor/docs state; root PROGRESS chỉ tổng hợp. Study dùng tiếng Việt,
link source và kết quả thật. Hướng dẫn hằng ngày, API handoff, interview, duyệt,
refactor, verify và resume nằm trong [README](README.md#daily-usage-trong-codex).

## Verification results

| Kiểm tra | Kết quả |
| --- | --- |
| specify version | Passed: 1.4.0, Python 3.14.4, Darwin arm64 |
| specify check | Passed: CLI ready, Codex CLI available; agent khác không bắt buộc |
| Native managed-core hashes | Passed: scripts/templates khớp CLI manifest |
| JSON/Bash syntax, skill frontmatter | Passed |
| Preset source/installed consistency | Passed |
| Native + mobile template composition | Passed: giữ native content và mobile additions |
| 9 generated skills | Passed; approval preamble đứng trước native implementation |
| Workflow/overlay resolution | Passed: analysis và approval trước implementation |
| Isolated .spec numbering/creation | Passed: không tạo specs/ hoặc .git; dry-run không ghi state |
| Existing plan + no-persist selection | Passed: plan/pointer được bảo toàn |
| Real native gate, non-interactive | Passed: paused; harmless marker step sau gate không chạy |
| Protected-file checksum comparison | Passed: 387 file app/test/API/spec giữ nguyên từ baseline Phase B, trừ index spec chủ đích cập nhật riêng |
| git diff --check | Passed |
| App build/business test suites/SwiftLint | Skipped: không có thay đổi app/build/lint; setup test là check phù hợp |
| Simulator/device/visual/energy/performance | Unverified; không tuyên bố đã chạy |
| Feature workflow qua model dispatcher | Unverified; không gọi model hay triển khai feature trong setup |

Không có setup check đang fail. Những lỗi composition/environment tìm trong lúc
setup đã được sửa và kiểm tra lại. Bộ kiểm tra tái chạy bằng:

```bash
bash scripts/test_specify.sh
```

Gates terminal và skill instructions là workflow controls, không phải security
sandbox. Resume approval phải do người dùng thực hiện; không agent nào được tự điền
duyệt. CLI web docs có thể đi trước 1.4.0: các lệnh thực tế đã đối chiếu --help/source.
Upgrade cần review preset, overrides và rerun checks; không tự nâng dependency.
