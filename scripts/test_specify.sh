#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source .specify/env.sh
"$SPECKIT_PYTHON_EXECUTABLE" - <<'PY'
from pathlib import Path
import hashlib
import importlib.metadata
import json
import os
import shutil
import subprocess
import tempfile
import yaml

root = Path.cwd()
assert importlib.metadata.version('specify-cli') == '1.4.0'
cli = shutil.which('specify')
assert cli

def run(*args, cwd=root, env=None, check=True):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, stdin=subprocess.DEVNULL,
                            capture_output=True)
    if check and result.returncode:
        raise AssertionError(f'{args}: {result.stdout}\n{result.stderr}')
    return result

for p in (root/'.specify').rglob('*.json'):
    json.loads(p.read_text())
for p in (root/'.specify').rglob('*.sh'):
    run('bash', '-n', str(p))
assert json.loads((root/'.specify/integration.json').read_text())['default_integration'] == 'codex'
manifest = json.loads((root/'.specify/integrations/speckit.manifest.json').read_text())
for path, digest in manifest['files'].items():
    if path.startswith(('.specify/scripts/', '.specify/templates/')):
        assert hashlib.sha256((root/path).read_bytes()).hexdigest() == digest, path
print('PASS: pinned CLI, native core provenance, JSON/Bash and Codex integration')

source_preset = root/'.specify/mobile-preset'
installed_preset = root/'.specify/presets/familytracker-mobile'
for p in source_preset.rglob('*'):
    if p.is_file():
        assert p.read_bytes() == (installed_preset/p.relative_to(source_preset)).read_bytes(), p
for name, marker in [('spec-template', 'Backend API Dependencies'),
                     ('plan-template', 'Reusability & Optimization Analysis'),
                     ('tasks-template', 'FamilyTracker Task Rules')]:
    data = json.loads(run('bash', '.specify/scripts/bash/resolve-template.sh', name, '--json').stdout)
    content = data['TEMPLATE_CONTENT']
    assert marker in content and len(content) > len((source_preset/f'templates/{name}.md').read_text())
    assert 'strategy: append' not in content
skills = list((root/'.agents/skills').glob('speckit-*/SKILL.md'))
assert len(skills) == 9
for p in skills:
    text = p.read_text()
    front = yaml.safe_load(text.split('---', 2)[1])
    assert front['name'] == p.parent.name and front['description']
    assert '## User Input' in text and '$ARGUMENTS' in text, p
implement = (root/'.agents/skills/speckit-implement/SKILL.md').read_text()
assert implement.index('Mandatory FamilyTracker approval gate') < implement.index('## Outline')
specify = (root/'.agents/skills/speckit-specify/SKILL.md').read_text()
assert 'templates/overrides/scripts/create-new-feature.sh' in specify
print('PASS: native + mobile composition, 9 skills, explicit approval before implementation')

# Both CLI attribution and its resolved workflow must accept the real overlay.
resolved = run(cli, 'workflow', 'resolve', 'speckit').stdout
assert resolved.index('mobile-analysis:') < resolved.index('mobile-approval:') < resolved.index('implement:')
assert resolved.index('mobile-verification-documentation:') < resolved.index('mobile-convergence:')
print('PASS: native workflow resolves analysis -> human approval -> implement -> verification -> converge')

with tempfile.TemporaryDirectory(prefix='familytracker-specify-') as tmp:
    project = Path(tmp)/'Test Workspace'
    project.mkdir()
    shutil.copytree(root/'.specify', project/'.specify',
                    ignore=shutil.ignore_patterns('runs', '.cache'))
    (project/'.spec/001-example').mkdir(parents=True)
    (project/'.spec/012-existing').mkdir(parents=True)
    pointer = project/'.specify/feature.json'
    pointer.write_text('{"feature_directory":".spec/012-existing"}\n')
    initial_pointer = pointer.read_bytes()
    env = dict(os.environ, SPECIFY_INIT_DIR=str(project))
    env.pop('SPECIFY_FEATURE_DIRECTORY', None)
    env.pop('SPECIFY_FEATURE', None)
    env.pop('SPECIFY_FEATURE_NO_PERSIST', None)
    helper = str(project/'.specify/templates/overrides/scripts/create-new-feature.sh')
    dry = json.loads(run('bash', helper, '--json', '--dry-run', '--short-name', 'sample',
                         'Sample feature', cwd=project, env=env).stdout)
    assert dry['FEATURE_NUM'] == '013' and dry['DRY_RUN'] is True
    assert '/.spec/013-sample' in str(Path(dry['SPEC_FILE']).parent)
    assert not (project/'.spec/013-sample').exists() and pointer.read_bytes() == initial_pointer
    invalid = run('bash', helper, '--dry-run', '--short-name',
                  cwd=project, env=env, check=False)
    assert invalid.returncode != 0
    created = json.loads(run('bash', helper, '--json', '--short-name', 'sample', 'Sample feature',
                             cwd=project, env=env).stdout)
    feature = Path(created['SPEC_FILE']).parent
    assert feature == project/'.spec/013-sample'
    assert 'FamilyTracker Mobile Requirements' in (feature/'spec.md').read_text()
    assert not (project/'specs').exists() and not (project/'.git').exists()
    assert json.loads(pointer.read_text())['feature_directory'] == '.spec/013-sample'
    active_pointer = pointer.read_bytes()
    selected = dict(env, SPECIFY_FEATURE_DIRECTORY='.spec/013-sample', SPECIFY_FEATURE_NO_PERSIST='1')
    setup = str(project/'.specify/scripts/bash/setup-plan.sh')
    run('bash', setup, '--json', cwd=project, env=selected)
    plan = feature/'plan.md'
    assert 'Reusability & Optimization Analysis' in plan.read_text()
    plan.write_text('existing plan must survive\n')
    run('bash', setup, '--json', cwd=project, env=selected)
    assert plan.read_text() == 'existing plan must survive\n'
    other = dict(env, SPECIFY_FEATURE_DIRECTORY='.spec/012-existing', SPECIFY_FEATURE_NO_PERSIST='1')
    run('bash', str(project/'.specify/scripts/bash/check-prerequisites.sh'),
        '--paths-only', '--json', cwd=project, env=other)
    assert pointer.read_bytes() == active_pointer
    print('PASS: .spec numbering, read-only dry-run, missing argument, composed creation, safe plan and feature selection')

    # Exercise the real native gate with no agent invocation and only a harmless
    # marker after the gate. Non-interactive execution must pause before the marker.
    gate = {
        'schema_version': '1.0',
        'workflow': {'id': 'approval-smoke', 'name': 'Approval smoke', 'version': '1.0.0'},
        'steps': [
            {'id': 'human', 'type': 'gate', 'message': 'Synthetic test approval only',
             'options': ['approve', 'reject'], 'on_reject': 'abort'},
            {'id': 'after', 'type': 'shell', 'run': 'touch approved.marker'},
        ],
    }
    gate_path = project/'approval-smoke.yml'
    gate_path.write_text(yaml.safe_dump(gate))
    result = run(cli, 'workflow', 'run', str(gate_path), '--json', cwd=project,
                 env=env, check=False)
    assert not (project/'approved.marker').exists()
    assert 'paused' in result.stdout.lower(), result.stdout + result.stderr
    print('PASS: real native gate pauses without human approval; following shell step did not execute')

print('PASS: Spec Kit setup checks complete; no model, app build or device test was run')
PY
