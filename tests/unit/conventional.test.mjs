import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as C from "../tools/conventional.mjs"

describe("commit headers", () => {
  it("accepts type, optional scope and breaking marker", () => {
    assert.deepEqual(C.checkHeader("feat: add a show delay"), [])
    assert.deepEqual(C.checkHeader("fix(switcher): keep focus on cancel"), [])
    assert.deepEqual(C.checkHeader("feat(ipc)!: rename the toggle method"), [])
    assert.deepEqual(C.checkHeader("chore(release): 1.3.0"), [])
  })

  it("rejects unknown types and missing separators", () => {
    assert.equal(C.checkHeader("feature: add x").length, 1)
    assert.equal(C.checkHeader("Add GitHub issue templates").length, 1)
    assert.equal(C.checkHeader("fix:no space").length, 1)
    assert.equal(C.checkHeader("fix(Dock): upper-case scope").length, 1)
  })

  it("enforces length, lower-case start and no trailing period", () => {
    assert.match(C.checkHeader(`docs: ${"x".repeat(80)}`)[0], /max 72/)
    assert.match(C.checkHeader("fix: Fix the dock")[0], /lower case/)
    assert.match(C.checkHeader("fix: fix the dock.")[0], /period/)
    assert.deepEqual(C.checkHeader("docs: explain IPC in the README"), [])
  })

  it("lets git's own headers through", () => {
    assert.deepEqual(C.checkHeader("Merge branch 'main' into feat/x"), [])
    assert.deepEqual(C.checkHeader('Revert "feat: add x"'), [])
    assert.deepEqual(C.checkHeader("fixup! feat: add x"), [])
  })
})

describe("commit messages", () => {
  it("ignores git's comment lines", () => {
    assert.deepEqual(C.checkCommit("# Please enter a message\nfeat: add x\n\nBody.\n# comment\n"), [])
  })

  it("needs a blank line after the header", () => {
    assert.match(C.checkCommit("feat: add x\nbody right away")[0], /blank line/)
  })

  it("rejects an empty message", () => {
    assert.equal(C.checkCommit("# only comments\n").length, 1)
  })
})

describe("branch names", () => {
  it("accepts <type>/<kebab-topic> and release/<version>", () => {
    for (const name of [
      "feat/show-delay",
      "fix/alt-tab-focus",
      "hotfix/1-2-1-crash",
      "docs/install",
      "chore/biome-2",
      "release/1.3.0",
      "main",
    ]) {
      assert.deepEqual(C.checkBranch(name), [], name)
    }
  })

  it("rejects other shapes", () => {
    for (const name of ["feature/x", "feat/Show_Delay", "feat/a/b", "release/next", "show-delay", "fix/"]) {
      assert.equal(C.checkBranch(name).length, 1, name)
    }
  })
})
