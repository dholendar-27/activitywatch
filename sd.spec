# -*- mode: python -*-
# vi: set ft=python :

import os
import platform
import shlex
import subprocess
from pathlib import Path

import sd_core
import flask_restx

current_release = subprocess.run(
    shlex.split("git describe --tags --abbrev=0"),
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    encoding="utf8",
).stdout.strip()
print("bundling Sundial version " + current_release)

entitlements_file = Path(".") / "scripts" / "package" / "entitlements.plist"
codesign_identity = os.environ.get("APPLE_PERSONALID", "").strip()
if not codesign_identity:
    print("Environment variable APPLE_PERSONALID not set. Releases won't be signed.")

sd_core_path = Path(os.path.dirname(sd_core.__file__))
restx_path = Path(os.path.dirname(flask_restx.__file__))

sds_location = Path("sd-server")
sd_qt_location = Path("sd-qt")
sda_location = Path("sd-watcher-afk")
sdw_location = Path("sd-watcher-window")

if platform.system() == "Darwin":
    icon = sd_qt_location / "media/logo/logo.icns"
else:
    icon = sd_qt_location / "media/logo/logo.ico"
block_cipher = None

extra_pathex = []
if platform.system() == "Windows":
    # The Windows version includes paths to Qt binaries which are
    # not automatically found due to bug in PyInstaller 3.2.
    # See: https://github.com/pyinstaller/pyinstaller/issues/2152
    import PyQt6

    pyqt_path = os.path.dirname(PyQt6.__file__)
    extra_pathex.append(pyqt_path + "\\Qt\\bin")

sd_server_a = Analysis(
    ["sd-server/__main__.py"],
    pathex=[],
    binaries=None,
    datas=[
        (sds_location / "sd_server/static", "sd_server/static"),
        (restx_path / "templates", "flask_restx/templates"),
        (restx_path / "static", "flask_restx/static"),
        (sd_core_path / "schemas", "sd_core/schemas"),
    ],
    hiddenimports=[],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)
dependent_datas = []

if platform.system() == "Windows":
    dependent_datas = [
        (os.path.join(spec_dir, "libcrypto-1_1-x64.dll"), '.'),
        (os.path.join(spec_dir, "sqlcipher.dll"), '.'),
    ]
elif platform.system() == "Darwin":
    dependent_datas = [
        ("libcrypto.3.dylib", '.'),
        ("libsqlcipher.0.dylib", '.'),
    ]

datas = [
    (sd_qt_location / "resources/sd-qt.desktop", "sd_qt/resources"),
    (sd_qt_location / "media", "sd_qt/media"),
]

datas += dependent_datas  # Combine datas and dependent_datas

sd_qt_a = Analysis(
    [sd_qt_location / "sd_qt/__main__.py"],
    pathex=[] + extra_pathex,
    binaries=None,
    datas=datas,
    hiddenimports=['PyQt6'],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)

sd_watcher_afk_a = Analysis(
    [sda_location / "sd_watcher_afk/__main__.py"],
    pathex=[],
    binaries=None,
    datas=None,
    hiddenimports=[
        "Xlib.keysymdef.miscellany",
        "Xlib.keysymdef.latin1",
        "Xlib.keysymdef.latin2",
        "Xlib.keysymdef.latin3",
        "Xlib.keysymdef.latin4",
        "Xlib.keysymdef.greek",
        "Xlib.support.unix_connect",
        "Xlib.ext.shape",
        "Xlib.ext.xinerama",
        "Xlib.ext.composite",
        "Xlib.ext.randr",
        "Xlib.ext.xfixes",
        "Xlib.ext.security",
        "Xlib.ext.xinput",
        "pynput.keyboard._xorg",
        "pynput.mouse._xorg",
        "pynput.keyboard._win32",
        "pynput.mouse._win32",
        "pynput.keyboard._darwin",
        "pynput.mouse._darwin",
    ],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)

sd_watcher_window_a = Analysis(
    [sdw_location / "sd_watcher_window/__main__.py"],
    pathex=[],
    binaries=[
        (
            sdw_location / "sd_watcher_window/sd-watcher-window-macos",
            "sd_watcher_window",
        )
    ]
    if platform.system() == "Darwin"
    else [],
    datas=[
        (sdw_location / "sd_watcher_window/printAppStatus.jxa", "sd_watcher_window")
    ],
    hiddenimports=[],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)

# https://pythonhosted.org/PyInstaller/spec-files.html#multipackage-bundles
# MERGE takes a bit weird arguments, it wants tuples which consists of
# the analysis paired with the script name and the bin name
MERGE(
    (sd_server_a, "sd-server", "sd-server"),
    (sd_qt_a, "sd-qt", "sd-qt"),
    (sd_watcher_afk_a, "sd-watcher-afk", "sd-watcher-afk"),
    (sd_watcher_window_a, "sd-watcher-window", "sd-watcher-window"),
)

sdw_pyz = PYZ(
    sd_watcher_window_a.pure, sd_watcher_window_a.zipped_data, cipher=block_cipher
)
sdw_exe = EXE(
    sdw_pyz,
    sd_watcher_window_a.scripts,
    exclude_binaries=True,
    name="sd-watcher-window",
    debug=False,
    strip=False,
    upx=True,
    console=True,
    entitlements_file=entitlements_file,
    codesign_identity=codesign_identity,
)
sdw_coll = COLLECT(
    sdw_exe,
    sd_watcher_window_a.binaries,
    sd_watcher_window_a.zipfiles,
    sd_watcher_window_a.datas,
    strip=False,
    upx=True,
    name="sd-watcher-window",
)

sda_pyz = PYZ(sd_watcher_afk_a.pure, sd_watcher_afk_a.zipped_data, cipher=block_cipher)
sda_exe = EXE(
    sda_pyz,
    sd_watcher_afk_a.scripts,
    exclude_binaries=True,
    name="sd-watcher-afk",
    debug=False,
    strip=False,
    upx=True,
    console=True,
    entitlements_file=entitlements_file,
    codesign_identity=codesign_identity,
)
sda_coll = COLLECT(
    sda_exe,
    sd_watcher_afk_a.binaries,
    sd_watcher_afk_a.zipfiles,
    sd_watcher_afk_a.datas,
    strip=False,
    upx=True,
    name="sd-watcher-afk",
)

sds_pyz = PYZ(sd_server_a.pure, sd_server_a.zipped_data, cipher=block_cipher)

sds_exe = EXE(
    sds_pyz,
    sd_server_a.scripts,
    exclude_binaries=True,
    name="sd-server",
    debug=False,
    strip=False,
    upx=True,
    console=True,
    entitlements_file=entitlements_file,
    codesign_identity=codesign_identity,
)
sds_coll = COLLECT(
    sds_exe,
    sd_server_a.binaries,
    sd_server_a.zipfiles,
    sd_server_a.datas,
    strip=False,
    upx=True,
    name="sd-server",
)

sdq_pyz = PYZ(sd_qt_a.pure, sd_qt_a.zipped_data, cipher=block_cipher)
sdq_exe = EXE(
    sdq_pyz,
    sd_qt_a.scripts,
    exclude_binaries=True,
    name="sd-qt",
    debug=True,
    strip=False,
    upx=True,
    icon=icon,
    console=False if platform.system() == "Windows" else True,
    entitlements_file=entitlements_file,
    codesign_identity=codesign_identity,
)
sdq_coll = COLLECT(
    sdq_exe,
    sd_qt_a.binaries,
    sd_qt_a.zipfiles,
    sd_qt_a.datas,
    strip=False,
    upx=True,
    name="sd-qt",
)

if platform.system() == "Darwin":
    app = BUNDLE(
        sdq_coll,
        sdw_coll,
        sda_coll,
        sds_coll,
        name="Sundial.app",
        icon=icon,
        bundle_identifier="net.ralvie.Sundial",
        version=current_release.lstrip("v"),
        info_plist={
            "NSPrincipalClass": "NSApplication",
            "CFBundleExecutable": "MacOS/sd-qt",
            "CFBundleIconFile": "logo.icns",
            "NSAppleEventsUsageDescription": "Please grant access to use Apple Events",
            # This could be set to a more specific version string (including the commit id, for example)
            "CFBundleVersion": current_release.lstrip("v"),
            # Replaced by the 'version' kwarg above
            # "CFBundleShortVersionString": current_release.lstrip('v'),
        },
    )
