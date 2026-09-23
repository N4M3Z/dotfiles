const assert = require("node:assert/strict");
const { test } = require("node:test");
const { fixture } = require("./excalidraw-canvas-fixture.cjs");

function assertNoBindings(f) {
  assert.equal(f.listeners.size, 0);
  assert.equal(f.view.scope, undefined);
  assert.equal(f.domObservers.some((observer) => observer.connected), false);
  assert.equal(f.windowListeners.size, 0);
  assert.equal(f.subscribers.size, 0);
  assert.equal(f.timers.size, 0);
}

function testScriptLifecycle(scriptName) {
  test(`${scriptName}: autostart permission can disable this feature`, async () => {
    const f = fixture(scriptName);
    f.ea.registerAutostart = async () => "deny";
    await f.run();
    assertNoBindings(f);
    assert.equal(f.cleanups.size, 0);
  });

  test(`${scriptName}: cleanup cancels startup while the canvas loads`, async () => {
    const f = fixture(scriptName);
    f.ea.getExcalidrawAPI = () => null;
    f.clock.onTick = () => {
      for (const cleanup of [...f.cleanups]) cleanup();
    };
    await f.run();
    assertNoBindings(f);
    assert.equal(f.clock.ticks, 1);
    assert.equal(f.autostarts.length, 0);
    assert.equal(f.cleanups.size, 0);
  });

  test(`${scriptName}: cleanup cancels a pending permission request`, async () => {
    const f = fixture(scriptName);
    let allow;
    f.ea.registerAutostart = () => new Promise((resolve) => { allow = resolve; });
    const running = f.run();
    await Promise.resolve();
    assert.equal(typeof allow, "function");
    for (const cleanup of [...f.cleanups]) cleanup();
    allow("allow");
    await running;
    assertNoBindings(f);
    assert.equal(f.cleanups.size, 0);
  });

  test(`${scriptName}: a rerun replaces pending startup without duplicate bindings`, async () => {
    const f = fixture(scriptName);
    let ready = false;
    let replacement;
    f.ea.getExcalidrawAPI = () => ready ? f.api : null;
    f.clock.onTick = () => {
      ready = true;
      replacement = f.run();
    };
    await f.run();
    await replacement;
    assert.equal(f.autostarts.length, 1);
    assert.equal(f.cleanups.size, 1);
    for (const cleanup of [...f.cleanups]) cleanup();
    assertNoBindings(f);
    assert.equal(f.cleanups.size, 0);
  });
}

module.exports = { testScriptLifecycle };
