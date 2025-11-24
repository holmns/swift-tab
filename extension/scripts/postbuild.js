const fs = require("fs");
const path = require("path");

const distDir = path.join(__dirname, "..", "dist");
const contentPath = path.join(distDir, "content.js");

function stripModuleSyntax(source) {
  // Remove imports, exports, and leave the raw declarations behind for inlining.
  source = source.replace(/import\s+[^;]+;\s*/g, "");
  source = source.replace(/\bexport\s+(?=(const|function|class|async\s+function|let|var))/g, "");
  source = source.replace(/export\s*\{[^}]*\};?\s*/g, "");
  return source.trim() + "\n";
}

function loadModuleSource(modulePath) {
  if (!fs.existsSync(modulePath)) return null;
  const source = fs.readFileSync(modulePath, "utf8");
  return stripModuleSyntax(source);
}

function resolveImportPath(importPath) {
  const withExt = path.extname(importPath) ? importPath : `${importPath}.js`;
  return path.resolve(path.dirname(contentPath), withExt);
}

function inlineDependencies() {
  if (!fs.existsSync(contentPath)) return;

  let targetSource = fs.readFileSync(contentPath, "utf8");
  const importRegex = /import\s+[^;]+from\s+"(\.\/[^"]+)";\s*/g;
  const inlined = new Set();
  let didInline = false;

  while (true) {
    const match = importRegex.exec(targetSource);
    if (!match) break;
    const fullImport = match[0];
    const importPath = match[1];
    const modulePath = resolveImportPath(importPath);
    const moduleSource = loadModuleSource(modulePath);
    if (!moduleSource) {
      continue;
    }
    targetSource = targetSource.replace(fullImport, `${moduleSource}\n`);
    inlined.add(modulePath);
    didInline = true;
    importRegex.lastIndex = 0; // reset after replacement
  }

  if (didInline) {
    fs.writeFileSync(contentPath, targetSource);
  }

  return [...inlined];
}

function removeInlinedModules(inlinedFiles) {
  for (const file of inlinedFiles) {
    // Keep shared output because background still consumes it.
    if (file.startsWith(path.join(distDir, "shared"))) continue;
    if (file === contentPath) continue;
    if (fs.existsSync(file)) {
      fs.rmSync(file);
    }
  }
}

function removeEmptyContentDir() {
  const contentDir = path.join(distDir, "content");
  if (!fs.existsSync(contentDir)) return;
  const entries = fs.readdirSync(contentDir);
  if (entries.length === 0) {
    fs.rmdirSync(contentDir);
  }
}

const inlinedFiles = inlineDependencies() ?? [];
removeInlinedModules(inlinedFiles);
removeEmptyContentDir();
