const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const { PNG } = require("pngjs");
const pixelmatch = require("pixelmatch");

// SERVE_DIR must point to directory with index.html and tfview.js
const serveDir = process.env.SERVE_DIR;
if (!serveDir) { process.stderr.write("SERVE_DIR not set\n"); process.exit(1); }

const modelPath = path.resolve(process.argv[2]);
const expectedPath = process.argv[3];
const modelName = path.basename(modelPath, ".tflite");

const goldenDir = path.join(__dirname, "golden");
const goldenPath = path.join(goldenDir, modelName + ".png");
const updateGolden = process.env.UPDATE_GOLDEN === "1";
const maxMismatchPixels = parseInt(process.env.GOLDEN_THRESHOLD || "100", 10);

// Reuse the shared serve.js with SERVE_DIR already set
const serve = require("./serve");

serve.listen(0, "127.0.0.1", async () => {
  const port = serve.address().port;
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1024, height: 768 } });
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

    // Screenshot comparison against golden reference
    const screenshot = await page.screenshot({ timeout: 60000 });

    if (updateGolden) {
      fs.mkdirSync(goldenDir, { recursive: true });
      fs.writeFileSync(goldenPath, screenshot);
      process.stderr.write("Updated golden: " + goldenPath + "\n");
    } else if (fs.existsSync(goldenPath)) {
      const actual = PNG.sync.read(screenshot);
      const golden = PNG.sync.read(fs.readFileSync(goldenPath));

      if (actual.width !== golden.width || actual.height !== golden.height) {
        process.stderr.write(
          "FAIL: screenshot size " + actual.width + "x" + actual.height +
          " differs from golden " + golden.width + "x" + golden.height + "\n"
        );
        failed = true;
      } else {
        const diff = new PNG({ width: actual.width, height: actual.height });
        const mismatch = pixelmatch(
          actual.data, golden.data, diff.data,
          actual.width, actual.height,
          { threshold: 0.1 }
        );

        if (mismatch > maxMismatchPixels) {
          const diffPath = path.join(
            path.dirname(expectedPath),
            modelName + ".diff.png"
          );
          fs.writeFileSync(diffPath, PNG.sync.write(diff));
          process.stderr.write(
            "FAIL: screenshot mismatch (" + mismatch + " pixels, " +
            "threshold " + maxMismatchPixels + "), diff saved to " +
            diffPath + "\n"
          );
          failed = true;
        }
      }
    }

    process.exitCode = failed ? 1 : 0;
  } finally {
    await browser.close();
    serve.close();
  }
});
