import fs from 'fs-extra';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = path.resolve(__dirname, '..');

// Target: ~/.claude (global Claude Code config)
const CLAUDE_DIR = path.join(os.homedir(), '.claude');

const INSTALL_MANIFEST = path.join(CLAUDE_DIR, '.claude-solo-manifest.json');

function log(msg) { console.log(`  ${msg}`); }
function ok(msg)  { console.log(`  ✓ ${msg}`); }
function warn(msg) { console.log(`  ⚠ ${msg}`); }

export async function install() {
  console.log('\nclaude-solo install\n');

  await fs.ensureDir(CLAUDE_DIR);
  await fs.ensureDir(path.join(CLAUDE_DIR, 'agents'));
  await fs.ensureDir(path.join(CLAUDE_DIR, 'skills'));
  await fs.ensureDir(path.join(CLAUDE_DIR, 'hooks'));

  const installed = [];

  // 1. Install CLAUDE.md (append our block, don't overwrite)
  const claudeMdPath = path.join(CLAUDE_DIR, 'CLAUDE.md');
  const ourBlock = await fs.readFile(path.join(PKG_ROOT, 'src', 'CLAUDE.md'), 'utf8');

  const MARKER_START = '<!-- claude-solo:start -->';
  const MARKER_END = '<!-- claude-solo:end -->';

  let existing = '';
  if (await fs.pathExists(claudeMdPath)) {
    existing = await fs.readFile(claudeMdPath, 'utf8');
    // Remove existing claude-solo block if present
    const start = existing.indexOf(MARKER_START);
    const end = existing.indexOf(MARKER_END);
    if (start !== -1 && end !== -1) {
      existing = existing.slice(0, start) + existing.slice(end + MARKER_END.length);
    }
    ok('Found existing CLAUDE.md — appending (not overwriting)');
  }

  const combined = `${existing.trimEnd()}\n\n${MARKER_START}\n${ourBlock}\n${MARKER_END}\n`;
  await fs.writeFile(claudeMdPath, combined, 'utf8');
  ok('CLAUDE.md updated');
  installed.push('CLAUDE.md');

  // 2. Install agents
  const agentsDir = path.join(PKG_ROOT, 'src', 'agents');
  if (await fs.pathExists(agentsDir)) {
    const agents = await fs.readdir(agentsDir);
    for (const agent of agents) {
      const src = path.join(agentsDir, agent);
      const dest = path.join(CLAUDE_DIR, 'agents', agent);
      await fs.copy(src, dest, { overwrite: true });
      ok(`Agent: ${agent}`);
      installed.push(`agents/${agent}`);
    }
  }

  // 3. Install skills
  const skillsDir = path.join(PKG_ROOT, 'src', 'skills');
  if (await fs.pathExists(skillsDir)) {
    const skills = await fs.readdir(skillsDir);
    for (const skill of skills) {
      const src = path.join(skillsDir, skill);
      const dest = path.join(CLAUDE_DIR, 'skills', skill);
      await fs.copy(src, dest, { overwrite: true });
      ok(`Skill: ${skill}`);
      installed.push(`skills/${skill}`);
    }
  }

  // 4. Install hooks
  const hooksDir = path.join(PKG_ROOT, 'src', 'hooks');
  if (await fs.pathExists(hooksDir)) {
    const hooks = await fs.readdir(hooksDir);
    for (const hook of hooks) {
      const src = path.join(hooksDir, hook);
      const dest = path.join(CLAUDE_DIR, 'hooks', hook);
      await fs.copy(src, dest, { overwrite: true });
      ok(`Hook: ${hook}`);
      installed.push(`hooks/${hook}`);
    }
  }

  // 5. Merge settings.json (hooks config)
  const ourSettings = await fs.readJson(path.join(PKG_ROOT, 'src', 'settings', 'settings.json'));
  const settingsPath = path.join(CLAUDE_DIR, 'settings.json');

  let existingSettings = {};
  if (await fs.pathExists(settingsPath)) {
    try {
      existingSettings = await fs.readJson(settingsPath);
      ok('Found existing settings.json — merging hooks (not overwriting)');
    } catch {
      warn('Could not parse existing settings.json — skipping merge');
    }
  }

  // Deep merge hooks only
  const merged = {
    ...existingSettings,
    hooks: {
      ...existingSettings.hooks,
      ...ourSettings.hooks,
    }
  };
  await fs.writeJson(settingsPath, merged, { spaces: 2 });
  ok('settings.json updated (hooks registered)');
  installed.push('settings.json');

  // 6. Save manifest
  await fs.writeJson(INSTALL_MANIFEST, {
    version: (await fs.readJson(path.join(PKG_ROOT, 'package.json'))).version,
    installed_at: new Date().toISOString(),
    files: installed
  }, { spaces: 2 });

  console.log(`\nDone! claude-solo installed ${installed.length} files into ~/.claude\n`);
  console.log('Available commands in Claude Code:');
  console.log('  /brief  /plan  /build  /review  /test  /ship  /retro\n');
}

export async function uninstall() {
  console.log('\nclaude-solo uninstall\n');

  if (!await fs.pathExists(INSTALL_MANIFEST)) {
    warn('Nothing installed. Run: claude-solo install');
    return;
  }

  const manifest = await fs.readJson(INSTALL_MANIFEST);

  // Remove CLAUDE.md block
  const claudeMdPath = path.join(CLAUDE_DIR, 'CLAUDE.md');
  if (await fs.pathExists(claudeMdPath)) {
    const MARKER_START = '<!-- claude-solo:start -->';
    const MARKER_END = '<!-- claude-solo:end -->';
    let content = await fs.readFile(claudeMdPath, 'utf8');
    const start = content.indexOf(MARKER_START);
    const end = content.indexOf(MARKER_END);
    if (start !== -1 && end !== -1) {
      content = content.slice(0, start) + content.slice(end + MARKER_END.length);
      await fs.writeFile(claudeMdPath, content.trimEnd() + '\n', 'utf8');
      ok('Removed from CLAUDE.md');
    }
  }

  // Remove installed files
  for (const file of manifest.files) {
    if (file === 'CLAUDE.md') continue; // handled above
    const fullPath = path.join(CLAUDE_DIR, file);
    if (await fs.pathExists(fullPath)) {
      await fs.remove(fullPath);
      ok(`Removed: ${file}`);
    }
  }

  await fs.remove(INSTALL_MANIFEST);
  console.log('\nUninstalled. Your own Claude Code files are untouched.\n');
}

export async function status() {
  console.log('\nclaude-solo status\n');

  if (!await fs.pathExists(INSTALL_MANIFEST)) {
    warn('Not installed. Run: claude-solo install');
    return;
  }

  const manifest = await fs.readJson(INSTALL_MANIFEST);
  log(`Version: ${manifest.version}`);
  log(`Installed: ${manifest.installed_at}`);
  log(`Files: ${manifest.files.length}`);
  console.log();
  for (const f of manifest.files) {
    ok(f);
  }
  console.log();
}

export async function update() {
  console.log('\nclaude-solo update\n');
  log('Reinstalling with latest version...');
  await install();
}
