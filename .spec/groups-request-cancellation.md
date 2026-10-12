# Groups Request Cancellation

## Objective

Keep a manual `/groups` refresh alive even if SwiftUI cancels its `.refreshable` task, and do not show an error for genuine cancellation.

## Input / Output

- Input: initial view load or pull-to-refresh, possibly overlapping.
- Output: one in-flight group fetch shared by callers; no user-facing error for genuine cancellation.

## State and Boundaries

- Keep network cancellation propagation in `APIClient` and repository layers.
- Circle ViewModel owns a short-lived unstructured group-load task, independently of SwiftUI's refresh task. Places and Journey ViewModels retain their existing loading flow and ignore cancellation alerts.
- Do not change token refresh, backend URLs, or navigation.

## Edge Cases / Verification

- Pull-to-refresh on the existing group list must complete even if SwiftUI cancels the awaiting refresh task.
- Switching tabs during a slow groups request must not show an error alert on return.
- Overlapping initial/manual loads must use a single request.
- A genuine network or server failure must still populate the existing error state.
- Verify with an unsigned iOS Simulator build and `git diff --check`; manually inspect Pulse and the UI on a device with throttled network.
