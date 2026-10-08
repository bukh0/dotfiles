import os,subprocess,tempfile,time,json
from pathlib import Path
from PIL import Image
BINARY=os.environ.get('THEME_TEST_BINARY', str(Path.home()/'.scripts/theme.switcher'))
def call(args,env,ok=True):
 r=subprocess.run([BINARY,*args],env=env,text=True,capture_output=True,timeout=60)
 if ok: assert r.returncode==0,(args,r.returncode,r.stderr)
 return r
def mock(p,text):
 p.write_text('#!/usr/bin/env python3\n'+text);p.chmod(0o755)
with tempfile.TemporaryDirectory(prefix='theme-tests-') as d:
 root=Path(d); walls=root/'Pictures/Wallpapers';walls.mkdir(parents=True)
 cache=root/'cache';config=root/'config';bins=root/'bin';bins.mkdir()
 env=dict(os.environ,HOME=d,XDG_CACHE_HOME=str(cache),XDG_CONFIG_HOME=str(config),PATH=str(bins)+os.pathsep+os.environ['PATH'])
 # Real libvips: long names, source changes, tie ordering, no-op cache hits.
 for name in ['b.png','a.png','long-'+'x'*230+'.png']:
  Image.new('RGB',(800,450),'red').save(walls/name)
  os.utime(walls/name,ns=(1000000000,1000000000))
 listing=call(['--list-walls'],env).stdout.splitlines()
 assert [Path(x.split('\t')[0]).name for x in listing]==sorted(p.name for p in walls.iterdir())
 assert all(len(Path(x.split('\t')[1]).name)==68 for x in listing)
 r=call(['--thumbs'],env);assert len(r.stdout.splitlines())==3
 assert not call(['--thumbs'],env).stdout
 stale=Path(listing[0].split('\t')[1]);partial=stale.parent/'abandoned.part';partial.touch()
 os.utime(walls/'a.png',ns=(1000000001,1000000001))
 assert len(call(['--thumbs'],env).stdout.splitlines())==1
 assert not stale.exists() and not partial.exists()
 print('PASS real libvips, hash size, deterministic sorting, nanosecond invalidation, pruning and warm-cache no-op',flush=True)
 # More than 128 KiB of paths, with a cheap mock thumbnailer.
 mock(bins/'vipsthumbnail','''import pathlib,sys
p=sys.argv[sys.argv.index('--path')+1].split('[')[0]
pathlib.Path(p).write_bytes(b'jpeg fixture')
''')
 for i in range(1600): (walls/(f'{i:04}-'+'x'*100+'.png')).write_bytes(b'fixture')
 assert sum(len(str(p)) for p in walls.iterdir()) > 131072
 r=call(['--thumbs'],env);assert len(r.stdout.splitlines())==1600
 assert not call(['--thumbs'],env).stdout
 print('PASS 1600-thumbnail queue exceeds old single-argument limit',flush=True)
 # Installation uses one route table, preserves target symlinks/mode, serializes generation.
 generated=config/'hypr/themes/matugen/generated';generated.mkdir(parents=True)
 for n in ['rofi.rasi','kitty.conf','waybar.css','gtk-3.css','swaync.css','hyprlock.conf','wlogout.css','quickshell-colors.qml']:(generated/n).write_text('new '+n)
 target=root/'real-colors';target.write_text('old');target.chmod(0o640)
 (config/'rofi').mkdir();(config/'rofi/colors.rasi').symlink_to(target)
 scripts=root/'.scripts';scripts.mkdir();(scripts/'quickshell-common.sh').write_text('quickshell_running() { return 1; }\n')
 for n in ['pkill','notify-send','swaync-client','swww']:mock(bins/n,'raise SystemExit(0)\n')
 mock(bins/'pgrep','raise SystemExit(1)\n')
 mock(bins/'matugen','''import os,pathlib,time
p=pathlib.Path(os.environ['HOME'])/'generation-lock'
try: p.mkdir()
except FileExistsError: raise SystemExit(99)
time.sleep(.2)
p.rmdir()
''')
 procs=[subprocess.Popen([BINARY,'--apply','Matugen',str(walls/'a.png')],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE) for _ in range(2)]
 for p in procs:
  _,err=p.communicate(timeout=10);assert p.returncode==0,err
 assert (config/'rofi/colors.rasi').is_symlink() and target.read_text()=='new rofi.rasi'
 assert target.stat().st_mode & 0o777 == 0o640
 target.write_text('sentinel');(generated/'wlogout.css').unlink()
 assert call(['--install-matugen'],env,False).returncode!=0 and target.read_text()=='sentinel'
 (generated/'wlogout.css').write_text('restored output')
 # Make a later destination fail after the first file has been replaced.
 (config/'kitty/theme.conf').unlink()
 blocked=root/'blocked';blocked.mkdir();blocked.chmod(0o500)
 (config/'kitty/theme.conf').symlink_to(blocked/'theme.conf')
 try:
  assert call(['--install-matugen'],env,False).returncode != 0
  assert target.read_text() == 'sentinel', 'partial installation did not roll back'
  assert (config/'kitty/theme.conf').is_symlink()
 finally: blocked.chmod(0o700)
 print('PASS serialized generation, symlink/mode preservation, preflight and rollback',flush=True)
 # Pywal gets identical, bounded-size input whether the cache is cold or warm.
 mock(bins/'wal','''import os,pathlib,sys
root=pathlib.Path(os.environ['XDG_CACHE_HOME'])
source=sys.argv[sys.argv.index('-i')+1]
assert pathlib.Path(source).is_file() and '/wall-thumbs/v2/' in source
with (root/'wal-inputs').open('a') as f: f.write(source+'\\n')
out=root/'wal';out.mkdir(exist_ok=True)
for name in ['rofi.rasi','kitty.conf','waybar.css','gtk.css','swaync.css','hyprlock.conf','wlogout.css','quickshell-colors.qml']:
 (out/name).write_text('pywal fixture')
''')
 wall=walls/'a.png'
 thumb=Path(next(line.split('\t')[1] for line in call(['--list-walls'],env).stdout.splitlines() if line.split('\t')[0]==str(wall)))
 thumb.unlink(missing_ok=True)
 call(['--apply','pywal',str(wall)],env)
 before=thumb.stat().st_mtime_ns
 call(['--apply','pywal',str(wall)],env)
 assert thumb.stat().st_mtime_ns==before
 inputs=(cache/'wal-inputs').read_text().splitlines()
 assert len(inputs)==2 and inputs[0]==inputs[1]==str(thumb)
 print('PASS Pywal uses the same small input on cold and warm caches',flush=True)
 # Curated image symlinks are selectable even when the image lives elsewhere.
 external=root/'external.png';external.write_bytes(wall.read_bytes())
 linked=walls/'linked.png';linked.symlink_to(external)
 assert str(linked)+'\t' in call(['--list-walls'],env).stdout
 for generator in ['Matugen','pywal']:
  call(['--apply',generator,str(linked)],env)
  rejected=call(['--apply',generator,str(external)],env,False)
  assert rejected.returncode != 0 and 'Invalid wallpaper path' in rejected.stderr
 print('PASS listed image symlinks work with both generators; direct outside paths remain rejected',flush=True)
 # Wallpaper failures must reach the picker after installed colours are reloaded.
 mock(bins/'swww',"import sys\nprint('mock wallpaper failure',file=sys.stderr)\nraise SystemExit(1)\n")
 mock(bins/'notify-send',"import os,pathlib\n(pathlib.Path(os.environ['HOME'])/'success-notice').touch()\n")
 failed=call(['--apply','Matugen',str(wall)],env,False)
 assert failed.returncode != 0 and 'mock wallpaper failure' in failed.stderr
 assert 'Theme colours were applied, but the wallpaper could not be set' in failed.stderr
 assert not (root/'success-notice').exists()
 print('PASS wallpaper failure returns an actionable error without a success notification',flush=True)
 # Theme application relies on the watched Colors.qml; never restart the bar.
 (scripts/'quickshell-common.sh').write_text('quickshell_running() { return 0; }\n')
 mock(scripts/'switch_quickshell.sh', "import pathlib,os\n(pathlib.Path(os.environ['HOME'])/'bar-restarted').touch()\nraise SystemExit(7)\n")
 mock(bins/'swww', 'raise SystemExit(0)\n')
 call(['--apply','Matugen',str(wall)],env)
 assert (root/'success-notice').exists()
 assert not (root/'bar-restarted').exists()
 print('PASS theme application does not restart the bar',flush=True)
