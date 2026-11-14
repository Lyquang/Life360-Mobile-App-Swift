# Implementation Plan: iOS Design Workflow & Accessibility Quality

## Summary

Giữ Spec Kit1.4.0 và MVVM-C hiện có. Preset mobile1.1.0 thêm review thiết kế có điều
kiện trước native plan. Cài hai skill được yêu cầu trong project, audit source toàn
app, rồi sửa UI ít rủi ro theo §11 user attachment; không đổi nghiệp vụ/API/consent.

## Technical Context

Swift language mode5, iOS16, SwiftUI/UIKit, Combine. Không thêm dependency app.
SPM/Xcode project/native Spec Kit core giữ nguyên. QA dùng pattern XcodeGen UI-test
harness riêng đang có trong repo, không thêm auth bypass/test route vào production.

## Constitution Check

Đạt trước implementation: §11 người dùng cho phép styling/shared UI/accessibility
sau audit/plan. Evidence ghi trong progress.md, chỉ áp dụng batch ít rủi ro này.
Constitution được giữ nguyên từng byte. Không có API assumption, navigation, branding,
location state hay consent mới. Thay đổi material vẫn cần gate duyệt hiện tại.

## Design Review

Ứng dụng tiện ích gia đình, ưu tiên khả năng đọc và thao tác tin cậy. Giữ indigo,
SF Rounded, map-first và navigation hiện có. Inventory/findings trong design.md;
phân biệt source review với hình ảnh thật. Baseline compact-light Login xác nhận
form gray translucent làm chữ tối khó đọc; source xác nhận font cố định và eye nhỏ.

Tái sử dụng semantic text/surface colors và CardModifier; auth label/card cùng
appearance context. Native SecureField, system gestures, sheet dismiss, loading và
error state có thật được giữ nguyên. UI UX Pro Max/Mobile Design/HIG chỉ hướng dẫn
thiết kế; không thay Spec Kit orchestration hoặc tự duyệt requirement mới.

## Reusability & Optimization Analysis

- FTFont đổi sang system text styles cùng rounded weights; default role size giữ gần
  như cũ, nhưng đáp ứng system text settings.
- CardModifier thêm cornerRadius có default; auth tái sử dụng thay duplicate blur/
  background/radius/shadow declarations. Không thêm generic wrapper/framework.
- Auth background palette cũ hợp nhất thành một token; fieldHint/44pt target chung.
- Field/button/feedback giữ binding và callback; bổ sung tên/state, hit region và
  Reduce Motion. Glyph18pt nằm trong target44pt, tránh phóng theo body text rất lớn.
- Login account prompt dùng AnyLayout để stack ở accessibility text, không nhân đôi UI.
- Không thêm cache/memoization/network/GPS/renderer changes. Không có perf claim chưa đo.
- Rủi ro: shared text lớn ảnh hưởng các consumer constrained; build tất cả, ghi rõ
  authenticated layouts chưa có screenshot/interaction QA.

## Project Structure

App: FTDesignSystem, FTTextField, GoogleSignInButton, FTFeedbackViews, LoginView,
RegisterView và paired vi/en resources. Batch B chỉ thêm name/44pt trong ChatView,
GroupDetailView, PlacesView, HistoryView. Không đổi ViewModel/Domain/Data/Core.
Tooling: AGENTS/AI_RULES/design-workflow.md, preset addenda/preamble và overlay QA
hiện có. Tests: Tests/DesignUI/project.yml, Tests/DesignUITests.swift và script riêng.
Ảnh/verification/study/progress ở cùng feature folder, không tạo hierarchy thứ hai.

## Approval & Verification Plan

Native setup checks + skill discovery/search; localization; scoped lint; Debug và
Release Simulator builds; native interaction/contrast tests và ảnh thực tế.
Dùng Simulator riêng iPhoneSE3/17ProMax với light/dark, normal/accessibility XXXL,
vi/en, empty-input validation và password visibility. Không gửi credentials hợp lệ.
Không coi source audit là visual QA của authenticated screens hoặc full VoiceOver.
Rollback chỉ các thay đổi batch; không auto commit/push/branch hoặc dọn dữ liệu user.

## Batch B — control semantics

Sau shared/auth QA, áp cùng44pt/name cho composer, copy invite, add place và history
back. Tái sử dụng key có sẵn, thêm bốn keypaired khi cần. Chỉ presentation modifiers;
callbacks/state/API/permissions giữ nguyên. Những màn này được source/build/lint
verify; visual/interaction QA cần fixture được phép, không suy diễn từ auth screenshots.

## Runtime follow-up — locale

Test chuyển ngôn ngữ có sẵn phát hiện chuỗi auth chưa đổi ngay khi chọn locale mới.
Dùng AppLocalizedText và environment locale hiện có, không ép `.id` để recreate form
và mất focus/state. Rerun nguyên test cũ để chứng minh email còn nguyên và preference
persist qua relaunch; không thay preference/session logic hoặc expected behavior.
