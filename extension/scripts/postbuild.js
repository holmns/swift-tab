const fs = require('fs');
const path = require('path');

const distDir = path.join(__dirname, '..', 'dist');
const sharedPath = path.join(distDir, 'shared', 'index.js');
const contentPath = path.join(distDir, 'content.js');

function inlineSharedIntoContent() {
  if (!fs.existsSync(contentPath) || !fs.existsSync(sharedPath)) {
    return;
  }

  const sharedSource = fs.readFileSync(sharedPath, 'utf8');
  const contentSource = fs.readFileSync(contentPath, 'utf8');

  const strippedShared = sharedSource.replace(/\bexport\s+/g, '');
  const importPattern = /import\s+\{[^}]+\}\s+from\s+"\.\/shared\/index";\s*/;

  if (!importPattern.test(contentSource)) {
    return;
  }

  const stitched = contentSource.replace(importPattern, `${strippedShared}\n`);
  fs.writeFileSync(contentPath, stitched);
}

inlineSharedIntoContent();
