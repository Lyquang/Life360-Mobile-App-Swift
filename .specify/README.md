# Spec Kit — FamilyTracker Mobile

Spec Kit CLI **1.4.0** và integration **Codex** đã được cài cho workflow này.
[AGENTS.md](../AGENTS.md) là điểm vào Codex; [AI_RULES.md](../AI_RULES.md) chứa quy chuẩn
kỹ thuật; [constitution](memory/constitution.md) quản trị feature. Đặc tả luôn ở
[.spec/](../.spec/README.md). Không có thay đổi business logic trong setup.

## Cài đặt và môi trường

Tool được cài ngoài repo, trong user tool directory; không có Python venv trong app.
uv và specify ở `$HOME/.local/bin`. Trước **mỗi shell invocation** chạy helper, source:

```bash
source .specify/env.sh
specify version
specify check
```

`env.sh` chỉ thay environment của shell hiện tại, không sửa shell profile. Nó chọn
Python của specify-cli có PyYAML để native template composition hoạt động; không
cài PyYAML vào Python hệ thống. Xcode/Swift dependencies không thay đổi.

Trên máy mới, cài uv theo [hướng dẫn chính thức](https://docs.astral.sh/uv/getting-started/installation/),
đưa executable vào PATH rồi cài đúng release đã kiểm chứng:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v1.4.0
source .specify/env.sh
specify integration list
```

Với checkout này, skills và cấu hình đã có sẵn. Nếu cần cài lại integration, dùng
`specify integration install codex`; đọc diff và bảo vệ customizations trước khi
refresh core. Không mặc định dùng `init --here --force` trên working tree có thay đổi.
Không tự nâng phiên bản: preset yêu cầu đúng 1.4.0, cần review khi upgrade.

## Native và phần tuỳ chỉnh

- `.specify/scripts/bash/` và template core: bản chính thức, có manifest provenance.
- `.agents/skills/speckit-*/SKILL.md`: 9 skills do CLI chính thức sinh; không sửa tay.
- `.specify/mobile-preset/`: nguồn chuẩn của 3 template addenda và 5 command preambles.
  Preset `familytracker-mobile` dùng native append/prepend, giữ nội dung core.
- `.specify/presets/familytracker-mobile/`: bản đã cài; sửa nguồn rồi refresh bằng CLI.
- `.specify/templates/overrides/scripts/create-new-feature.sh`: bản upstream 1.4.0
  chỉ đổi root `specs/` thành `.spec/` và vị trí source common.sh. Skill specify dùng
  dry-run của helper để lấy tên/số; native skill tạo spec từ template đã compose.
- `.specify/templates/overrides/{interview,progress,verification,study}-template.md`:
  supporting templates, chỉ tạo tài liệu feature khi cần. Không có lệnh Spec Kit giả.
- `.specify/workflows/speckit/`: bundled workflow đã đăng ký, có project overlay tại
  `.specify/workflows/overlays/speckit/familytracker-mobile.yml`.

Native core không tự hiểu `.spec/` là default. Phải dùng installed specify skill
có preamble của repo, hoặc helper override bên trên; không gọi core creation helper
trực tiếp cho feature mới. JSON dry-run trả SPEC_FILE; thư mục cha là feature dir.
Không cài git automation extension, không tự tạo/checkout branch hoặc commit.

Sau khi sửa preset source:

```bash
source .specify/env.sh
specify preset update familytracker-mobile --dev .specify/mobile-preset
bash scripts/test_specify.sh
```

Native local overrides là **replace**; append/prepend được khai báo ở preset manifest.
Không đặt addendum thay thế core tại đường dẫn override có tên native template.
Template cũ trong `.spec/templates/` được giữ để bảo toàn tài liệu; chúng là legacy,
không được workflow đang hoạt động dùng làm nguồn chính.

## Mode và trách nhiệm

| Mode | Áp dụng | Quy trình |
| --- | --- | --- |
| SMALL | Lỗi hoặc chỉnh UI nhỏ, scope rõ, không đổi material API/kiến trúc | Context → clarify nếu cần → fix → verify → docs phù hợp |
| STANDARD | Mặc định cho feature | Specify → clarify → API analysis → plan → tasks → analyze → approve → implement → refactor → verify → docs → converge |
| COMPLEX | Cross-feature, navigation/architecture/refactor lớn | Discovery/API/interview → requirements + architecture review → STANDARD theo milestone |

SMALL không buộc full bộ tài liệu. Yêu cầu sửa nhỏ trực tiếp của người dùng đủ cho
scope đó; không tạo vòng duyệt giả. Feature implementation/refactor đáng kể cần duyệt.
Nếu scope SMALL trở thành material thì chuyển STANDARD trước phần việc mới.

Một Codex có thể lần lượt đảm nhiệm: Orchestrator điều phối/gate; Mobile Analyst
requirements/UX; Architect architecture/state; API Specialist contracts; Developer
code đã duyệt; Clean Code Reviewer readability/reuse; Performance Reviewer bằng chứng;
QA requirements/regression; Documentation/Study tài liệu tiếng Việt. Đây là logical
roles, không yêu cầu spawn nhiều agent hoặc thay đổi model.

## Daily usage trong Codex

Các `$speckit-*` dưới đây là **skills gọi trong chat**, không phải shell commands.
Mở phiên Codex mới tại repo nếu skills mới chưa hiện trong danh sách.

1. Bắt đầu: `$speckit-specify <mục tiêu feature bằng tiếng Việt>`. Nêu constraints,
   thiết kế và Backend docs được cung cấp. Agent đọc context/reuse trước, tự chọn số
   tiếp theo trong `.spec/`; không copy một feature mẫu hoặc tự đổi branch.
2. Cung cấp Backend docs: đặt Markdown/OpenAPI YAML/JSON trong `api-docs/` hoặc attach
   tài liệu, rồi nói rõ đường dẫn/revision đã được duyệt. Không cần Backend source.
3. Làm rõ: `$speckit-clarify`. Phỏng vấn tiếng Việt, giữ câu trả lời thật và open
   questions trong interview.md khi đáng kể; sync vào Clarifications native của spec.
4. Chốt requirements khi còn điểm material chưa xác nhận; không hỏi lại câu đã rõ.
5. Lập plan: `$speckit-plan`. Kiểm tra `Reusability & Optimization Analysis`, state
   ownership, API mapping, file scope, refactor, localization và test plan.
6. Chia task: `$speckit-tasks`; IDs và story phases theo native. Chỉ task cần thiết,
   có tiêu chí hoàn thành; [P] chỉ cho công việc độc lập.
7. Phân tích: `$speckit-analyze`. Đối chiếu spec/interview/plan/tasks/API/source và
   constitution; giải quyết material findings trước implementation.
8. Agent trình review package: yêu cầu, API source/endpoints/status, UI states/screens,
   UI/logic reuse và phần mới, architecture/state, file/refactor/optimization scope,
   tasks, risks và tests. Ghi **AWAITING_APPROVAL**, chờ người dùng duyệt rõ.
9. Sau khi duyệt: `$speckit-implement`. Duyệt cùng scope trong session vẫn có hiệu lực.
   Không coi setup approval, generated flag hoặc plan là feature approval.
10. Refactor trong scope đã duyệt, kiểm tra shared consumers/navigation/API. Nếu cần
    đổi material behavior/architecture/API assumption/refactor scope thì duyệt lại.
11. Chạy checks phù hợp ở mục bên dưới; ghi bằng chứng vào verification.md.
12. Với feature đáng kể, yêu cầu cập nhật study.md bằng tiếng Việt: architecture,
    source/data flow/state/API/reuse/trade-offs/refactor/performance/tests/debugging.
13. `$speckit-converge` đối chiếu thực tế, ghi gap thành task IDs. Lặp implement/converge
    trong scope đã duyệt tới khi đạt yêu cầu; không tự duyệt scope mới.

Không bắt buộc tạo interview.md cho thay đổi đã rõ, study.md cho typo, hoặc mọi
supporting artifact cho một feature nhỏ. Có thể copy supporting template khi cần.

## API documentation workflow

Authority: contract/version đã duyệt → Backend docs được cung cấp → Mobile client/types
→ hành vi test được phép xác minh. Tìm theo feature, không quét tài liệu không liên quan.
Ghi revision Unknown nếu nguồn không cung cấp, không đoán version.

Trong spec dùng `Backend API Dependencies`; trong plan dùng bảng traceability:
source/revision → method/path/event → request/response/auth/status/errors →
DTO/mapper/repository → UI consumer → test/status. Bao phủ path/query/headers/body,
nullability/optional/enums/date, pagination/filter/sort/upload/versioning nếu có.
Dùng APIClient, TokenRefreshCoordinator và DTO/mapper hiện có, không tạo client thứ hai.

Contract status là Verified/Pending/Conflict/N/A. Mâu thuẫn phải chỉ rõ nguồn, phần
bị chặn và hỏi Backend hay Mobile đổi. Mock cần duyệt, isolate và migration path.
Tài liệu thay đổi: phân tích breaking/non-breaking và affected files, cập nhật đề
xuất rồi mới triển khai phần đã duyệt. Không gọi production để test unsafe.

Backend change request gồm endpoint/event, documented behavior, required behavior,
lý do, compatibility và Mobile feature ảnh hưởng. Không sửa Backend từ repo này.
Không duplicate toàn bộ API docs trong contracts/. Index Location hiện có một số
link tới tài liệu Study không nằm trong checkout: ghi nguồn chưa có, không suy diễn.

## Artifacts và resume

`spec.md`, `plan.md`, `tasks.md` cùng supporting artifacts native giữ format upstream.
`tasks.md` là checklist task duy nhất. Feature `progress.md` lưu mode/phase/approval
và evidence, API/refactor/docs status, verification link, remaining/blocked task IDs.
Root `PROGRESS.md` là summary + links, không sao chép checklist của feature.

Để tiếp tục, chỉ rõ feature directory hiện có trong chat, đọc artifacts và source
changes thật, so với tasks, khôi phục phase/approval rồi làm tiếp trong scope.
Không suy luận approval hoặc completion từ code đang có hay checkbox legacy.
Ví dụ chọn đọc feature hiện có, không ghi shared pointer:

```bash
source .specify/env.sh
SPECIFY_FEATURE_DIRECTORY=.spec/013-place-search SPECIFY_FEATURE_NO_PERSIST=1 \
  bash .specify/scripts/bash/check-prerequisites.sh --paths-only --json
```

Giá trị trên là feature đã có, không phải thư mục mẫu cho mọi tính năng. Khi làm
feature khác, dùng đường dẫn thật. `--paths-only` không khẳng định feature đã được duyệt.

## Automation tùy chọn

Manual skills là đường dùng hằng ngày và cho interview nhiều vòng. Workflow engine
cũng đã đăng ký `speckit` với analysis + human gate trước implement, verification/docs
và convergence sau implement. Review-spec và review-plan native vẫn được giữ.
Không dùng automation để bỏ qua câu hỏi/contract conflict chưa được giải quyết.

```bash
source .specify/env.sh
specify workflow info speckit
specify workflow resolve speckit
# Chỉ chạy khi chủ động muốn bắt đầu một feature; có thể gọi codex exec và dùng quota:
# specify workflow run speckit --input spec='<mục tiêu feature thật>'
# specify workflow status <run_id>
# specify workflow resume <run_id>
```

Ở bản pinned 1.4.0, gates của workflow này không khai báo verdict input. Khi không
có TTY, run dừng paused; người dùng chạy resume trong terminal tương tác và chọn
approve/reject. Không dùng ví dụ --input verdict của tài liệu phiên bản mới hơn.
Không tự chọn approve thay người dùng. Gate terminal và instruction trong skill là
workflow controls, không phải sandbox bảo mật. Chưa smoke-test một feature thật qua
Codex dispatcher, vì setup không được triển khai feature hay dùng model để giả duyệt.

## Verification có thật trong repo

```bash
bash scripts/test_specify.sh           # Tooling: temp fixtures, native composition and approval gate
bash scripts/test_networking.sh        # Khi API/auth/realtime liên quan
bash scripts/test_localization.sh      # Bắt buộc cho UI/localization
bash scripts/test_place_search.sh      # Khi search/history liên quan
swiftlint lint --config .swiftlint.yml # Theo scope/CI
xcodebuild build -project FamilyTracker.xcodeproj -scheme FamilyTracker \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

UI localization harness: chỉ chạy `SIMULATOR_ID=<booted-id> bash scripts/test_localization_ui.sh`
khi app đã cài, logged out và Simulator phù hợp. App scheme hiện không có testable
target; không gọi xcodebuild test trên scheme này rồi khẳng định XCTest đã chạy.
Setup không thay test target, CI hoặc package versions. Device GPS/pin/background,
visual accessibility và performance phải ghi Unverified nếu chưa thực hiện.

## Nguồn chính thức

- [Spec Kit v1.4.0](https://github.com/github/spec-kit/releases/tag/v1.4.0)
- [Codex integration](https://github.github.io/spec-kit/integrations/codex.html)
- [Presets và resolution](https://github.github.io/spec-kit/presets/api.html)
- [Workflow overlays](https://github.github.io/spec-kit/workflows/overlays.html)
- [Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

Tài liệu web có thể đi trước bản pinned: ưu tiên `specify <command> --help` và source
của 1.4.0 khi syntax khác nhau. Kết quả khảo sát/setup: [setup-report.md](setup-report.md).
