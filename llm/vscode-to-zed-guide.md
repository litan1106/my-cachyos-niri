# Reproducing a VS Code Setup in Zed

A step-by-step guide to configuring [Zed](https://zed.dev) to feel like home if you're coming from Visual Studio Code.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Set the Base Keymap](#2-set-the-base-keymap)
3. [Configure Settings](#3-configure-settings)
4. [Configure Keybindings](#4-configure-keybindings)
5. [Install Extensions & Themes](#5-install-extensions--themes)
6. [VS Code → Zed Concepts](#6-vs-code--zed-concepts)
7. [Keybinding Cheat Sheet](#7-keybinding-cheat-sheet)
8. [Known Differences](#8-known-differences)

---

## 1. Prerequisites

- **Install Zed**: [zed.dev/download](https://zed.dev/download) or via your package manager
- **Install a Nerd Font** (optional but recommended):
  ```bash
  # Example: JetBrainsMono Nerd Font
  # Download from https://www.nerdfonts.com/font-downloads
  # Or via package manager
  ```

### Config File Locations

| File | Path |
|---|---|
| Zed Settings | `~/.config/zed/settings.json` |
| Zed Keybindings | `~/.config/zed/keymap.json` |
| VS Code Settings | `~/.config/Code/User/settings.json` |
| VS Code Keybindings | `~/.config/Code/User/keybindings.json` |

> [!TIP]
> Open Zed settings quickly with `ctrl+,` and keymap with `ctrl+k ctrl+s` (when using VSCode base keymap).

---

## 2. Set the Base Keymap

The single most important setting — this gives you all default VS Code shortcuts out of the box:

```jsonc
// ~/.config/zed/settings.json
{
  "base_keymap": "VSCode"
}
```

This maps `ctrl+p` → file finder, `ctrl+shift+p` → command palette, `ctrl+/` → toggle comment, and hundreds more automatically.

---

## 3. Configure Settings

Below is the full `settings.json` with annotations explaining each VS Code equivalent.

Copy this to `~/.config/zed/settings.json`:

```jsonc
{
  // ─── Panel Layout ──────────────────────────────────────────────
  // VS Code: Activity Bar on left, panels in sidebar
  "project_panel": { "dock": "left" },          // File explorer → left
  "outline_panel": { "dock": "left" },           // Outline → left
  "git_panel": {
    "file_icons": false,
    "button": true,
    "dock": "left"                               // Source control → left
  },
  "collaboration_panel": {
    "button": false,
    "dock": "left"
  },
  "agent": {
    "dock": "right",                             // AI panel → right
    "favorite_models": [],
    "model_parameters": []
  },
  "debugger": { "dock": "bottom" },              // Debug → bottom

  // ─── Appearance ────────────────────────────────────────────────
  // VS Code: workbench.colorTheme, editor.fontFamily, editor.fontSize
  "theme": "VSCode Dark Modern",                 // Or "One Dark", "Ayu Dark", etc.
  "icon_theme": "Zed (Default)",
  "show_menu_bar": "always",                     // Show File/Edit/View menu bar
  "ui_font_family": "JetBrainsMono Nerd Font",
  "buffer_font_family": "JetBrainsMono Nerd Font",
  "buffer_font_size": 16.0,

  // ─── Editor Behavior ──────────────────────────────────────────
  // VS Code: editor.wordWrap, editor.minimap.enabled, editor.autoClosingBrackets
  "soft_wrap": "editor_width",                   // editor.wordWrap: "on"
  "minimap": { "show": "never" },                // editor.minimap.enabled: false
  "use_autoclose": false,                        // editor.autoClosingBrackets: "never"
  "show_edit_predictions": true,                 // editor.inlineSuggest.enabled: true
  "line_ending": "prefer_lf",                    // files.eol: "\n"

  // ─── Base Keymap ───────────────────────────────────────────────
  "base_keymap": "VSCode",

  // ─── Session & Trust ───────────────────────────────────────────
  "session": { "trust_all_worktrees": true },

  // ─── Terminal ──────────────────────────────────────────────────
  // VS Code: terminal.integrated.fontSize, terminal.integrated.copyOnSelection
  "terminal": {
    "font_size": 16.0,
    "copy_on_select": true,
    "shell": { "program": "bash" }               // terminal.integrated.defaultProfile.linux
  },

  // ─── Tabs & Preview ───────────────────────────────────────────
  // VS Code: workbench.editor.enablePreview
  "preview_tabs": {
    "enabled": false,                            // Disable preview tabs (single-click opens)
    "enable_preview_from_file_finder": true,
    "enable_keep_preview_on_code_navigation": true
  },

  // ─── Auto Save ─────────────────────────────────────────────────
  // VS Code: files.autoSave: "afterDelay", files.autoSaveDelay: 5000
  "autosave": {
    "after_delay": { "milliseconds": 5000 }
  },

  // ─── File Associations ─────────────────────────────────────────
  // VS Code: files.associations
  "file_types": {
    "dotenv": [".env.*"],
    "dockercompose": ["docker-compose.*.yml"],
    "azure-pipelines": ["azure-pipeline*.yml", "**/pipelines/**/*.yml"],
    "plaintext": [".databrickscfg"]
  },

  // ─── Search Exclusions ─────────────────────────────────────────
  // VS Code: search.exclude
  "file_scan_exclusions": [
    "**/node_modules",
    "**/.venv",
    "**/vendor",
    "**/obj",
    "**/bin/Debug",
    "**/bin/Release",
    "**/dist",
    "**/build",
    "**/.git",
    "**/.DS_Store"
  ],

  // ─── Python / Ruff Integration ─────────────────────────────────
  // VS Code: ruff.nativeServer, editor.codeActionsOnSave, [python].editor.formatOnType
  "code_actions_on_format": {
    "source.fixAll.ruff": true,
    "source.organizeImports.ruff": true
  },
  "languages": {
    "Python": {
      "format_on_type": "on",
      "language_servers": ["pyright", "ruff"]     // Replaces Pylance + Ruff extensions
    }
  },

  // ─── AI / Agent Servers ────────────────────────────────────────
  "agent_servers": {
    "claude-acp": { "type": "registry" }
  }
}
```

---

## 4. Configure Keybindings

Create `~/.config/zed/keymap.json` with the following custom bindings. These override the VSCode base keymap with IntelliJ-inspired shortcuts:

```jsonc
[
  // =============================================
  // Navigation & Panels
  // =============================================

  // alt+1 → Toggle explorer / project panel
  // VS Code: workbench.view.explorer
  {
    "bindings": {
      "alt-1": "workspace::ToggleLeftDock"
    }
  },
  // alt+2 → Git panel
  // VS Code: workbench.view.scm
  {
    "bindings": {
      "alt-2": "git_panel::ToggleFocus"
    }
  },
  // alt+3 → Debug panel
  // VS Code: workbench.view.debug
  {
    "bindings": {
      "alt-3": "debugger::ToggleFocus"
    }
  },
  // alt+0 → Toggle terminal
  // VS Code: workbench.action.terminal.toggleTerminal
  {
    "bindings": {
      "alt-0": "workspace::ToggleBottomDock"
    }
  },
  // alt+f12 → New terminal tab
  // VS Code: workbench.action.createTerminalEditor
  {
    "bindings": {
      "alt-f12": "terminal_panel::NewTerminal"
    }
  },
  // ctrl+shift+n → Quick open file
  // VS Code: workbench.action.quickOpen (remapped from ctrl+p)
  {
    "bindings": {
      "ctrl-shift-n": "file_finder::Toggle"
    }
  },
  // ctrl+e → Open recent projects
  // VS Code: workbench.action.openRecent (remapped from ctrl+r)
  {
    "bindings": {
      "ctrl-e": "projects::OpenRecent"
    }
  },
  // ctrl+shift+a → Command palette
  // VS Code: workbench.action.showCommands (remapped from ctrl+shift+p)
  {
    "bindings": {
      "ctrl-shift-a": "command_palette::Toggle"
    }
  },

  // =============================================
  // Editor – Editing Actions
  // =============================================
  {
    "context": "Editor && !menu",
    "bindings": {
      // ctrl+d → Duplicate line down
      // VS Code: editor.action.copyLinesDownAction (remapped from shift+alt+down)
      "ctrl-d": "editor::DuplicateLineDown",

      // alt+j → Select next occurrence
      // VS Code: editor.action.addSelectionToNextFindMatch (remapped from ctrl+d)
      "alt-j": "editor::SelectNext",

      // ctrl+shift+u → Transform to uppercase
      // VS Code: editor.action.transformToUppercase
      "ctrl-shift-u": "editor::ConvertToUpperCase",

      // ctrl+shift+l → Transform to lowercase
      // VS Code: editor.action.transformToLowercase
      "ctrl-shift-l": "editor::ConvertToLowerCase",

      // ctrl+shift+/ → Toggle block comment
      // VS Code: editor.action.blockComment (remapped from shift+alt+a)
      "ctrl-shift-/": "editor::ToggleComments",

      // shift+f6 → Rename symbol
      // VS Code: editor.action.rename (remapped from f2)
      "shift-f6": "editor::Rename",

      // alt+enter → Code actions / quick fix
      // VS Code: editor.action.quickFix (remapped from ctrl+.)
      "alt-enter": "editor::ToggleCodeActions",

      // ctrl+b → Go to definition/declaration
      // VS Code: editor.action.revealDeclaration
      "ctrl-b": "editor::GoToDefinition",

      // ctrl+shift+i → Peek definition in split
      // VS Code: editor.action.peekDefinition (remapped from alt+f12)
      "ctrl-shift-i": "editor::GoToDefinitionSplit",

      // ctrl+alt+b → Go to implementation
      // VS Code: editor.action.goToImplementation (remapped from ctrl+f12)
      "ctrl-alt-b": "editor::GoToImplementation",

      // ctrl+up/down → Paragraph navigation
      // VS Code: cursorMove by 10 lines (no direct Zed equivalent)
      "ctrl-up": "editor::MoveToStartOfParagraph",
      "ctrl-down": "editor::MoveToEndOfParagraph"
    }
  },

  // =============================================
  // Save All on ctrl+s
  // =============================================
  // VS Code: workbench.action.files.saveAll (remapped from ctrl+k s)
  {
    "bindings": {
      "ctrl-s": "workspace::SaveAll"
    }
  },

  // =============================================
  // Search & Replace
  // =============================================
  // ctrl+shift+r → Project-wide search & replace
  // VS Code: workbench.action.replaceInFiles (remapped from ctrl+shift+h)
  {
    "bindings": {
      "ctrl-shift-r": "pane::DeploySearch"
    }
  },
  // f3 / shift+f3 → Next/prev match in search bar
  {
    "context": "BufferSearchBar",
    "bindings": {
      "f3": "search::SelectNextMatch",
      "shift-f3": "search::SelectPrevMatch"
    }
  },
  // f3 / shift+f3 → Next/prev match in editor
  {
    "context": "Editor && !menu",
    "bindings": {
      "f3": "search::SelectNextMatch",
      "shift-f3": "search::SelectPrevMatch"
    }
  },

  // =============================================
  // Tab / Pane Management
  // =============================================
  {
    "bindings": {
      // alt+a → Close all editors
      // VS Code: workbench.action.closeAllEditors
      "alt-a": "pane::CloseAllItems",

      // alt+w → Close editors in group
      // VS Code: workbench.action.closeEditorsInGroup
      "alt-w": "pane::CloseAllItems"
    }
  },

  // =============================================
  // Debugging
  // =============================================
  {
    "bindings": {
      // VS Code: workbench.action.debug.start (remapped from f5)
      "shift-f9": "debugger::Start",
      // VS Code: workbench.action.debug.stepOver (remapped from f10)
      "f8": "debugger::StepOver",
      // VS Code: workbench.action.debug.stepInto (remapped from f11)
      "f7": "debugger::StepInto",
      // VS Code: workbench.action.debug.stepOut (remapped from shift+f11)
      "shift-f8": "debugger::StepOut",
      // VS Code: workbench.action.debug.continue (remapped from f5)
      "f9": "debugger::Continue",
      // VS Code: workbench.action.debug.restart (remapped from ctrl+shift+f5)
      "ctrl-f5": "debugger::Restart"
    }
  },

  // =============================================
  // Markdown Preview
  // =============================================
  {
    "context": "Editor && (extension == md || extension == markdown)",
    "bindings": {
      // VS Code: markdown.showPreviewToSide (remapped from ctrl+k v)
      "alt-d": "markdown::OpenPreviewToTheSide"
    }
  }
]
```

---

## 5. Install Extensions & Themes

Open Zed's extension panel with the command palette (`ctrl+shift+a` → "Extensions") and search for:

### Themes

| VS Code Theme | Zed Extension to Install |
|---|---|
| Dark Modern (VS Code default) | `VSCode Dark Modern` (search "vscode dark") |
| Tokyo Night | `Tokyo Night` |
| Catppuccin | `Catppuccin` |
| Rosé Pine | `Rosé Pine` |
| One Dark | Built-in — no install needed |

### Language Support

| VS Code Extension | Zed Equivalent |
|---|---|
| Python (`ms-python.python`) | **Built-in** — Python support included |
| Pylance (`ms-python.vscode-pylance`) | **Built-in** — configure `pyright` in language_servers |
| Ruff (`charliermarsh.ruff`) | **Built-in** — configure in `languages.Python.language_servers` |
| YAML (`redhat.vscode-yaml`) | **Built-in** — YAML support included |
| Docker (`ms-azuretools.vscode-docker`) | Install `Docker` extension or use terminal |
| Markdown Preview | **Built-in** — `alt+d` with our keymap |
| Spell Checker | Not yet available in Zed |

> [!NOTE]
> Zed has many language servers built-in that require extensions in VS Code. Check the command palette for available language support before installing extensions.

---

## 6. VS Code → Zed Concepts

A mapping of terminology and UI concepts:

| VS Code Concept | Zed Equivalent |
|---|---|
| Activity Bar (left icons) | No equivalent (use keyboard shortcuts) |
| Sidebar | Left/Right **Dock** |
| Panel (bottom) | Bottom **Dock** |
| Settings UI | No GUI — edit `settings.json` directly |
| Extensions Marketplace | Extensions panel (command palette → "Extensions") |
| `settings.json` | `~/.config/zed/settings.json` |
| `keybindings.json` | `~/.config/zed/keymap.json` |
| Command Palette (`ctrl+shift+p`) | Command Palette (`ctrl+shift+p` or custom) |
| Quick Open (`ctrl+p`) | File Finder (`ctrl+p` or custom) |
| Workspace Settings (`.vscode/`) | Project settings (`.zed/settings.json`) |
| `tasks.json` | Zed Tasks (`.zed/tasks.json`) |
| `launch.json` | Zed Debug configs (`.zed/debug.json`) |
| Integrated Terminal | Terminal panel (bottom dock) |
| Source Control view | Git panel |
| Peek Definition | Go to Definition Split |
| IntelliSense | Edit Predictions + Completions |

---

## 7. Keybinding Cheat Sheet

### Panels & Navigation

| Shortcut | Action |
|---|---|
| `alt+1` | Toggle file explorer |
| `alt+2` | Toggle git panel |
| `alt+3` | Toggle debug panel |
| `alt+0` | Toggle terminal |
| `alt+f12` | New terminal tab |
| `ctrl+shift+a` | Command palette |
| `ctrl+shift+n` | Quick open file |
| `ctrl+e` | Open recent projects |

### Editing

| Shortcut | Action |
|---|---|
| `ctrl+s` | Save all files |
| `ctrl+d` | Duplicate line down |
| `alt+j` | Select next occurrence |
| `ctrl+shift+u` | UPPERCASE selection |
| `ctrl+shift+l` | lowercase selection |
| `ctrl+shift+/` | Toggle block comment |
| `ctrl+up` | Jump to start of paragraph |
| `ctrl+down` | Jump to end of paragraph |

### Code Navigation

| Shortcut | Action |
|---|---|
| `ctrl+b` | Go to definition |
| `ctrl+shift+i` | Peek definition (split) |
| `ctrl+alt+b` | Go to implementation |
| `shift+f6` | Rename symbol |
| `alt+enter` | Code actions / quick fix |

### Search

| Shortcut | Action |
|---|---|
| `ctrl+shift+r` | Project search & replace |
| `f3` | Next search match |
| `shift+f3` | Previous search match |

### Tabs

| Shortcut | Action |
|---|---|
| `alt+a` | Close all tabs |
| `alt+w` | Close tabs in group |

### Debugging

| Shortcut | Action |
|---|---|
| `shift+f9` | Start debugging |
| `f8` | Step over |
| `f7` | Step into |
| `shift+f8` | Step out |
| `f9` | Continue |
| `ctrl+f5` | Restart |

### Markdown

| Shortcut | Action |
|---|---|
| `alt+d` | Preview markdown (side-by-side) |

---

## 8. Known Differences

Things that work differently in Zed and **cannot** be configured to match VS Code:

| Feature | VS Code | Zed |
|---|---|---|
| **Activity Bar** | Vertical icon bar on left side | No equivalent — use shortcuts |
| **Settings UI** | GUI settings editor | JSON only |
| **Move N lines** | `cursorMove` with `value: 10` | Not supported — use paragraph nav |
| **Preview tabs** | Single-click = preview, double-click = keep | Can disable, but behavior differs |
| **Diff editor** | Side-by-side toggle available | Inline only |
| **Workspace trust** | Per-workspace prompt | Global `trust_all_worktrees` setting |
| **Multi-root workspaces** | `.code-workspace` files | Open multiple folders directly |
| **Remote SSH** | Remote-SSH extension | Zed remote (built-in, different UX) |
| **Extension ecosystem** | ~50,000+ extensions | Growing but much smaller |

> [!TIP]
> Zed is evolving fast. Features that are missing today may be added soon.
> Check [Zed's GitHub issues](https://github.com/zed-industries/zed/issues) for feature requests.
