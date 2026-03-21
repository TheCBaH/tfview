const fs = require("fs");
const path = require("path");

// SERVE_DIR must point to directory with index.html and tfview.js
const serveDir = process.env.SERVE_DIR;
if (!serveDir) { process.stderr.write("SERVE_DIR not set\n"); process.exit(1); }

const modelPath = process.argv[2];
const mode = process.argv[3]; // "api" or "dom"
const bundlePath = path.join(serveDir, "tfview.js");

if (mode === "api") {
  global.window = {};
  const mod = require(path.resolve(bundlePath));
  const tfview = (mod && mod.tfview) || window.tfview;
  const data = fs.readFileSync(modelPath, "latin1");
  process.stdout.write(tfview.parse(data));
} else if (mode === "dom") {
  const { JSDOM } = require("jsdom");
  const expectedPath = process.argv[4];

  const htmlPath = path.join(serveDir, "index.html");
  const html = fs.readFileSync(htmlPath, "utf8");
  const bundleJs = fs.readFileSync(bundlePath, "utf8");
  const stripped = html.replace('<script src="tfview.js"></script>', "");

  const dom = new JSDOM(stripped, {
    runScripts: "dangerously",
    resources: "usable",
    url: "http://localhost",
  });
  const { window } = dom;
  const { document } = window;

  // Polyfill globals that js_of_ocaml expects (harmless for melange)
  const util = require("util");
  window.TextDecoder = util.TextDecoder;
  window.TextEncoder = util.TextEncoder;

  window.eval(bundleJs);
  const appScript = html.match(/<script>\n?([\s\S]*?)<\/script>\s*<\/body>/);
  if (appScript) window.eval(appScript[1]);

  const modelData = fs.readFileSync(modelPath);
  const file = new dom.window.File([modelData], "test.tflite");
  const fileInput = document.getElementById("file");
  const output = document.getElementById("output");
  const downloadBtn = document.getElementById("download");

  Object.defineProperty(fileInput, "files", { value: [file] });
  fileInput.dispatchEvent(new dom.window.Event("change"));

  setTimeout(() => {
    const expected = fs.readFileSync(expectedPath, "utf8");
    let failed = false;
    if (output.textContent !== expected) {
      process.stderr.write("FAIL: output mismatch\n");
      failed = true;
    }
    if (downloadBtn.disabled) {
      process.stderr.write("FAIL: download button still disabled\n");
      failed = true;
    }
    dom.window.close();
    process.exit(failed ? 1 : 0);
  }, 500);
}
