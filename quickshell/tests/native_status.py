"""Exercise native status subscriptions without launching legacy transports."""
import os
from pathlib import Path
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='qs-native-status-') as directory:
    p = Path(directory)
    (p/'transport').mkdir()
    (p/'transport/qmldir').write_text('\n'.join('singleton '+n+' 1.0 '+n+'.qml' for n in ['Networking','Bluetooth','DeviceType']))
    (p/'transport/DeviceType.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { enum Type { Wifi, Wired } }')
    (p/'transport/Networking.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool wifiEnabled: true
 property bool wifiHardwareEnabled: true
 property var devices: ({values: [wifi]})
 property QtObject wifi: QtObject {
  property int type: DeviceType.Wifi
  property bool connected: true
  property string name: "wlan-test"
  property var networks: ({values: [network]})
 }
 property QtObject network: QtObject {
  property bool connected: true
  property string name: "Test wifi"
  property real signalStrength: 0.71
 }
}
''')
    (p/'transport/Bluetooth.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property var adapters: ({values: [adapter]})
 property var devices: ({values: []})
 property QtObject adapter: QtObject { property string dbusPath: "/org/bluez/hci0"; property bool enabled: true }
}
''')
    for name,module in [('NetworkService','Networking'),('BluetoothService','Bluetooth')]:
        source=(ROOT/'components'/f'{name}.qml').read_text().replace(f'import Quickshell.{module} as Native','import "transport" as Native')
        (p/f'{name}.qml').write_text(source)
    (p/'qmldir').write_text('singleton NetworkService 1.0 NetworkService.qml\nsingleton BluetoothService 1.0 BluetoothService.qml\n')
    (p/'profile').symlink_to(ROOT/'profiles/default',target_is_directory=True)
    (p/'shell.qml').write_text('''import QtQuick
import Quickshell
import "."
import "transport" as Native
import "profile" as Profile
ShellRoot {
 property int step: 0
 function check(ok, message) { if (!ok) throw new Error(message) }
 Timer { interval: 100; repeat: true; running: true
 onTriggered: {
  try {
   switch (step++) {
   case 0:
    check(NetworkService.nativeStatusEnabled && BluetoothService.nativeStatusEnabled, "native enabled")
    check(Profile.Theme.sysmonPath === "''' + str(p/'../../native/sysmon') + '''", "helper path " + Profile.Theme.sysmonPath)
    break
   case 1:
    check(NetworkService.ssid === "Test wifi" && NetworkService.signalStrength === 71, "initial wifi")
    check(BluetoothService.hasAdapter && BluetoothService.powered, "initial Bluetooth")
    Native.Networking.network.signalStrength = 0.25
    Native.Networking.network.name = "Renamed"
    Native.Bluetooth.adapter.enabled = false
    break
   case 2:
    check(NetworkService.signalStrength === 25 && NetworkService.ssid === "Renamed", "property updates")
    check(!BluetoothService.powered, "adapter toggle")
    Native.Networking.wifiHardwareEnabled = false
    NetworkService.networks = [{ssid: "Renamed"}]
    NetworkService.awaitingPasswordFor = "Renamed"
    break
   case 3:
    check(!NetworkService.wifiOn && !NetworkService.networks.length && !NetworkService.awaitingPasswordFor, "radio-off cleanup")
    Native.Networking.devices = {values: []}; Native.Bluetooth.adapters = {values: []}
    break
   case 4:
    check(NetworkService.connectionType === "none" && !BluetoothService.hasAdapter, "device removal")
    console.log("NATIVE PASS"); Qt.quit()
   }
  } catch (error) { console.error("NATIVE FAIL", error); Qt.quit() }
 }
 }
}
''')
    # A legacy status/monitor launch is a failure; native snapshots need no commands.
    for name in ['nmcli','busctl','dbus-monitor']:
        f=p/name; f.write_text('#!/bin/sh\necho '+name+' >> "$TEST_CALLS"\n'); f.chmod(0o755)
    calls=p/'calls'
    r=subprocess.run(['quickshell','-p',str(p)],env=dict(os.environ,PATH=directory+':'+os.environ['PATH'],TEST_CALLS=str(calls),QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=directory),capture_output=True,text=True,timeout=8)
    output=r.stdout+r.stderr
    assert 'NATIVE PASS' in output and 'NATIVE FAIL' not in output,output
    assert not calls.exists(),calls.read_text()
    print('PASS native device/property updates, radio cleanup, shared helper path, no legacy status processes')
