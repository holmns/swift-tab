const fs = require("fs");
const path = require("path");

const distDir = path.join(__dirname, "..", "dist");
const sharedDir = path.join(distDir, "shared");
const contentPath = path.join(distDir, "content.js");

function loadSharedSource(sharedPath) {
  let source = fs.readFileSync(sharedPath, "utf8");
  source = source.replace(/import\s+[^;]+from\s+"\.\/index\.js";\s*/g, "");
  source = source.replace(/\bexport\s+(?=(const|function|class|async\s+function|let|var))/g, "");
  source = source.replace(/export\s*\{[^}]*\};?\s*/g, "");
  return source.trim() + "\n";
}

function inlineSharedForContent() {
  if (!fs.existsSync(contentPath) || !fs.existsSync(sharedDir)) return;

  const sharedIndexPath = path.join(sharedDir, "index.js");
  if (!fs.existsSync(sharedIndexPath)) return;

  const sharedSource = loadSharedSource(sharedIndexPath);
  const importPattern = /import\s+[^;]+from\s+"\.\/shared\/index\.js";\s*/;

  const targetSource = fs.readFileSync(contentPath, "utf8");
  if (!importPattern.test(targetSource)) return;

  const stitched = targetSource.replace(importPattern, `${sharedSource}\n`);
  fs.writeFileSync(contentPath, stitched);
}

inlineSharedForContent();
