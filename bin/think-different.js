#!/usr/bin/env node
const { execFileSync } = require("child_process");
const { join } = require("path");
try {
  execFileSync(join(__dirname, "..", "think.sh"), process.argv.slice(2), {
    stdio: "inherit",
  });
} catch (e) {
  process.exit(e.status || 1);
}
