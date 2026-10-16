// Conventional Commits and branch-name checks (docs/GIT_WORKFLOW.md).
//
//   node tests/tools/conventional.mjs commit <message-file>   commit-msg hook
//   node tests/tools/conventional.mjs title "<pr title>"      CI, pull requests
//   node tests/tools/conventional.mjs branch "<branch name>"  CI, pull requests

import { readFileSync } from "node:fs"

export const TYPES = [
  "feat",
  "fix",
  "docs",
  "style",
  "refactor",
  "perf",
  "test",
  "build",
  "ci",
  "chore",
  "revert",
]
export const BRANCH_TYPES = ["feat", "fix", "hotfix", "release", "docs", "chore"]
export const MAX_HEADER = 72

const HEADER = new RegExp(`^(${TYPES.join("|")})(\\([a-z0-9-]+\\))?(!)?: (\\S.*)$`)
// Headers git writes itself; they are fine on a branch and never reach main
// (pull requests are squash-merged under their title).
const GENERATED = /^(Merge |Revert "|fixup! |squash! |amend! )/

/** Problems with a commit message or PR title header; [] when it's valid. */
export function checkHeader(header) {
  if (GENERATED.test(header)) return []
  const problems = []
  const m = header.match(HEADER)
  if (!m) {
    problems.push(`"${header}" isn't "<type>(<scope>): <description>"; types: ${TYPES.join(", ")}`)
    return problems
  }
  const description = m[4]
  if (header.length > MAX_HEADER) problems.push(`header is ${header.length} chars (max ${MAX_HEADER})`)
  if (/^[A-Z][a-z]/.test(description)) problems.push("start the description in lower case")
  if (/\.$/.test(description)) problems.push("don't end the description with a period")
  return problems
}

/** Problems with a whole commit message (git's comment lines are ignored). */
export function checkCommit(message) {
  const lines = message
    .split("\n")
    .filter(line => !line.startsWith("#"))
    .join("\n")
    .trim()
    .split("\n")
  if (lines.length === 0 || lines[0] === "") return ["the commit message is empty"]
  const problems = checkHeader(lines[0])
  if (lines.length > 1 && lines[1] !== "") problems.push("leave a blank line after the header")
  return problems
}

/** Problems with a branch name; [] when it's valid. */
export function checkBranch(name) {
  if (name === "main") return []
  const [type, ...rest] = name.split("/")
  const topic = rest.join("/")
  if (BRANCH_TYPES.indexOf(type) === -1 || rest.length !== 1) {
    return [`"${name}" isn't "<type>/<topic>"; types: ${BRANCH_TYPES.join(", ")}`]
  }
  if (type === "release") {
    return /^\d+\.\d+\.\d+$/.test(topic) ? [] : [`release branches are release/<version>, e.g. release/1.3.0`]
  }
  return /^[a-z0-9]+(-[a-z0-9]+)*$/.test(topic) ? [] : [`"${topic}" should be lower-case words joined by -`]
}

function main(argv) {
  const [kind, arg] = argv
  const check = {
    commit: () => checkCommit(readFileSync(arg, "utf8")),
    title: () => checkHeader(arg),
    branch: () => checkBranch(arg),
  }[kind]
  if (!check || arg === undefined) {
    console.error("usage: conventional.mjs commit <file> | title <text> | branch <name>")
    return 2
  }
  const problems = check()
  for (const p of problems) console.error(`✘ ${kind}: ${p}`)
  if (problems.length) console.error("See docs/GIT_WORKFLOW.md.")
  return problems.length ? 1 : 0
}

if (import.meta.url === `file://${process.argv[1]}`) process.exit(main(process.argv.slice(2)))
