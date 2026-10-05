#!/bin/bash
# Static QC for Macro. Run from the repo root: ./qc.sh (exit 0 = pass)
# Adapted from App Starter's qc.sh: this project has no workbench.html,
# so every workbench.html check below was dropped, index.html only.
#
# Checks:
#   1. JS syntax: lib/*.js, sw.js, and every inline <script> block in
#      index.html
#   2. No inline style="..." in static markup, and no stray <style> blocks
#      beyond the one designated shell style block (page CSS built on tokens.css)
#   3. Version consistency: every ?v= cache-buster and sw.js CACHE agree with
#      APP.version (see CLAUDE.md, "Version bump ritual")
#   4. Duplicate DOM ids (warn only, never fails the build - a static text
#      match on a template-built id, e.g. id="f-${c.key}" in a column loop,
#      looks like a duplicate here but differs at runtime)
cd "$(dirname "$0")" || exit 1
fail=0

TMP_DIR=$(mktemp -d) || { echo "FAIL: could not create a temp dir"; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT

# Prints the content of every bare <script>...</script> block (no src=) in a
# file. Assumes each tag sits alone on its own line (current file convention);
# a "<script src=...>" line is a different exact string and never matches, so
# vendored lib tags are correctly left out of the extraction.
extract_inline_js() {
  awk '
    /<script>/   { insrc=1; next }
    /<\/script>/ { insrc=0; next }
    insrc        { print }
  ' "$1"
}

# Same file, with bare inline-script bodies blanked out, so a style="" grep
# only sees static markup, not JS strings that build modal HTML at runtime
# (e.g. the auth-modal template literals with style="color:var(--text2)").
strip_inline_js() {
  awk '
    /<script>/   { insrc=1; print; next }
    /<\/script>/ { insrc=0; print; next }
    insrc        { next }
    { print }
  ' "$1"
}

echo "- syntax: lib/*.js and sw.js"
for f in lib/kjr-format.js lib/kjr-calendar.js lib/kjr-sortable.js sw.js; do
  if ! err=$(node --check "$f" 2>&1); then
    echo "FAIL: $f"
    echo "$err" | sed 's/^/    /'
    fail=1
  fi
done

echo "- syntax: inline <script> blocks in index.html"
for f in index.html; do
  extract_inline_js "$f" > "$TMP_DIR/inline.js"
  if [ ! -s "$TMP_DIR/inline.js" ]; then
    echo "FAIL: no inline <script> content extracted from $f (expects <script> and </script> alone on their own line, check tag formatting has not changed)"
    fail=1
    continue
  fi
  if ! err=$(node --check "$TMP_DIR/inline.js" 2>&1); then
    echo "FAIL: inline <script> in $f"
    echo "$err" | sed 's/^/    /'
    fail=1
  fi
done

echo "- no inline style=\"...\" in markup, no stray <style> blocks"
for f in index.html; do
  n=$(strip_inline_js "$f" | grep -o 'style="' | wc -l | xargs)
  [ "$n" -eq 0 ] || { echo "FAIL: $f has $n inline style=\"...\" attribute(s) in static markup (outside the shell <script>), use a class + tokens.css instead"; fail=1; }
  s=$(grep -c '<style' "$f")
  [ "$s" -le 1 ] || { echo "FAIL: $f has $s <style> blocks, only the one shell block (head, built on tokens.css tokens) is allowed"; fail=1; }
done

echo "- version consistency (APP.version, ?v= cache-busters, sw.js CACHE)"
cat > "$TMP_DIR/version-check.js" <<'NODEEOF'
const fs = require('fs');
let fail = 0;
const idx = fs.readFileSync('index.html', 'utf8');
const sw  = fs.readFileSync('sw.js', 'utf8');

// Anchor to the const APP = {...} block so this cannot pick up an unrelated
// "version:" property elsewhere in the file (mirrors the starter's own
// in-browser version-consistency check, see CLAUDE.md).
const appBlock = (idx.match(/const APP\s*=\s*\{[\s\S]*?\};/) || [''])[0];
const appVer   = (appBlock.match(/version:\s*'v([\d.]+)/) || [])[1];
if (!appVer) { console.log('FAIL: APP.version not found in index.html'); process.exit(1); }

// Generic prefix match (project-name-vX.Y), not hardcoded to any one app.
const cacheVer = (sw.match(/CACHE\s*=\s*'[^']*-v([\d.]+)'/) || [])[1];
if (cacheVer !== appVer) {
  console.log('FAIL: sw.js CACHE suffix is v' + cacheVer + ', expected v' + appVer);
  fail = 1;
}

const vParams = (str) => [...str.matchAll(/\?v=([\d.]+)/g)].map(m => m[1]);
for (const [name, text] of [['index.html', idx], ['sw.js', sw]]) {
  const vs = vParams(text);
  if (vs.length === 0) { console.log('FAIL: no ?v= cache-buster found in ' + name); fail = 1; continue; }
  const bad = [...new Set(vs.filter(v => v !== appVer))];
  if (bad.length) { console.log('FAIL: ' + name + ' has ?v=' + bad.join(',') + ', expected ?v=' + appVer); fail = 1; }
}

if (!fail) console.log('  v' + appVer + ' agrees in APP.version, every ?v=, and sw.js CACHE');
process.exit(fail);
NODEEOF
node "$TMP_DIR/version-check.js" || fail=1

echo "- duplicate DOM ids (warn only: a template-built id can repeat in source text but differ at runtime, e.g. a form field id built from a loop variable)"
for f in index.html; do
  dupes=$(grep -o 'id="[^"]*"' "$f" | sort | uniq -d)
  if [ -n "$dupes" ]; then
    echo "  $f:"
    echo "$dupes" | sed 's/^/    /'
  fi
done

if [ "$fail" -eq 0 ]; then echo "QC PASS"; else echo "QC FAIL"; fi
exit "$fail"
