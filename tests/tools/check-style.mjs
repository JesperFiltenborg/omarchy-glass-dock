// Whitespace and layout rules for every tracked text file, the ones
// .editorconfig describes. QML has no formatter we trust (qmlformat rewrites
// trailing comments in object literals), so this is its style gate.
//
//   node tests/tools/check-style.mjs          report
//   node tests/tools/check-style.mjs --fix    fix what can be fixed safely

import { execFileSync } from "node:child_process"
import { readFileSync, writeFileSync } from "node:fs"

const fix = process.argv.includes("--fix")
const root = new URL("../../", import.meta.url).pathname

const SCRIPTS = /^(scripts|\.githooks|tests\/e2e)\/[^.]+$/
const TEXT = new RegExp(
  /\.(qml|mjs|js|lua|sh|json|md|ya?ml|toml|ini)$|(^|\/)(\.editorconfig|\.luacheckrc|LICENSE)$/.source +
    `|${SCRIPTS.source}`,
)
// Indented in steps of two spaces. Markdown and LICENSE are free-form.
const TWO_SPACE = /\.(qml|mjs|js|lua|sh|json|ya?ml)$|^(scripts|\.githooks|tests\/e2e)\/[^.]+$/
const MAX_LINE = { qml: 140, mjs: 120, lua: 120, sh: 120 }

const files = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], {
  cwd: root,
  encoding: "utf8",
})
  .split("\n")
  .filter(f => f && TEXT.test(f))

const problems = []
let fixed = 0

for (const file of files) {
  let text
  try {
    text = readFileSync(root + file, "utf8")
  } catch {
    continue // deleted but still listed
  }
  const original = text
  const ext = file.split(".").pop()
  const report = (line, message) => problems.push(`${file}:${line}: ${message}`)

  if (text.includes("\r\n")) {
    if (fix) text = text.replaceAll("\r\n", "\n")
    else report(1, "CRLF line endings")
  }
  if (text.length && !text.endsWith("\n")) {
    if (fix) text += "\n"
    else report(text.split("\n").length, "missing final newline")
  }
  if (/\n\n+$/.test(text) && text.trim().length) {
    if (fix) text = text.replace(/\n+$/, "\n")
    else report(text.split("\n").length, "blank lines at end of file")
  }

  const lines = text.split("\n")
  lines.forEach((line, i) => {
    const n = i + 1
    if (/[ \t]+$/.test(line) && ext !== "md") {
      if (fix) lines[i] = line.replace(/[ \t]+$/, "")
      else report(n, "trailing whitespace")
    }
    if (/^\t/.test(line) && ext !== "md") report(n, "tab indentation (use spaces)")
    if (TWO_SPACE.test(file)) {
      const indent = line.match(/^ */)[0].length
      // Continuation lines inside block comments (" * ") are exempt.
      if (indent % 2 && !/^ +\*/.test(line)) report(n, `indent of ${indent} (use steps of 2)`)
    }
    const max = MAX_LINE[ext]
    if (max && line.length > max && !/https?:\/\//.test(line))
      report(n, `line is ${line.length} chars (max ${max})`)
  })
  text = lines.join("\n")

  if (fix && text !== original) {
    writeFileSync(root + file, text)
    fixed++
  }
}

if (fix && fixed) console.log(`check-style: fixed ${fixed} file(s)`)
console.log(`check-style: ${files.length} files, ${problems.length} problem(s)`)
for (const p of problems) console.log(`  ${p}`)
process.exit(problems.length ? 1 : 0)
