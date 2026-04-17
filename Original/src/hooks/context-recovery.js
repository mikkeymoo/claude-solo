#!/usr/bin/env node

/**
 * Context Recovery Hook
 *
 * Purpose: Save and restore conversation context to minimize token usage
 * during long development sessions.
 *
 * Features:
 * - Automatic session snapshots
 * - Context state persistence
 * - Conversation recovery
 * - Archive management
 * - Token usage tracking
 *
 * Usage:
 * - Automatically runs during conversation
 * - Manual: node hooks/context-recovery.js [save|restore|list|clean]
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Configuration
const CONFIG = {
  snapshotsDir: path.join(__dirname, '../.claude/snapshots'),
  archiveDir: path.join(__dirname, '../.claude/archive'),
  maxSnapshots: 10,
  snapshotInterval: 15 * 60 * 1000, // 15 minutes
  compressionEnabled: true,
  autoCleanupDays: 30
};

class ContextRecovery {
  constructor() {
    this.ensureDirectories();
    this.sessionId = this.generateSessionId();
    this.lastSnapshot = null;
  }

  /**
   * Generate unique session ID
   */
  generateSessionId() {
    const timestamp = Date.now();
    const random = crypto.randomBytes(4).toString('hex');
    return `session-${timestamp}-${random}`;
  }

  /**
   * Ensure required directories exist
   */
  ensureDirectories() {
    [CONFIG.snapshotsDir, CONFIG.archiveDir].forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });
  }

  /**
   * Create snapshot of current session
   */
  async createSnapshot(metadata = {}) {
    try {
      const snapshot = {
        id: this.generateSnapshotId(),
        sessionId: this.sessionId,
        timestamp: Date.now(),
        metadata: {
          ...metadata,
          cwd: process.cwd(),
          nodeVersion: process.version,
          platform: process.platform
        },
        context: await this.captureContext(),
        fileState: await this.captureFileState(),
        gitState: await this.captureGitState()
      };

      const snapshotPath = path.join(
        CONFIG.snapshotsDir,
        `${snapshot.id}.json`
      );

      // Write snapshot
      fs.writeFileSync(
        snapshotPath,
        JSON.stringify(snapshot, null, 2),
        'utf8'
      );

      this.lastSnapshot = snapshot.id;

      console.log(`✅ Snapshot created: ${snapshot.id}`);
      console.log(`   Location: ${snapshotPath}`);
      console.log(`   Size: ${this.formatBytes(fs.statSync(snapshotPath).size)}`);

      // Cleanup old snapshots
      await this.cleanupOldSnapshots();

      return snapshot;
    } catch (error) {
      console.error('❌ Failed to create snapshot:', error.message);
      throw error;
    }
  }

  /**
   * Generate snapshot ID
   */
  generateSnapshotId() {
    const date = new Date();
    const dateStr = date.toISOString().split('T')[0];
    const timeStr = date.toTimeString().split(' ')[0].replace(/:/g, '-');
    return `snapshot-${dateStr}-${timeStr}`;
  }

  /**
   * Capture current context state
   */
  async captureContext() {
    const context = {
      documentation: [],
      activeFiles: [],
      recentCommands: [],
      environmentVars: {}
    };

    // Capture documentation files
    const docPatterns = [
      '*-plan.md',
      '*-context.md',
      '*-tasks.md',
      'CLAUDE.md',
      'README.md'
    ];

    for (const pattern of docPatterns) {
      const files = this.findFiles(process.cwd(), pattern);
      context.documentation.push(...files);
    }

    // Capture recently modified files
    context.activeFiles = this.getRecentlyModifiedFiles(24); // Last 24 hours

    // Capture environment (non-sensitive)
    context.environmentVars = {
      NODE_ENV: process.env.NODE_ENV,
      CI: process.env.CI
    };

    return context;
  }

  /**
   * Capture file state checksums
   */
  async captureFileState() {
    const state = {};

    const importantFiles = [
      'package.json',
      'package-lock.json',
      'tsconfig.json',
      '.env.example'
    ];

    for (const file of importantFiles) {
      const filePath = path.join(process.cwd(), file);
      if (fs.existsSync(filePath)) {
        const content = fs.readFileSync(filePath, 'utf8');
        state[file] = {
          checksum: this.calculateChecksum(content),
          size: content.length,
          modified: fs.statSync(filePath).mtime.toISOString()
        };
      }
    }

    return state;
  }

  /**
   * Capture Git repository state
   */
  async captureGitState() {
    try {
      const { execSync } = require('child_process');

      const state = {
        branch: execSync('git branch --show-current', { encoding: 'utf8' }).trim(),
        commit: execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim(),
        status: execSync('git status --short', { encoding: 'utf8' }).trim(),
        remotes: execSync('git remote -v', { encoding: 'utf8' }).trim()
      };

      return state;
    } catch (error) {
      return { error: 'Not a git repository or git not available' };
    }
  }

  /**
   * Restore from snapshot
   */
  async restoreSnapshot(snapshotId) {
    try {
      const snapshotPath = path.join(CONFIG.snapshotsDir, `${snapshotId}.json`);

      if (!fs.existsSync(snapshotPath)) {
        throw new Error(`Snapshot not found: ${snapshotId}`);
      }

      const snapshot = JSON.parse(fs.readFileSync(snapshotPath, 'utf8'));

      console.log('\n📦 Restoring context from snapshot...');
      console.log(`   Snapshot ID: ${snapshot.id}`);
      console.log(`   Created: ${new Date(snapshot.timestamp).toLocaleString()}`);
      console.log(`   Session: ${snapshot.sessionId}`);

      // Verify file states
      await this.verifyFileStates(snapshot.fileState);

      // Display context summary
      this.displayContextSummary(snapshot.context);

      // Create recovery file
      await this.createRecoveryFile(snapshot);

      console.log('\n✅ Context restored successfully!');
      console.log(`   Recovery file: ${path.join(process.cwd(), 'CONTEXT-RECOVERY.md')}`);

      return snapshot;
    } catch (error) {
      console.error('❌ Failed to restore snapshot:', error.message);
      throw error;
    }
  }

  /**
   * Verify file states match snapshot
   */
  async verifyFileStates(snapshotState) {
    console.log('\n🔍 Verifying file states...');

    const changes = [];

    for (const [file, state] of Object.entries(snapshotState)) {
      const filePath = path.join(process.cwd(), file);

      if (!fs.existsSync(filePath)) {
        changes.push({ file, status: 'deleted' });
        continue;
      }

      const content = fs.readFileSync(filePath, 'utf8');
      const currentChecksum = this.calculateChecksum(content);

      if (currentChecksum !== state.checksum) {
        changes.push({ file, status: 'modified' });
      }
    }

    if (changes.length > 0) {
      console.log('\n⚠️  File changes detected:');
      changes.forEach(({ file, status }) => {
        console.log(`   ${status === 'modified' ? '📝' : '🗑️'}  ${file} (${status})`);
      });
    } else {
      console.log('   ✅ All files match snapshot');
    }

    return changes;
  }

  /**
   * Display context summary
   */
  displayContextSummary(context) {
    console.log('\n📄 Context Summary:');
    console.log(`   Documentation files: ${context.documentation.length}`);
    console.log(`   Active files: ${context.activeFiles.length}`);

    if (context.documentation.length > 0) {
      console.log('\n   Documentation:');
      context.documentation.slice(0, 5).forEach(file => {
        console.log(`     - ${path.basename(file)}`);
      });
    }
  }

  /**
   * Create recovery markdown file
   */
  async createRecoveryFile(snapshot) {
    const content = `# Context Recovery Report

## Session Information
- **Snapshot ID:** ${snapshot.id}
- **Session ID:** ${snapshot.sessionId}
- **Created:** ${new Date(snapshot.timestamp).toLocaleString()}
- **Working Directory:** ${snapshot.metadata.cwd}

## Git State
\`\`\`
Branch: ${snapshot.gitState.branch || 'N/A'}
Commit: ${snapshot.gitState.commit || 'N/A'}

Status:
${snapshot.gitState.status || 'No changes'}
\`\`\`

## Documentation Files
${snapshot.context.documentation.map(file => `- ${file}`).join('\n')}

## Recently Modified Files
${snapshot.context.activeFiles.map(file => `- ${file}`).join('\n')}

## Recovery Instructions

1. **Review Documentation:** Start with the documentation files listed above
2. **Check Git State:** Review the current git branch and uncommitted changes
3. **Verify Files:** Ensure critical files match expected state
4. **Resume Work:** Continue from where you left off

---
*Generated by Context Recovery Hook on ${new Date().toLocaleString()}*
`;

    const recoveryPath = path.join(process.cwd(), 'CONTEXT-RECOVERY.md');
    fs.writeFileSync(recoveryPath, content, 'utf8');

    return recoveryPath;
  }

  /**
   * List available snapshots
   */
  async listSnapshots() {
    const files = fs.readdirSync(CONFIG.snapshotsDir)
      .filter(f => f.endsWith('.json'))
      .map(f => {
        const filePath = path.join(CONFIG.snapshotsDir, f);
        const snapshot = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        const stats = fs.statSync(filePath);

        return {
          id: snapshot.id,
          timestamp: snapshot.timestamp,
          size: stats.size,
          age: Date.now() - snapshot.timestamp
        };
      })
      .sort((a, b) => b.timestamp - a.timestamp);

    console.log('\n📋 Available Snapshots:\n');

    if (files.length === 0) {
      console.log('   No snapshots found');
      return [];
    }

    files.forEach((snapshot, index) => {
      const date = new Date(snapshot.timestamp).toLocaleString();
      const age = this.formatDuration(snapshot.age);
      const size = this.formatBytes(snapshot.size);

      console.log(`${index + 1}. ${snapshot.id}`);
      console.log(`   Created: ${date} (${age} ago)`);
      console.log(`   Size: ${size}\n`);
    });

    return files;
  }

  /**
   * Cleanup old snapshots
   */
  async cleanupOldSnapshots() {
    const files = fs.readdirSync(CONFIG.snapshotsDir)
      .filter(f => f.endsWith('.json'))
      .map(f => ({
        name: f,
        path: path.join(CONFIG.snapshotsDir, f),
        mtime: fs.statSync(path.join(CONFIG.snapshotsDir, f)).mtime.getTime()
      }))
      .sort((a, b) => b.mtime - a.mtime);

    // Keep only the most recent snapshots
    const toDelete = files.slice(CONFIG.maxSnapshots);

    for (const file of toDelete) {
      // Archive before deleting
      const archivePath = path.join(CONFIG.archiveDir, file.name);
      fs.renameSync(file.path, archivePath);
      console.log(`📦 Archived old snapshot: ${file.name}`);
    }

    // Cleanup very old archives
    await this.cleanupOldArchives();
  }

  /**
   * Cleanup old archives
   */
  async cleanupOldArchives() {
    const cutoff = Date.now() - (CONFIG.autoCleanupDays * 24 * 60 * 60 * 1000);

    const archives = fs.readdirSync(CONFIG.archiveDir)
      .filter(f => f.endsWith('.json'))
      .map(f => ({
        name: f,
        path: path.join(CONFIG.archiveDir, f),
        mtime: fs.statSync(path.join(CONFIG.archiveDir, f)).mtime.getTime()
      }));

    let deleted = 0;
    for (const archive of archives) {
      if (archive.mtime < cutoff) {
        fs.unlinkSync(archive.path);
        deleted++;
      }
    }

    if (deleted > 0) {
      console.log(`🗑️  Deleted ${deleted} old archive(s)`);
    }
  }

  /**
   * Find files by pattern
   */
  findFiles(dir, pattern) {
    const results = [];
    const files = fs.readdirSync(dir);

    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);

      if (stat.isDirectory()) {
        if (!file.startsWith('.') && file !== 'node_modules') {
          results.push(...this.findFiles(filePath, pattern));
        }
      } else {
        const regex = new RegExp(pattern.replace('*', '.*'));
        if (regex.test(file)) {
          results.push(filePath);
        }
      }
    }

    return results;
  }

  /**
   * Get recently modified files
   */
  getRecentlyModifiedFiles(hours) {
    const cutoff = Date.now() - (hours * 60 * 60 * 1000);
    const results = [];

    const walk = (dir) => {
      const files = fs.readdirSync(dir);

      for (const file of files) {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);

        if (stat.isDirectory()) {
          if (!file.startsWith('.') && file !== 'node_modules') {
            walk(filePath);
          }
        } else {
          if (stat.mtime.getTime() > cutoff) {
            results.push(filePath);
          }
        }
      }
    };

    walk(process.cwd());
    return results.slice(0, 20); // Limit to 20 files
  }

  /**
   * Calculate file checksum
   */
  calculateChecksum(content) {
    return crypto.createHash('md5').update(content).digest('hex');
  }

  /**
   * Format bytes to human readable
   */
  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  }

  /**
   * Format duration to human readable
   */
  formatDuration(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days} day${days > 1 ? 's' : ''}`;
    if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''}`;
    if (minutes > 0) return `${minutes} minute${minutes > 1 ? 's' : ''}`;
    return `${seconds} second${seconds > 1 ? 's' : ''}`;
  }
}

// CLI Interface
async function main() {
  const recovery = new ContextRecovery();
  const command = process.argv[2] || 'save';

  try {
    switch (command) {
      case 'save':
      case 'snapshot':
        await recovery.createSnapshot({
          trigger: 'manual',
          user: process.env.USER || 'unknown'
        });
        break;

      case 'restore':
        const snapshotId = process.argv[3];
        if (!snapshotId) {
          console.error('❌ Error: Please provide a snapshot ID');
          console.log('Usage: node context-recovery.js restore <snapshot-id>');
          process.exit(1);
        }
        await recovery.restoreSnapshot(snapshotId);
        break;

      case 'list':
        await recovery.listSnapshots();
        break;

      case 'clean':
        await recovery.cleanupOldSnapshots();
        console.log('✅ Cleanup complete');
        break;

      default:
        console.log(`
Context Recovery Hook

Usage:
  node context-recovery.js [command]

Commands:
  save, snapshot    Create a new snapshot (default)
  restore <id>      Restore from a snapshot
  list              List available snapshots
  clean             Cleanup old snapshots

Examples:
  node context-recovery.js save
  node context-recovery.js restore snapshot-2025-10-29-14-30-00
  node context-recovery.js list
        `);
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = ContextRecovery;
