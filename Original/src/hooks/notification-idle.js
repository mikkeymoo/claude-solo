#!/usr/bin/env node
/**
 * claude-solo Notification hook (idle / awaiting-input state)
 *
 * Fires when Claude Code enters the idle/notification state — i.e. Claude has
 * finished responding and is awaiting user input.
 *
 * Use case: optional desktop notification via system tray / terminal bell
 * so you know when a long-running task finishes.
 *
 * Enable with:
 *   CLAUDE_SOLO_NOTIFY=1   → enable notifications
 *   CLAUDE_SOLO_NOTIFY=bell → use terminal bell only (default when enabled)
 *   CLAUDE_SOLO_NOTIFY=os   → use OS notification (requires `notify-send` / `osascript`)
 *
 * Input (stdin): JSON { session_id, message? }
 * Output: none
 */

import { createInterface } from 'readline';
import { execSync } from 'child_process';

const MODE = process.env.CLAUDE_SOLO_NOTIFY;
if (!MODE) process.exit(0);

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => (raw += line));

rl.on('close', () => {
  let input = {};
  try { input = JSON.parse(raw); } catch { /* ignore */ }

  const title = 'Claude Code';
  const body = input.message || 'Ready — awaiting your input';

  if (MODE === 'os') {
    try {
      const platform = process.platform;
      if (platform === 'darwin') {
        execSync(`osascript -e 'display notification "${body}" with title "${title}"'`);
      } else if (platform === 'linux') {
        execSync(`notify-send "${title}" "${body}"`);
      } else if (platform === 'win32') {
        // PowerShell toast (Windows 10+)
        execSync(
          `powershell -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null; $t = [Windows.UI.Notifications.ToastTemplateType]::ToastText01; $x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($t); $x.GetElementsByTagName('text')[0].AppendChild($x.CreateTextNode('${body}')) | Out-Null; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new($x))"`,
          { stdio: 'ignore' }
        );
      }
    } catch {
      // OS notification failed — fall through to bell
      process.stdout.write('\x07');
    }
  } else {
    // Default: terminal bell
    process.stdout.write('\x07');
  }
});
