const assert = require('node:assert/strict');
const {chromium} = require('../tools/browser/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
  });
  try {
    const context = await browser.newContext({viewport: {width: 390, height: 844}, isMobile: true, hasTouch: true});
    // Measure the actual Web Audio output, including Godot's streamed bus effects.
    await context.addInitScript(() => {
      window.audioProbe = {peak: 0, rms: 0, contexts: []};
      const connect = AudioNode.prototype.connect;
      AudioNode.prototype.connect = function (...args) {
        if (args[0] instanceof AudioDestinationNode) {
          const meter = this.context.createAnalyser();
          meter.fftSize = 2048;
          connect.call(meter, args[0]);
          args[0] = meter;
          window.audioProbe.contexts.push(this.context);
          const samples = new Float32Array(meter.fftSize);
          setInterval(() => {
            meter.getFloatTimeDomainData(samples);
            const rms = Math.sqrt(samples.reduce((sum, value) => sum + value * value, 0) / samples.length);
            window.audioProbe.rms = rms;
            window.audioProbe.peak = Math.max(window.audioProbe.peak, rms);
          }, 15);
        }
        return connect.apply(this, args);
      };
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) errors.push(message.text());
    });
    const scale = 390 / 720, offset = (844 - 1280 * scale) / 2;
    const tap = async (x, y) => {
      await page.touchscreen.tap(x * scale, y * scale + offset);
      await page.waitForTimeout(500);
    };
    const resetPeak = () => page.evaluate(() => {window.audioProbe.peak = 0;});
    const read = () => page.evaluate(() => ({peak: audioProbe.peak, rms: audioProbe.rms, states: audioProbe.contexts.map(c => c.state)}));
    const readSound = () => page.evaluate(async () => {
      for (const entry of await indexedDB.databases()) {
        const db = await new Promise(resolve => {const r = indexedDB.open(entry.name); r.onsuccess = () => resolve(r.result);});
        for (const name of db.objectStoreNames) {
          const rows = await new Promise(resolve => {const r = db.transaction(name).objectStore(name).getAll(); r.onsuccess = () => resolve(r.result);});
          for (const row of rows) if (row.contents) {
            try {const data = JSON.parse(new TextDecoder().decode(row.contents)); if (data.levels) return data.sound;} catch {}
          }
        }
        db.close();
      }
      return null;
    });
    const waitSound = async expected => {
      for (let i = 0; i < 40; i++) {
        if (await readSound() === expected) return;
        await page.waitForTimeout(200);
      }
      assert.fail('sound toggle did not persist ' + expected);
    };
    await page.goto(process.env.GAME_URL || 'http://localhost:8060');
    await page.waitForFunction(() => !document.querySelector('#status'), null, {timeout: 120000});
    await page.waitForTimeout(1200);
    assert.equal((await read()).peak, 0, 'no audio before user activation');
    await tap(610, 74); // Skip opening story in this isolated profile.
    await tap(596, 54); // Help opens without loading a new scene.
    await page.waitForFunction(() => audioProbe.peak > 0.00001, null, {timeout: 5000});
    const audible = await read();
    assert(audible.states.includes('running'), 'user interaction unlocks a running audio context');
    await tap(624, 317); // Close help.
    await tap(667, 54); // Global mute also stops current tails.
    await waitSound(false);
    await page.waitForTimeout(350);
    await resetPeak();
    await tap(596, 54);
    await page.waitForTimeout(700);
    assert((await read()).peak < 0.000001, 'muted interactions produce silence at the audio output');
    await tap(624, 317);
    await tap(667, 54); // Re-enable.
    await waitSound(true);
    await resetPeak();
    await tap(596, 54);
    await page.waitForFunction(() => audioProbe.peak > 0.00001, null, {timeout: 5000});
    assert.deepEqual(errors, [], 'Web mixer runs without browser or Godot errors');
    console.log('AUDIO BROWSER PASS: activation, real streamed output, mute silence and unmute; peak RMS', audible.peak);
  } finally {
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
