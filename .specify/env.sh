#!/usr/bin/env bash
# Source before Spec Kit shell helpers. Keep tooling outside the iOS repository.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    printf '%s\n' 'Spec Kit needs uv. See .specify/README.md for installation.' >&2
    return 1 2>/dev/null || exit 1
fi
_specify_tools_dir="$(uv tool dir)" || { return 1 2>/dev/null || exit 1; }
export SPECKIT_PYTHON_EXECUTABLE="$_specify_tools_dir/specify-cli/bin/python"
unset _specify_tools_dir
if ! "$SPECKIT_PYTHON_EXECUTABLE" -c 'import yaml' >/dev/null 2>&1; then
    printf '%s\n' 'Install the pinned specify-cli tool first; its interpreter must include PyYAML.' >&2
    return 1 2>/dev/null || exit 1
fi
