# Circle Members Response

Status: Implemented (device verification pending)

## Objective

Display circle members when the deployed `GET /groups/{id}/members` response omits `data.groupId`, and make load failures recoverable in the detail sheet.

## Inputs / Outputs

- Input: documented response with `groupId`, deployed response without `groupId`, network/decode failure, sheet dismissal.
- Output: decoded `[User]`, visible retry state on failure, no stale members from another circle.

## Modeled State

- `GroupMembersDTO.groupId` is optional because the client does not use it.
- Circle ViewModel owns members, loading/error state, and request generation.
- Circles Coordinator owns the sheet and the member-load task lifecycle.

## Architecture Path

`GroupDetailView -> CirclesCoordinator -> CircleListViewModel -> FetchCircleMembersUseCase -> CircleRepositoryImpl -> APIClient`

## Edge Cases / Verification

- A 200 response without `groupId` must decode and preserve all members.
- A late response from an older sheet/request must not replace current members.
- Failure must show an inline retry action; cancellation must not show an error.
- Run networking contract tests, localization checks, and unsigned Simulator build.
