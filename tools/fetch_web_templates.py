"""Fetch only single-thread Web templates from the official release ZIP via HTTP ranges."""
import io, json, struct, urllib.request, zipfile, pathlib, zlib
release = json.load(urllib.request.urlopen('https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable'))
asset = next(a for a in release['assets'] if a['name'].endswith('stable_export_templates.tpz'))
url, size = asset['browser_download_url'], asset['size']
def get(a,b):
    req=urllib.request.Request(url,headers={'Range':f'bytes={a}-{b}'})
    with urllib.request.urlopen(req) as r:
        if r.status != 206: raise RuntimeError(f'Range unsupported: {r.status}')
        return r.read()
tail=get(size-100000,size-1)
p=tail.rfind(b'PK\x05\x06')
eocd=struct.unpack('<4s4H2IH',tail[p:p+22])
cd=get(eocd[6],eocd[6]+eocd[5]-1)
# Feed central directory and EOCD to ZipFile; offsets stay accessible from the records.
z=zipfile.ZipFile(io.BytesIO(cd+tail[p:]))
out=pathlib.Path('tools/web_templates');out.mkdir(exist_ok=True)
for info in z.infolist():
    if info.filename.split('/')[-1] not in ('web_nothreads_debug.zip','web_nothreads_release.zip'): continue
    # ZipFile compensates offsets for truncated archive; restore original local-header offset.
    offset=info.header_offset+eocd[6]
    header=get(offset,offset+29)
    fields=struct.unpack('<4s5H3I2H',header)
    start=offset+30+fields[-2]+fields[-1]
    raw=get(start,start+info.compress_size-1)
    data=zlib.decompress(raw,-15) if info.compress_type==8 else raw
    assert len(data)==info.file_size and zlib.crc32(data)==info.CRC
    target=out/pathlib.Path(info.filename).name;target.write_bytes(data)
    print(target,len(data),flush=True)
