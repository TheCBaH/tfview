const fs = require("fs");
const path = require("path");
const http = require("http");

const mimeTypes = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
};

const buildDir = process.env.SERVE_DIR || "_build/default/web-jsoo";

const server = http.createServer((req, res) => {
  const file = path.join(buildDir, req.url === "/" ? "index.html" : req.url);
  try {
    const contentType = mimeTypes[path.extname(file)] || "application/octet-stream";
    res.writeHead(200, { "Content-Type": contentType });
    res.end(fs.readFileSync(file));
  } catch {
    res.writeHead(404);
    res.end();
  }
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
