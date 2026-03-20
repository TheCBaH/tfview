const fs = require("fs");
const path = require("path");

const modelPath = process.argv[2];
const mode = process.argv[3]; // "api" or "dom"

if (mode === "api") {
  const mod = require(path.resolve("_build/default/web-jsoo/tfview_web.bc.js"));
  const data = fs.readFileSync(modelPath, "latin1");
  process.stdout.write(mod.tfview.parse(data));
} else if (mode === "dom") {
  const { JSDOM } = require("jsdom");
  const expectedPath = process.argv[4];

  const html = fs.readFileSync("web-jsoo/static/index.html", "utf8");
  const bundleJs = fs.readFileSync(
    "_build/default/web-jsoo/tfview_web.bc.js", "utf8"
  );
  // Remove the bundle script tag so we can inject globals first
  const stripped = html.replace(
    '<script src="tfview_web.bc.js"></script>',
    ""
  );

  const dom = new JSDOM(stripped, {
    runScripts: "dangerously",
    resources: "usable",
    url: "http://localhost",
  });
  const { window } = dom;
  const { document } = window;

  // Polyfill globals the js_of_ocaml bundle expects
  const util = require("util");
  window.TextDecoder = util.TextDecoder;
  window.TextEncoder = util.TextEncoder;

  // Execute the bundle and inline app script
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
