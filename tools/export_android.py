#!/usr/bin/env python3
"""Build a signed test APK using dependencies stored entirely in this project."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import struct
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile
import zlib

ROOT = Path(__file__).resolve().parent.parent
TOOLCHAIN = ROOT / 'tools/android'
CACHE = ROOT / '.local/android-build'
GODOT = ROOT / 'tools/Godot.app/Contents/MacOS/Godot'
SETTINGS = ROOT / 'tools/editor_data/editor_settings-4.7.tres'
SDK = TOOLCHAIN / 'sdk'
TEMPLATE = TOOLCHAIN / 'android_release.apk'
KEYSTORE = TOOLCHAIN / 'test.keystore'
OUTPUT = ROOT / 'build/android/crimson-front-test.apk'
CMDLINE_URL = 'https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip'


def request(url, headers=None):
    request_headers = {'User-Agent': 'CrimsonFrontBuild/1.0', 'Accept': '*/*'}
    request_headers.update(headers or {})
    return urllib.request.urlopen(urllib.request.Request(url, headers=request_headers), timeout=45)


def download(url, destination, checksum=None):
    if destination.exists():
        if not checksum or hashlib.sha256(destination.read_bytes()).hexdigest() == checksum:
            return destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    print('下载：' + url, flush=True)
    temporary = destination.with_name(destination.name + '.part')
    with request(url) as response, temporary.open('wb') as target:
        shutil.copyfileobj(response, target)
    if checksum and hashlib.sha256(temporary.read_bytes()).hexdigest() != checksum:
        temporary.unlink()
        raise RuntimeError('下载校验失败：' + str(destination))
    temporary.replace(destination)
    return destination


def java_home():
    return next(TOOLCHAIN.glob('jdk/*/Contents/Home'), TOOLCHAIN / 'jdk/missing/Contents/Home')


def install_java():
    if (java_home() / 'bin/keytool').exists():
        return
    arch = 'aarch64' if platform.machine() == 'arm64' else 'x64'
    url = 'https://api.adoptium.net/v3/assets/latest/17/hotspot?os=mac&architecture=' + arch + '&image_type=jdk'
    with request(url) as response:
        package = json.load(response)[0]['binary']['package']
    archive = download(package['link'], CACHE / package['name'], package['checksum'])
    folder = TOOLCHAIN / 'jdk'
    folder.mkdir(parents=True, exist_ok=True)
    subprocess.run(['tar', '-xzf', str(archive), '-C', str(folder)], check=True)


def environment():
    env = dict(os.environ)
    env['JAVA_HOME'] = str(java_home())
    env['PATH'] = str(java_home() / 'bin') + os.pathsep + env.get('PATH', '')
    env['ANDROID_HOME'] = str(SDK)
    env['ANDROID_USER_HOME'] = str(CACHE / 'android-user')
    env['ANDROID_SDK_HOME'] = str(CACHE)
    env['GRADLE_USER_HOME'] = str(CACHE / 'gradle')
    env['TMPDIR'] = str(CACHE / 'tmp')
    Path(env['TMPDIR']).mkdir(parents=True, exist_ok=True)
    Path(env['ANDROID_USER_HOME']).mkdir(parents=True, exist_ok=True)
    return env


def install_sdk(env):
    signer = SDK / 'build-tools/35.0.1/apksigner'
    if signer.exists() and (SDK / 'platform-tools/adb').exists():
        return
    manager = SDK / 'cmdline-tools/12.0/bin/sdkmanager'
    if not manager.exists():
        # Official archive checksum; retain a fixed JDK 17 compatible tool version.
        archive = download(CMDLINE_URL, CACHE / 'commandlinetools.zip',
                           '7bc5c72ba0275c80a8f19684fb92793b83a6b5c94d4d179fc5988930282d7e64')
        folder = SDK / 'cmdline-tools/12.0'
        folder.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as source:
            for entry in source.infolist():
                relative = Path(entry.filename).relative_to('cmdline-tools')
                if '..' in relative.parts:
                    raise RuntimeError('SDK 压缩包包含非法路径')
                target = folder / relative
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read(entry))
                target.chmod((entry.external_attr >> 16 & 0o777) or 0o644)
        manager.chmod(0o755)
    print('安装项目内 Android SDK；首次运行时请按 SDK 提示阅读并接受许可。', flush=True)
    subprocess.run([str(manager), '--sdk_root=' + str(SDK), 'platform-tools',
                    'build-tools;35.0.1', 'platforms;android-35'], env=env, check=True)
    if not signer.exists() or not (SDK / 'platform-tools/adb').exists():
        raise RuntimeError('Android SDK 未安装完成，请确认 SDK 许可后重试。')


def install_template():
    if TEMPLATE.exists():
        return
    # Read only the Android release entry from the official template ZIP.
    with request('https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable') as response:
        release = json.load(response)
    asset = next(a for a in release['assets'] if a['name'].endswith('stable_export_templates.tpz'))
    url, size = asset['browser_download_url'], asset['size']

    def get(first, last):
        with request(url, {'Range': 'bytes=%d-%d' % (first, last)}) as response:
            if response.status != 206:
                raise RuntimeError('模板下载服务器不支持分段下载。')
            return response.read()

    print('下载 Godot 4.7.2 Android 导出模板…', flush=True)
    tail = get(size - 100000, size - 1)
    offset = tail.rfind(b'PK\x05\x06')
    if offset < 0:
        raise RuntimeError('导出模板 ZIP 目录缺失。')
    eocd = struct.unpack('<4s4H2IH', tail[offset:offset + 22])
    central = get(eocd[6], eocd[6] + eocd[5] - 1)
    with zipfile.ZipFile(io.BytesIO(central + tail[offset:])) as source:
        entry = next(i for i in source.infolist() if Path(i.filename).name == 'android_release.apk')
        start = entry.header_offset + eocd[6]
        header = struct.unpack('<4s5H3I2H', get(start, start + 29))
        start += 30 + header[-2] + header[-1]
        compressed = get(start, start + entry.compress_size - 1)
        data = zlib.decompress(compressed, -15) if entry.compress_type == 8 else compressed
        if len(data) != entry.file_size or zlib.crc32(data) != entry.CRC:
            raise RuntimeError('Android 模板完整性校验失败。')
    TEMPLATE.parent.mkdir(parents=True, exist_ok=True)
    temporary = TEMPLATE.with_suffix('.part')
    temporary.write_bytes(data)
    temporary.replace(TEMPLATE)


def configure_editor():
    # The bundled editor already runs in self-contained mode inside tools/.
    if not (GODOT.parent / '_sc_').exists() or not SETTINGS.exists():
        raise RuntimeError('需要项目自带的独立 Godot 编辑器配置，以避免写入系统配置。')
    text = SETTINGS.read_text()
    values = {'export/android/java_sdk_path': str(java_home()),
              'export/android/android_sdk_path': str(SDK)}
    for key, value in values.items():
        pattern = '^' + re.escape(key) + r' = .*?$'
        line = key + ' = ' + json.dumps(value, ensure_ascii=False)
        if not re.search(pattern, text, re.MULTILINE):
            raise RuntimeError('项目内 Godot 配置缺少：' + key)
        text = re.sub(pattern, lambda _: line, text, flags=re.MULTILINE)
    SETTINGS.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='仅检查本地依赖，不下载、不打包')
    args = parser.parse_args()
    if platform.system() != 'Darwin' or not GODOT.exists():
        raise RuntimeError('请在 macOS 上使用本项目自带的 Godot。')
    dependencies = {'Java 17': java_home() / 'bin/keytool',
                    'Android SDK 签名工具': SDK / 'build-tools/35.0.1/apksigner',
                    'Android SDK 平台工具': SDK / 'platform-tools/adb',
                    'Godot Android 导出模板': TEMPLATE}
    if args.check:
        for title, path in dependencies.items():
            print(('已就绪：' if path.exists() else '缺少：') + title + ' · ' + str(path))
        return 0 if all(p.exists() for p in dependencies.values()) else 1
    install_java()
    env = environment()
    install_sdk(env)
    install_template()
    configure_editor()
    if not KEYSTORE.exists():
        subprocess.run([str(java_home() / 'bin/keytool'), '-genkeypair', '-noprompt',
                        '-keystore', str(KEYSTORE), '-alias', 'androiddebugkey',
                        '-storepass', 'android', '-keypass', 'android', '-keyalg', 'RSA',
                        '-keysize', '2048', '-validity', '10000',
                        '-dname', 'CN=Crimson Front Test,O=Crimson Front,C=CN'], env=env, check=True)
        KEYSTORE.chmod(0o600)
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(KEYSTORE)
    env['GODOT_ANDROID_KEYSTORE_RELEASE_USER'] = 'androiddebugkey'
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD'] = 'android'
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    candidate = OUTPUT.with_name('crimson-front-test-building.apk')
    candidate.unlink(missing_ok=True)
    subprocess.run([str(GODOT), '--headless', '--path', str(ROOT), '--log-file',
                    str(CACHE / 'export.log'), '--export-release', 'Android Test', str(candidate)],
                   cwd=ROOT, env=env, check=True)
    if not candidate.exists():
        raise RuntimeError('Godot 未生成 APK，请检查 .local/android-build/export.log。')
    subprocess.run([str(SDK / 'build-tools/35.0.1/apksigner'), 'verify', '--verbose',
                    str(candidate)], env=env, check=True)
    with zipfile.ZipFile(candidate) as apk:
        names = set(apk.namelist())
        if not {'AndroidManifest.xml', 'classes.dex', 'assets/project.binary',
                'lib/arm64-v8a/libgodot_android.so',
                'lib/armeabi-v7a/libgodot_android.so'} <= names:
            raise RuntimeError('APK 缺少游戏资源或 ARM 运行库。')
    candidate.replace(OUTPUT)
    candidate.with_suffix('.apk.idsig').unlink(missing_ok=True)
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    OUTPUT.with_suffix('.apk.sha256').write_text(digest + '  ' + OUTPUT.name + '\n')
    print('\nAPK 已生成并通过签名验证：\n%s\n大小：%.1f MB' % (OUTPUT, OUTPUT.stat().st_size / 1048576))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, StopIteration, subprocess.CalledProcessError,
            urllib.error.URLError, zipfile.BadZipFile) as error:
        print('APK 打包失败：' + str(error), file=sys.stderr)
        print('首次打包需要联网下载项目内依赖；重试：./export_android.command', file=sys.stderr)
        sys.exit(1)
