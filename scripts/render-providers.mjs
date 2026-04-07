#!/usr/bin/env node
import { readdirSync, readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, cpSync } from 'node:fs';
import { join } from 'node:path';

const repo = process.cwd();
const sharedCommandsDir = join(repo, 'src', 'shared', 'commands', 'mm');
const sharedAgentsDir = join(repo, 'src', 'shared', 'agents');
const claudeCommandsDir = join(repo, 'src', 'commands', 'mm');
const claudeAgentsDir = join(repo, 'src', 'agents');
const codexSkillsRoot = join(repo, 'src', 'codex', 'skills');
const codexAgentsDir = join(repo, 'src', 'codex', 'agents');
const codexTemplatesDir = join(repo, 'src', 'codex', 'templates');

function ensure(dir) {
  mkdirSync(dir, { recursive: true });
}

function clearDir(dir) {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
}

function parseFrontmatter(md) {
  const m = md.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) return { attrs: {}, body: md };
  const attrs = {};
  for (const line of m[1].split('\n')) {
    const idx = line.indexOf(':');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let val = line.slice(idx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    attrs[key] = val;
  }
  return { attrs, body: m[2].trimStart() };
}

function normalizeSkillName(commandName, fallbackBase) {
  if (commandName && commandName.includes(':')) {
    const slug = commandName.split(':')[1].trim();
    return `mm-${slug}`;
  }
  return `mm-${fallbackBase.replace(/\.md$/, '')}`;
}

function shellEscapeTomlMultiline(text) {
  return text.replace(/"""/g, '\\\"\\\"\\\"');
}

function renderCodexAgentToml(md, fileName) {
  const { attrs, body } = parseFrontmatter(md);
  const name = attrs.name || fileName.replace(/\.md$/, '');
  const description = attrs.description || `${name} specialist`;
  const prompt = shellEscapeTomlMultiline(body.trim());
  return `name = "${name}"\ndescription = "${description.replace(/"/g, '\\"')}"\nmodel = "gpt-5.4-mini"\nreasoning_effort = "medium"\nprompt = """\n${prompt}\n"""\n`;
}

function buildCommands() {
  ensure(sharedCommandsDir);
  ensure(claudeCommandsDir);
  clearDir(codexSkillsRoot);

  const files = readdirSync(sharedCommandsDir).filter(f => f.endsWith('.md')).sort();
  const mapping = [];

  for (const file of files) {
    const src = join(sharedCommandsDir, file);
    const md = readFileSync(src, 'utf8');

    // Claude command output
    writeFileSync(join(claudeCommandsDir, file), md);

    // Codex skill output
    const { attrs, body } = parseFrontmatter(md);
    const commandName = attrs.name || `mm:${file.replace(/\.md$/, '')}`;
    const description = attrs.description || 'Claude-solo command skill';
    const skillName = normalizeSkillName(commandName, file);
    const skillDir = join(codexSkillsRoot, skillName);
    ensure(skillDir);

    const skill = `# ${skillName}\n\n${description}\n\n## Instructions\n${body.trim()}\n`;
    writeFileSync(join(skillDir, 'SKILL.md'), skill);

    mapping.push({ command: `/${commandName}`, skill: `$${skillName}` });
  }

  return mapping;
}

function buildAgents() {
  ensure(sharedAgentsDir);
  ensure(claudeAgentsDir);
  clearDir(codexAgentsDir);

  const files = readdirSync(sharedAgentsDir).filter(f => f.endsWith('.md')).sort();

  for (const file of files) {
    const src = join(sharedAgentsDir, file);
    const md = readFileSync(src, 'utf8');

    // Claude agent output
    writeFileSync(join(claudeAgentsDir, file), md);

    // Codex agent output
    const toml = renderCodexAgentToml(md, file);
    writeFileSync(join(codexAgentsDir, file.replace(/\.md$/, '.toml')), toml);
  }
}

function buildCodexAgentsMd(mapping) {
  const block = mapping
    .map(m => `- \`${m.command}\` -> use \`${m.skill}\``)
    .join('\n');

  const content = `<!-- claude-solo-codex:start -->\n## claude-solo Codex Compatibility\n\nThis project supports the same /mm workflow in Codex using generated skills.\n\nCommand routing:\n${block}\n\nHook wrappers (Claude-like behavior):\n- Session start: \`node .codex/hooks/mm-hook.js session-start\`\n- Prompt submit transform: \`node .codex/hooks/mm-hook.js prompt-submit < payload.json\`\n- Pre tool warning: \`node .codex/hooks/mm-hook.js pre-tool-use < payload.json\`\n- Permission decision: \`node .codex/hooks/mm-hook.js permission-request < payload.json\`\n- Post tool telemetry: \`node .codex/hooks/mm-hook.js post-tool-use < payload.json\`\n- Pre compact checkpoint: \`node .codex/hooks/mm-hook.js pre-compact < payload.json\`\n- Subagent capture: \`node .codex/hooks/mm-hook.js subagent-stop < payload.json\`\n- Session end summary: \`node .codex/hooks/mm-hook.js session-end < payload.json\`\n\nWhen a user asks for an \`/mm:*\` command, run the mapped \`$mm-*\` skill automatically.\n<!-- claude-solo-codex:end -->\n`;

  writeFileSync(join(repo, 'src', 'codex', 'AGENTS.md'), content);
}

function buildCodexConfigTemplate() {
  const templatePath = join(codexTemplatesDir, 'config.toml');
  if (!existsSync(templatePath)) return;
  const template = readFileSync(templatePath, 'utf8');
  writeFileSync(join(repo, 'src', 'codex', 'config.toml'), template);
}

function buildCodexMcpTemplate() {
  const srcMcp = join(repo, 'src', 'mcp.json');
  const dstMcp = join(repo, 'src', 'codex', 'mcp.json');
  if (existsSync(srcMcp)) {
    cpSync(srcMcp, dstMcp);
  }
}

const mapping = buildCommands();
buildAgents();
buildCodexAgentsMd(mapping);
buildCodexConfigTemplate();
buildCodexMcpTemplate();

console.log(`Rendered ${mapping.length} commands and shared agents for Claude + Codex.`);
