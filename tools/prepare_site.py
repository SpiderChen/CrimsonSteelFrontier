"""Create a static hosting bundle; stream-decompress WASM to keep assets below 25 MB."""
import gzip,pathlib,shutil
root=pathlib.Path(__file__).resolve().parent.parent
src=root/'build/web'; dest=root/'publish/dist';dest.mkdir(parents=True,exist_ok=True)
for p in src.iterdir():
 if p.is_file() and p.suffix not in ('.wasm','.gz'): shutil.copy2(p,dest/p.name)
(dest/'index.wasm.gz').write_bytes(gzip.compress((src/'index.wasm').read_bytes(),compresslevel=9,mtime=0))
shell=dest/'index.html'
s=shell.read_text()
shim='''<script>
// Keep the engine unchanged: provide its WASM as a standard decompressed response.
const originalFetch = window.fetch.bind(window);
window.fetch = async function(input, init) {
  const address = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  if (new URL(address, location.href).pathname.endsWith('/index.wasm')) {
    const response = await originalFetch(address + '.gz', init);
    if (!response.ok) throw new Error('引擎加载失败，请刷新重试。');
    return new Response(response.body.pipeThrough(new DecompressionStream('gzip')), {
      headers: {'Content-Type': 'application/wasm'}
    });
  }
  return originalFetch(input, init);
};
</script>'''
s=s.replace('<script src="index.js"></script>',shim+'\n<script src="index.js"></script>')
shell.write_text(s)
print('Prepared publish/dist:',sum(p.stat().st_size for p in dest.iterdir()),'bytes')
