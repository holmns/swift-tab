const fs = require("fs");
const path = require("path");

const distDir = path.join(__dirname, "..", "dist");
const sharedPath = path.join(distDir, "shared", "index.js");
const contentPath = path.join(distDir, "content.js");
const backgroundPath = path.join(distDir, "background.js");

function inlineSharedInto(targetPath) {
  if (!fs.existsSync(targetPath) || !fs.existsSync(sharedPath)) {
    return;
  }

  const sharedSource = fs.readFileSync(sharedPath, "utf8");
  const targetSource = fs.readFileSync(targetPath, "utf8");

  const strippedShared = sharedSource.replace(
    /\bexport\s+(?=(const|function|class))/g,
    ""
  );
  const importPattern = /import\s+[^;]+from\s+"\.\/shared\/index";\s*/;

  if (!importPattern.test(targetSource)) {
    return;
  }

  const stitched = targetSource.replace(importPattern, `${strippedShared}\n`);
  fs.writeFileSync(targetPath, stitched);
}

inlineSharedInto(contentPath);
inlineSharedInto(backgroundPath);

function removeSharedBundle() {
  if (!fs.existsSync(sharedPath)) {
    return;
  }

  try {
    fs.unlinkSync(sharedPath);
    const sharedDir = path.dirname(sharedPath);
    if (fs.existsSync(sharedDir) && fs.readdirSync(sharedDir).length === 0) {
      fs.rmdirSync(sharedDir);
    }
  } catch (error) {
    console.warn("[postbuild] Failed to remove shared bundle", error);
  }
}

removeSharedBundle();
