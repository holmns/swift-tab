/** @type {import("eslint").Linter.Config} */
module.exports = {
  root: true,
  env: {
    browser: true,
    es2023: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: "latest",
    sourceType: "module",
  },
  plugins: ["@typescript-eslint", "prettier"],
  extends: ["plugin:@typescript-eslint/stylistic", "plugin:prettier/recommended"],
  globals: {
    chrome: "readonly",
  },
  ignorePatterns: ["dist/", "options-dist/", "node_modules/", "scripts/"],
  rules: {
    "prettier/prettier": "error",
    "no-empty-function": "off",
    "@typescript-eslint/no-empty-function": "off",
    "@typescript-eslint/prefer-for-of": "off",
  },
};
