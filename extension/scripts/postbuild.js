const fs = require("fs");
const path = require("path");

const distDir = path.join(__dirname, "..", "dist");
const sharedDir = path.join(distDir, "shared");
const contentPath = path.join(distDir, "content.js");
const backgroundPath = path.join(distDir, "background.js");

function readSharedModules() {
  if (!fs.existsSync(sharedDir)) return [];
  return fs
    .readdirSync(sharedDir)
    .filter((file) => file.endsWith(".js"))
    .map((file) => ({
      name: file.replace(/\.js$/, ""),
      path: path.join(sharedDir, file),
    }));
}

function loadSharedSource(sharedPath) {
  let source = fs.readFileSync(sharedPath, "utf8");
  // Drop intra-shared imports (e.g. "./index")
  source = source.replace(/import\s+[^;]+from\s+"\.\/index";\s*/g, "");
  // Strip ESM exports
  source = source.replace(/\bexport\s+(?=(const|function|class|async\s+function|let|var))/g, "");
  source = source.replace(/export\s*\{[^}]*\};?\s*/g, "");
  return source.trim() + "\n";
}

function inlineSharedInto(targetPath) {
  if (!fs.existsSync(targetPath)) return;

  let targetSource = fs.readFileSync(targetPath, "utf8");
  const sharedModules = readSharedModules();

  for (const module of sharedModules) {
    const importPattern = new RegExp(
      String.raw`import\s+[^;]+from\s+"\.\/shared\/${module.name}";\s*`
    );
    if (!importPattern.test(targetSource)) continue;

    const sharedSource = loadSharedSource(module.path);
    targetSource = targetSource.replace(importPattern, `${sharedSource}\n`);
  }

  fs.writeFileSync(targetPath, targetSource);
}

inlineSharedInto(contentPath);
inlineSharedInto(backgroundPath);

function removeSharedBundle() {
  if (!fs.existsSync(sharedDir)) return;
  try {
    for (const file of fs.readdirSync(sharedDir)) {
      fs.unlinkSync(path.join(sharedDir, file));
    }
    fs.rmdirSync(sharedDir);
  } catch (error) {
    console.warn("[postbuild] Failed to remove shared bundle", error);
  }
}

removeSharedBundle();
