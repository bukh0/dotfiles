"""Desktop helpers with fake commands: no audio, compositor or power changes."""
from pathlib import Path
import os, shutil, subprocess, tempfile
SCRIPTS=Path(os.environ.get('REVIEW_SCRIPTS_DIR', str(Path.home()/'.scripts')))
with tempfile.TemporaryDirectory(prefix='qs-desktop-controls-') as directory:
 root=Path(directory);home=root/'home';home.mkdir();bins=root/'bin';bins.mkdir()
 scripts=home/'.scripts';scripts.mkdir();cache=home/'.cache';cache.mkdir();config=home/'.config';config.mkdir()
 env=dict(os.environ,HOME=str(home),XDG_CACHE_HOME=str(cache),XDG_CONFIG_HOME=str(config),XDG_RUNTIME_DIR=str(root),PATH=str(bins)+':'+os.environ['PATH'],TEST_ROOT=str(root))
 log=root/'log'
 def mock(name,body):
  p=bins/name;p.write_text('#!/bin/bash\n'+body+'\n');p.chmod(0o755)
 def run(name,ok=True,extra=None):
  result=subprocess.run(['/bin/bash',str(SCRIPTS/name)],env=env| (extra or {}),text=True,capture_output=True,timeout=5)
  assert (result.returncode==0)==ok,(name,result)
  return result
 def lines(): return log.read_text().splitlines() if log.exists() else []
 mock('notify-send','exit 0')
 mock('sudo','cat >/dev/null; exit 0')
 mock('swayosd-client','echo "osd $*" >> "$TEST_ROOT/log"')
 mock('wpctl','''echo "wpctl $*" >> "$TEST_ROOT/log"
if [[ "$1" == set-mute ]]; then printf 'Volume: 0.5 [MUTED]\\n' > "$TEST_ROOT/volume"; else cat "$TEST_ROOT/volume"; fi''')
 run('audio-mute-toggle.sh')
 assert lines()[:3]==['wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle','wpctl get-volume @DEFAULT_AUDIO_SINK@','osd --custom-message Muted --custom-icon audio-volume-muted'],lines()
 # Missing wpctl must abort before OSD, with no dependence on LED tools.
 log.unlink();(bins/'wpctl').unlink()
 run('audio-mute-toggle.sh',False,{'PATH':str(bins)})
 run('mic-toggle.sh',False,{'PATH':str(bins)})
 assert not log.exists()
 mock('wpctl','if [[ "$1" == get-volume ]]; then echo "Volume: 0.5 [MUTED]"; fi')
 run('mic-toggle.sh',extra={'PATH':str(bins)})
 assert lines()==['osd --custom-message Mic Muted --custom-icon microphone-sensitivity-muted']
 log.unlink()
 print('PASS synchronous audio mute, dependency guards, optional microphone LED')
 mock('hyprctl','''if [[ "$1" == getoption ]]; then cat "$TEST_ROOT/blur"; else echo "$*" >> "$TEST_ROOT/log"; fi''')
 for value,expected in [('{"bool":false}','true'),('{"bool":true}','false'),('{"int":0}','true'),('{"int":1}','false')]:
  (root/'blur').write_text(value);run('toggle.blur.sh');assert f'enabled = {expected}' in lines()[-1]
 print('PASS blur boolean and integer representations')
 anim=config/'hypr/animations';anim.mkdir(parents=True);(anim/'Smooth.lua').touch()
 mock('rofi','cat >/dev/null; echo "${PICK:-Smooth}"')
 run('animation.switcher.sh')
 assert (anim/'current_animations.lua').resolve()==anim/'Smooth.lua'
 assert (config/'hypr/animations.lua').resolve()==anim/'Smooth.lua'
 run('animation.switcher.sh',False,{'PICK':'Missing'})
 assert (config/'hypr/animations.lua').resolve()==anim/'Smooth.lua'
 print('PASS both animation links and invalid selection rejection')
 shutil.copyfile(Path.home()/'.scripts/quickshell-common.sh',scripts/'quickshell-common.sh')
 mock('quickshell','echo "$*" >> "$TEST_ROOT/qs-log"')
 run('toggle_waybar.sh')
 assert (root/'qs-log').read_text().splitlines()[-1].endswith('call bar toggle')
 mock('hyprctl','echo "$*" >> "$TEST_ROOT/hyprctl-log"')
 run('fullscreen_toggle.sh')
 assert (root/'hyprctl-log').read_text().splitlines()[-1] == 'dispatch fullscreen'
 print('PASS selected Quickshell routing and fullscreen dispatch')
 # Substitute only hardware paths; execute the actual transaction and error branches.
 perf=root/'perf.sh'
 source=(SCRIPTS/'toggle-performance.sh').read_text()
 for name,file in [('GPU_PERF','gpu-level'),('GPU_PROFILE','gpu-profile')]:
  import re
  (root/file).write_text('old')
  source=re.sub(r'^'+name+r'=.*$',name+'="'+str(root/file)+'"',source,flags=re.M)
 perf.write_text(source)
 mock('sudo','''if [[ "$1" == auto-cpufreq ]]; then
 [[ "${FAIL_CPU:-0}" == 0 ]] || exit 1
 echo "$2" > "$TEST_ROOT/cpu"
else
 cat > "$TEST_ROOT/gpu-write"
 [[ "${FAIL_GPU:-0}" == 0 ]] || exit 1
fi''')
 state=cache/'perf-mode'
 for fail_cpu,fail_gpu,expected in [('1','0','auto'),('0','1','performance'),('0','0','performance')]:
  state.write_text('auto\n')
  result=subprocess.run(['/bin/bash',str(perf)],env=env|{'FAIL_CPU':fail_cpu,'FAIL_GPU':fail_gpu},capture_output=True,text=True,timeout=5)
  assert state.read_text().strip()==expected,(result,state.read_text())
  assert (result.returncode==0)==(fail_cpu==fail_gpu=='0'),result
 print('PASS CPU failure preserves state; GPU failure preserves applied CPU state')
 mock('curl','echo "$*" > "$TEST_ROOT/curl-log"; echo sunny')
 # Clear inherited optional location so the missing-file branch is deterministic.
 env['WEATHER_LOCATION']=''
 assert run('weather.sh').stdout.strip()=='󰼯 N/A'
 (config/'weather-location').write_text('TestCity\n');run('weather.sh')
 assert 'https://wttr.in/TestCity?format=%c%t' in (root/'curl-log').read_text()
 run('weather.sh',extra={'WEATHER_LOCATION':'OtherCity'})
 assert 'https://wttr.in/OtherCity?format=%c%t' in (root/'curl-log').read_text()
 print('PASS weather location file and environment override')
