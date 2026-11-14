# Kiểm chứng: [feature]

**Ngày / revision được kiểm tra**: [giá trị thật]

| FR / story / task | Lệnh hoặc thao tác thật | Kết quả Passed/Failed/Skipped/Unverified | Bằng chứng / giới hạn |
| --- | --- | --- | --- |

## UI / API / regression

Ghi các state áp dụng, request/response/auth/nullable/error/pagination/cancellation,
shared consumers và navigation. N/A có lý do. Không test unsafe trên production.

## Performance và thiết bị

Vấn đề gốc → baseline → thay đổi → cách đo → kết quả → trade-off.
Không có phép đo/device/visual verification thì ghi Unverified, không đoán kết quả.

## Hạn chế và phần còn lại

[Task IDs hoặc release checks; không đánh dấu complete khi còn yêu cầu bắt buộc.]
