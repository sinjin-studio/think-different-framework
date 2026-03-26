#!/usr/bin/env node
const http = require("http");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const htmlPath = path.join(__dirname, "..", "harness", "index.html");

if (!fs.existsSync(htmlPath)) {
  console.error("Error: harness/index.html not found at", htmlPath);
  process.exit(1);
}

const server = http.createServer((req, res) => {
  // Re-read HTML on each request for live editing
  const html = fs.readFileSync(htmlPath, "utf8");
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(html);
});

server.listen(0, "127.0.0.1", () => {
  const { port } = server.address();
  const url = `http://127.0.0.1:${port}`;
  console.log(`\n  Think Different Framework - Test Harness`);
  console.log(`  ${url}\n`);
  console.log(`  Press Ctrl+C to stop.\n`);

  // Open browser
  try {
    if (process.platform === "darwin") execSync(`open "${url}"`);
    else if (process.platform === "linux") execSync(`xdg-open "${url}"`);
    else if (process.platform === "win32") execSync(`start "${url}"`);
  } catch {}
});

process.on("SIGINT", () => {
  server.close();
  process.exit(0);
});
