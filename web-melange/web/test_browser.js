const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const serve = require("../../web-jsoo/serve");

const modelPath = path.resolve(process.argv[2]);
const expectedPath = process.argv[3];

const origDir = process.env.SERVE_DIR;
process.env.SERVE_DIR = "_build/default/web-melange/web/static";

serve.listen(0, "127.0.0.1", async () => {
  process.env.SERVE_DIR = origDir;
  const port = serve.address().port;
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${port}/`);

    // Select model file exactly as a user would
    await page.setInputFiles("#file", modelPath);

    // Wait for parsing to complete
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
