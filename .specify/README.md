# Spec Kit cho FamilyTracker

`.specify/` chứa quy chuẩn, mẫu và shell helper dựa trên cấu trúc Spec Kit; **đặc tả tính năng vẫn nằm trong `.spec/`**, xem [danh mục](../.spec/README.md). [Hiến chương](memory/constitution.md) tóm tắt quy chuẩn iOS; [AI_RULES.md](../AI_RULES.md) và chỉ dẫn người dùng là nguồn ưu tiên. Không áp dụng quy tắc React Native hay thông tin tích hợp của dự án mẫu.

## Trạng thái công cụ

Các script shell trong thư mục này có thể chạy trực tiếp bằng Bash. Workspace chưa xác nhận cài CLI `specify` hoặc các lệnh/agent `/speckit.*`; `integration.json` không khai báo integration được cài. `workflows/speckit/` là định nghĩa tham khảo chưa đăng ký, không chứng minh workflow engine hoặc agent đã có và không tự chạy. Các cổng duyệt trong workflow chỉ áp dụng khi quy trình đó được gọi và không thay thế chỉ dẫn của người dùng.

Spec Kit upstream mặc định dùng `specs/`; riêng helper `create-new-feature.sh` của repo đã chỉnh sang `.spec/`. Nếu sau này cài/khởi tạo CLI hoặc integration chính thức, kiểm tra lại đường dẫn và tránh `--force` ghi đè cấu hình hiện có. [Tài liệu upstream](https://github.com/github/spec-kit/blob/main/docs/quickstart.md) mô tả cách chọn feature và cài integration.

## Xem hoặc tạo đặc tả

```bash
# Dự kiến tên và số tiếp theo, không ghi file hay đổi nhánh.
bash .specify/scripts/bash/create-new-feature.sh --dry-run --short-name vi-du 'Tinh nang vi du'

# Khi cần tạo thật: tạo .spec/NNN-vi-du/spec.md từ template; không tạo hoặc checkout nhánh.
bash .specify/scripts/bash/create-new-feature.sh --short-name vi-du 'Tinh nang vi du'
```

Lệnh tạo thật cập nhật `.specify/feature.json` cục bộ; file này được gitignore vì mỗi workspace có thể chọn feature khác. Để chọn feature đã có một cách rõ ràng và tránh ghi state dùng chung:

```bash
SPECIFY_FEATURE_DIRECTORY=.spec/008-sos-assistance SPECIFY_FEATURE_NO_PERSIST=1 \
  bash .specify/scripts/bash/check-prerequisites.sh --json
```

Có thể thay đường dẫn bằng feature cần đọc. `--paths-only` chỉ báo đường dẫn; `setup-plan.sh` chỉ tạo plan nếu chưa có, và `setup-tasks.sh` báo template/nguồn để agent viết tasks chứ không tự sinh danh sách task hoàn chỉnh. Các tài liệu `.spec/templates/` vẫn được dùng cho quy trình thủ công; các template trong `.specify/templates/` đã được đồng bộ với chúng.

## Kiểm tra

```bash
bash scripts/test_specify.sh
```

Script kiểm tra trong thư mục tạm, không sửa branch hoặc các feature đang có. Trước khi đổi quy chuẩn, đối chiếu các thay đổi và tình trạng thật trong `PROGRESS.md`.
