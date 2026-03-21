const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

// SERVE_DIR must point to directory with index.html and tfview.js
const serveDir = process.env.SERVE_DIR;
if (!serveDir) { process.stderr.write("SERVE_DIR not set\n"); process.exit(1); }

const modelPath = path.resolve(process.argv[2]);
const expectedPath = process.argv[3];

// Reuse the shared serve.js with SERVE_DIR already set
const serve = require("./serve");

serve.listen(0, "127.0.0.1", async () => {
  const port = serve.address().port;
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${port}/`);

    await page.setInputFiles("#file", modelPath);

    await page.waitForFunction(() => {
      const text = document.getElementById("output").textContent;
      return text !== "Select a .tflite file to view its structure."
          && text !== "Loading...";
    });

    const outputText = await page.textContent("#output");
    const expected = fs.readFileSync(expectedPath, "utf8");
    let failed = false;

    if (outputText !== expected) {
      process.stderr.write("FAIL: output mismatch\n");
      failed = true;
    }

    const isDisabled = await page.$eval("#download", (el) => el.disabled);
    if (isDisabled) {
      process.stderr.write("FAIL: download button still disabled\n");
      failed = true;
    }

    process.exitCode = failed ? 1 : 0;
  } finally {
    await browser.close();
    serve.close();
  }
});
