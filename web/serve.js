const fs = require("fs");
const path = require("path");
const http = require("http");

const mimeTypes = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
};

const buildDir = process.env.SERVE_DIR || "_build/default/web-jsoo";

// Resolve model-explorer assets from npm package
let meDistDir;
try {
  meDistDir = path.join(path.dirname(require.resolve("ai-edge-model-explorer-visualizer/package.json")), "dist");
} catch {
  meDistDir = null;
}

const server = http.createServer((req, res) => {
  const urlPath = req.url === "/" ? "index.html" : req.url;

  // Serve model-explorer assets from npm package
  if (meDistDir && urlPath.startsWith("/model-explorer/")) {
    const mePath = path.join(meDistDir, urlPath.slice("/model-explorer/".length));
    let data;
    try {
      data = fs.readFileSync(mePath);
    } catch {
      res.writeHead(404);
      res.end();
      return;
    }
    const contentType = mimeTypes[path.extname(mePath)] || "application/octet-stream";
    res.writeHead(200, { "Content-Type": contentType });
    res.end(data);
    return;
  }

  const file = path.join(buildDir, urlPath);
  let data;
  try {
    data = fs.readFileSync(file);
  } catch {
    res.writeHead(404);
    res.end();
    return;
  }
  const contentType = mimeTypes[path.extname(file)] || "application/octet-stream";
  res.writeHead(200, { "Content-Type": contentType });
  res.end(data);
});

if (require.main === module) {
  const host = process.argv[2] || "127.0.0.1";
  const port = parseInt(process.argv[3] || "0", 10);
  server.listen(port, host, () => {
    const addr = server.address();
    console.log(`Serving at http://${addr.address}:${addr.port}`);
  });
}

module.exports = server;
