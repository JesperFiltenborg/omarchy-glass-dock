// QML lint gate. Runs qmllint over every QML file and fails only on findings
// that are real bugs here. The rest is noise outside the Omarchy shell:
// qs.Commons, qs.Ui and Quickshell types can't be resolved by a standalone
// qmllint, and "unqualified access" is a style hint.
//
//   node tests/tools/lint-qml.mjs [path/to/qmllint]

import { execFileSync } from "node:child_process"
import { mkdtempSync, readFileSync, readdirSync, rmSync, existsSync } from "node:fs"
import { join, relative } from "node:path"
import { tmpdir } from "node:os"

const root = new URL("../../", import.meta.url).pathname
const qmllint = process.argv[2]
  || ["/usr/lib/qt6/bin/qmllint", "/usr/lib/qt/bin/qmllint", "/usr/bin/qmllint6", "/usr/bin/qmllint"].find(existsSync)

if (!qmllint) {
  console.error("qmllint not found (install qt6-declarative)")
  process.exit(2)
}

// Always failures.
const FAIL_IDS = new Set([
  "syntax", "duplicated-name", "duplicate-property-binding", "read-only-property",
  "alias-cycle", "multiline-strings", "deprecated",
])
// Imports qmllint can't resolve outside the shell; any other import failure
// (e.g. a mistyped "../core/lib/x.mjs") is a real error.
const EXTERNAL_IMPORT = /qs\.Commons|qs\.Ui|OmarchyUi|Quickshell/

function qmlFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    if (entry.name.startsWith(".") || entry.name === "tests" || entry.name === "node_modules") return []
    const path = join(dir, entry.name)
    return entry.isDirectory() ? qmlFiles(path) : entry.name.endsWith(".qml") ? [path] : []
  })
}

const files = qmlFiles(root)
const out = mkdtempSync(join(tmpdir(), "glassdock-lint-"))
const report = join(out, "report.json")
try {
  execFileSync(qmllint, ["--json", report, ...files], { stdio: "ignore" })
} catch {
  // qmllint exits non-zero for any warning; the JSON is what we judge.
}
const results = JSON.parse(readFileSync(report, "utf8"))
rmSync(out, { recursive: true, force: true })

const failures = []
const ignored = {}
for (const file of results.files) {
  for (const w of file.warnings) {
    const isFailure = FAIL_IDS.has(w.id) || (w.id === "import" && !EXTERNAL_IMPORT.test(w.message))
    if (isFailure) failures.push(`${relative(root, file.filename)}:${w.line}:${w.column} [${w.id}] ${w.message}`)
    else ignored[w.id] = (ignored[w.id] || 0) + 1
  }
}

const summary = Object.entries(ignored).map(([id, n]) => `${id} ×${n}`).join(", ")
console.log(`qmllint: ${files.length} files, ${failures.length} failure(s)` + (summary ? `; ignored: ${summary}` : ""))
for (const f of failures) console.log("  " + f)
process.exit(failures.length ? 1 : 0)
