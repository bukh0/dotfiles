"""Run the dotfiles installer in a disposable checkout and HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

INSTALLER = Path(os.environ.get('REVIEW_INSTALL_SCRIPT', str(Path.home() / 'dotfiles/install.sh')))
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from harness import require_external_files
require_external_files(INSTALLER)

with tempfile.TemporaryDirectory(prefix='dotfiles-install-') as directory:
    root = Path(directory)
    repo = root / 'checkout with spaces'
    repo.mkdir()
    shutil.copyfile(INSTALLER, repo / 'install.sh')
    for name in ['hypr', 'quickshell', 'uwsm', '.config/hypr', '.config/btop', '.config/zsh',
                 '.scripts', '.themes/presets', 'dwm', 'slstatus']:
        (repo / name).mkdir(parents=True)
    for name in ['zsh/.zshrc', '.zshrc', '.zshenv', 'icons/default/index.theme',
                 'systemd/user/gtk-cursor-sync.service', '.config/example.conf']:
        path = repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(name)
    home = root / 'home'
    home.mkdir()
    config = root / 'custom config'
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config))
    def run(*args):
        return subprocess.run(['bash', str(repo / 'install.sh'), *args], env=env,
                              capture_output=True, text=True, timeout=10)
    result = run('--dry-run')
    assert result.returncode == 0, result.stderr
    assert not config.exists() and not list(home.iterdir()), 'dry run mutated files'
    assert run('--invalid').returncode == 2
    assert not config.exists()
    config.mkdir()
    (config / 'hypr').mkdir()
    (config / 'hypr/keep').write_text('original')
    (config / 'hypr.bak').write_text('previous backup')
    (config / 'btop').symlink_to('/missing/old-target')
    (home / '.scripts').symlink_to('/missing/scripts')
    result = run()
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert (config / 'hypr').resolve() == repo / 'hypr'
    assert (config / 'hypr.bak.1/keep').read_text() == 'original'
    assert (config / 'hypr.bak').read_text() == 'previous backup'
    assert (config / 'btop').resolve() == repo / '.config/btop'
    assert str((config / 'btop.bak').readlink()) == '/missing/old-target'
    assert (home / '.scripts').resolve() == repo / '.scripts'
    assert str((home / '.scripts.bak').readlink()) == '/missing/scripts'
    assert (home / '.zshrc').resolve() == repo / 'zsh/.zshrc'
    assert not (home / '.zshenv').exists() and not (config / 'zsh').exists()
    assert (config / 'systemd/user/gtk-cursor-sync.service').resolve() == repo / 'systemd/user/gtk-cursor-sync.service'
    assert (home / '.icons/default/index.theme').resolve() == repo / 'icons/default/index.theme'
    assert (config / 'example.conf').resolve() == repo / '.config/example.conf'
    assert (home / 'dwm').resolve() == repo / 'dwm'
    before = sorted(str(p) for p in root.rglob('*'))
    assert run().returncode == 0
    assert sorted(str(p) for p in root.rglob('*')) == before, 'second install created extra backups'
    print('PASS current layout precedence, legacy fallback, custom XDG path, spaces, dry run, backups and repeated installs')

    # An empty checkout must not create links to literal unmatched glob paths.
    empty = root / 'empty'
    empty.mkdir()
    shutil.copyfile(INSTALLER, empty / 'install.sh')
    empty_home = root / 'empty-home'
    empty_home.mkdir()
    result = subprocess.run(['bash', str(empty / 'install.sh')],
                            env=dict(env, HOME=str(empty_home), XDG_CONFIG_HOME=str(empty_home / '.config')),
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stderr
    assert not list(empty_home.iterdir())
    print('PASS empty and partial checkouts skip missing sources')
