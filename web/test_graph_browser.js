const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const { PNG } = require("pngjs");
const _pm = require("pixelmatch");
const pixelmatch = typeof _pm === "function" ? _pm : _pm.default;

// SERVE_DIR must point to directory with graph.html and tfview.js
const serveDir = process.env.SERVE_DIR;
if (!serveDir) { process.stderr.write("SERVE_DIR not set\n"); process.exit(1); }

const modelPath = path.resolve(process.argv[2]);
const modelName = path.basename(modelPath, ".tflite");

const goldenDir = path.join(__dirname, "golden");
const goldenPath = path.join(goldenDir, "graph-" + modelName + ".png");
const updateGolden = process.env.UPDATE_GOLDEN === "1";
const maxMismatchPixels = parseInt(process.env.GOLDEN_THRESHOLD || "16384", 10);

const serve = require("./serve");

serve.listen(0, "127.0.0.1", async () => {
  const port = serve.address().port;
  const browser = await chromium.launch({
    args: ['--use-gl=angle', '--use-angle=swiftshader'],
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1024, height: 768 } });
    await page.goto(`http://127.0.0.1:${port}/graph.html`, { timeout: 60000 });

    // Wait for model-explorer-visualizer custom element to be defined
    await page.waitForFunction(() => {
      return customElements.get('model-explorer-visualizer') !== undefined;
    }, { timeout: 30000 });

    await page.setInputFiles("#file", modelPath);

    // Wait for model-explorer to process the graph data
    // It shows "op node count" in the info panel when data is loaded
    await page.waitForFunction(() => {
      var el = document.querySelector('model-explorer-visualizer');
      if (!el || !el.shadowRoot) return false;
      var text = el.shadowRoot.textContent || '';
      return text.includes('op node count');
    }, { timeout: 60000 });

    // Give model-explorer time to finish rendering
    await page.waitForTimeout(3000);

    let failed = false;

    // Screenshot comparison
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
          const diffDir = path.join(__dirname, "..", "_build", "models");
          fs.mkdirSync(diffDir, { recursive: true });
          const diffPath = path.join(diffDir, "graph-" + modelName + ".diff.png");
          fs.writeFileSync(diffPath, PNG.sync.write(diff));
          process.stderr.write(
            "FAIL: screenshot mismatch (" + mismatch + " pixels, " +
            "threshold " + maxMismatchPixels + "), diff saved to " +
            diffPath + "\n"
          );
          failed = true;
        }
      }
    } else {
      process.stderr.write("No golden image found, saving: " + goldenPath + "\n");
      fs.mkdirSync(goldenDir, { recursive: true });
      fs.writeFileSync(goldenPath, screenshot);
    }

    process.exitCode = failed ? 1 : 0;
  } finally {
    await browser.close();
    serve.close();
  }
});
