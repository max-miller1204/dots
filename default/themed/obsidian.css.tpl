/* Dots theme for Obsidian */

.theme-dark, .theme-light {
  --background-primary: {{ background }};
  --background-primary-alt: {{ background }};
  --background-secondary: {{ dark_background }};
  --background-secondary-alt: {{ darker_background }};
  --text-normal: {{ foreground }};
  --text-selection: {{ selection_background }};
  --background-modifier-border: {{ muted }};

  --text-title-h1: {{ red }};
  --text-title-h2: {{ green }};
  --text-title-h3: {{ yellow }};
  --text-title-h4: {{ blue }};
  --text-title-h5: {{ magenta }};
  --text-title-h6: {{ magenta }};

  --text-link: {{ blue }};
  --text-accent: {{ accent }};
  --text-accent-hover: {{ bright_blue }};
  --interactive-accent: {{ accent }};
  --interactive-accent-hover: {{ bright_blue }};
  --text-muted: {{ dark_foreground }};
  --text-faint: {{ muted }};
  --code-normal: {{ cyan }};
  --text-error: {{ red }};
  --text-error-hover: {{ bright_red }};
  --text-success: {{ green }};
  --tag-color: {{ cyan }};
  --tag-background: {{ selection }};
  --graph-line: {{ muted }};
  --graph-node: {{ accent }};
  --graph-node-focused: {{ blue }};
  --graph-node-tag: {{ cyan }};
  --graph-node-attachment: {{ green }};
}

.cm-header-1, .markdown-rendered h1 { color: var(--text-title-h1); }
.cm-header-2, .markdown-rendered h2 { color: var(--text-title-h2); }
.cm-header-3, .markdown-rendered h3 { color: var(--text-title-h3); }
.cm-header-4, .markdown-rendered h4 { color: var(--text-title-h4); }
.cm-header-5, .markdown-rendered h5 { color: var(--text-title-h5); }
.cm-header-6, .markdown-rendered h6 { color: var(--text-title-h6); }
.markdown-rendered code { color: {{ cyan }}; }
.cm-s-obsidian span.cm-keyword { color: {{ red }}; }
.cm-s-obsidian span.cm-string { color: {{ green }}; }
.cm-s-obsidian span.cm-number { color: {{ yellow }}; }
.cm-s-obsidian span.cm-comment { color: {{ muted }}; }
.cm-s-obsidian span.cm-operator { color: {{ blue }}; }
.cm-s-obsidian span.cm-def { color: {{ blue }}; }
.markdown-rendered a { color: var(--text-link); }
.markdown-rendered blockquote { border-left-color: {{ accent }}; }
.workspace-leaf.mod-active .workspace-leaf-header-title,
.nav-file-title.is-active,
.search-result-file-title { color: var(--interactive-accent); }
