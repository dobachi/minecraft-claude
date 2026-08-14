#!/usr/bin/env node
/**
 * Patch socket-be to survive a connection that closes before its World is registered.
 *
 * Why:
 *   Network.onConnectionClose() looks up the World for the closing connection and
 *   calls world.onDisconnect() without checking that the lookup succeeded:
 *
 *       onConnectionClose(connection, code) {
 *         const world = this.server.worlds.get(connection);
 *         world.onDisconnect();          // <-- TypeError when world is undefined
 *
 *   When a connection drops before world registration completes, this throws from a
 *   'ws' close event. Nothing catches it there, so the exception is fatal and takes
 *   the whole MCP server process down — which in turn kills the Claude Code session's
 *   MCP connection. We hit this for real: Minecraft connected, Player.load() failed,
 *   the connection closed, and the server died with
 *   "TypeError: Cannot read properties of undefined (reading 'onDisconnect')".
 *
 *   Still present in socket-be 2.6.0 (the current npm latest) and unaddressed upstream.
 *
 * This patch turns the crash into a clean no-op: an unregistered connection is simply
 * removed from the connection set.
 *
 * Idempotent — safe to run on every setup. Applies to both the CJS and ESM bundles.
 *
 * Usage: node scripts/patch-socket-be.js [path/to/node_modules/socket-be]
 */

"use strict";

const fs = require("fs");
const path = require("path");

const MARKER = "// PATCH(minecraft-claude): guard unregistered connection";

const TARGET = [
  "\t\tconst world = this.server.worlds.get(connection);",
  "\t\tworld.onDisconnect();",
].join("\n");

const REPLACEMENT = [
  "\t\tconst world = this.server.worlds.get(connection);",
  `\t\t${MARKER} — see scripts/patch-socket-be.js`,
  "\t\tif (!world) {",
  "\t\t\tthis.connections.delete(connection);",
  "\t\t\treturn;",
  "\t\t}",
  "\t\tworld.onDisconnect();",
].join("\n");

const pkgDir =
  process.argv[2] ||
  path.join(__dirname, "..", "server", "node_modules", "socket-be");

if (!fs.existsSync(pkgDir)) {
  console.error(`patch-socket-be: ${pkgDir} not found — run npm install first.`);
  process.exit(1);
}

const version = JSON.parse(
  fs.readFileSync(path.join(pkgDir, "package.json"), "utf8")
).version;

let patched = 0;
let alreadyPatched = 0;
let missed = 0;

for (const file of ["dist/index.cjs", "dist/index.mjs"]) {
  const full = path.join(pkgDir, file);
  if (!fs.existsSync(full)) {
    console.error(`  SKIP  ${file} (not present in socket-be ${version})`);
    continue;
  }

  const source = fs.readFileSync(full, "utf8");

  if (source.includes(MARKER)) {
    console.log(`  OK    ${file} (already patched)`);
    alreadyPatched++;
    continue;
  }

  if (!source.includes(TARGET)) {
    // The bundle changed shape — most likely upstream fixed this, or reformatted.
    // Report loudly rather than silently doing nothing.
    console.error(
      `  MISS  ${file} — target code not found in socket-be ${version}.`
    );
    missed++;
    continue;
  }

  fs.writeFileSync(full, source.replace(TARGET, REPLACEMENT));
  console.log(`  PATCH ${file}`);
  patched++;
}

console.log(
  `patch-socket-be: socket-be ${version} — ${patched} patched, ${alreadyPatched} already patched, ${missed} not found.`
);

if (missed > 0) {
  console.error(
    "\nOne or more targets were not found. Verify whether upstream fixed\n" +
      "Network.onConnectionClose; if so, this patch can be retired."
  );
  process.exit(1);
}
