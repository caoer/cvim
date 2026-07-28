# Markview styles, live

How markdown looks in cvim is markview's `markdown`, `markdown_inline` and
`preview` tables. This file is the console for them: put the cursor inside a
`lua` block below and press `g==`. The block runs **in this editor**, so the
style changes under you — no rebuild, no restart.

`g==` is neovim's own key for this, borrowed. Core binds it in help buffers
(`$VIMRUNTIME/ftplugin/help.lua`); `modules/zt/run-code-block.nix` adds the
markdown half. It runs `lua` and `vim` blocks only, and names any other
language back at you rather than guessing.

Two things to know before you start:

- `markview.setup()` **merges** — `vim.tbl_deep_extend("force", …)`. Applying a
  preset overwrites the keys it defines and leaves the rest of the previous
  one in place. When a combination starts looking odd, run the block under
  [Reset to your config](#reset-to-your-config).
- Nothing here survives `:q`. [Making a keeper permanent](#making-a-keeper-permanent)
  is how one becomes config.

## Your config

What this build passed to `markview.setup()` — generated from the evaluated
attrs by `modules/ui/markview.nix`, so it is your config even on a host that
overrides it through `extendModules`:

```lua
return require("cvim.markview").settings
```

What markview is holding right now, which drifts from the above as you run
blocks below:

```lua
return require("markview.spec").config.preview
```

The per-language defaults live outside that table until markview needs them:

```lua
return require("markview.config.markdown").headings.heading_1
```

## Headings

Edit the one word, then `g==`.

```lua
local preset = "simple" -- glow | glow_center | slanted | arrowed | simple | marker | numbered

require("markview").setup({
  markdown = { headings = require("markview.presets").headings[preset] },
})
vim.cmd("Markview Render")
```

Heading indent is separate from the preset:

```lua
require("markview").setup({
  markdown = { headings = { shift_width = 0 } }, -- 1 is the default: one space per level
})
vim.cmd("Markview Render")
```

## Checkboxes

Checkboxes are inline markup, so they live under `markdown_inline`.

```lua
local preset = "nerd" -- nerd | minimal | legacy

require("markview").setup({
  markdown_inline = { checkboxes = require("markview.presets").checkboxes[preset] },
})
vim.cmd("Markview Render")
```

- [ ] unchecked
- [x] checked
- [-] pending

## Fenced code blocks

```lua
require("markview").setup({
  markdown = {
    code_blocks = {
      style = "simple",          -- "block" draws a padded frame, "simple" only labels
      sign = false,              -- language icon in the sign column
      label_direction = "left",
      min_width = 60,
      pad_amount = 2,
    },
  },
})
vim.cmd("Markview Render")
```

## Tables and horizontal rules

```lua
local presets = require("markview.presets")

require("markview").setup({
  markdown = {
    tables = presets.tables.rounded,          -- none | single | double | rounded | solid
    horizontal_rules = presets.horizontal_rules.thin, -- thin | thick | double | dashed | dotted | solid | arrowed
  },
})
vim.cmd("Markview Render")
```

| what | preset |
|---|---|
| table borders | `rounded` |
| rule | `thin` |

---

## Block quotes and callouts

`obsidian` is the only shipped block-quote preset: it recolours the callout
set to markview's palette.

```lua
require("markview").setup({
  markdown = { block_quotes = require("markview.presets").block_quotes.obsidian },
})
vim.cmd("Markview Render")
```

> [!NOTE]
> A callout to look at while you flip presets.

## No nerd font

A full config, not a fragment — pass it to `setup` whole. This is the answer
for a terminal without a patched font, where every icon is a replacement box.

```lua
require("markview").setup(require("markview.presets").no_nerd_fonts)
vim.cmd("Markview Render")
```

## Seeing the raw markup while you edit

Hybrid mode un-renders the line the cursor is on, so you edit the real text
and read the render everywhere else.

```vim
Markview HybridToggle
```

Splitview renders into a second window instead of over the buffer:

```vim
Markview splitToggle
```

## Reset to your config

`setup()` only ever merges, so the way back is to drop the accumulated table
and re-apply the shipped one. Nothing here is a copy: the settings come from
the build, so this stays a true reset after `modules/ui/markview.nix` changes.

```lua
local spec = require("markview.spec")
spec.config = vim.deepcopy(spec.default)

require("markview").setup(require("cvim.markview").settings)
vim.cmd("Markview Render")
```

## The upstream reference, at the version cvim pins

markview ships its whole wiki inside the plugin, so the docs match the
plugin exactly and cannot drift. Open the markdown page — and `g==` works
there too, though its blocks are option fragments rather than runnable calls:

```lua
vim.cmd.edit(vim.api.nvim_get_runtime_file("markview.nvim.wiki/Markdown.md", false)[1])
```

Sibling pages: `Markdown inline.md`, `Preview.md`, `Presets.md`,
`Highlight groups.md`, `Usage.md`, `Configuration.md`.

## Making a keeper permanent

`modules/ui/markview.nix` owns the shipped config. `plugins.markview.settings`
is freeform, so anything above translates key-for-key; presets need `__raw`
because they are a lua call, not data.

```nix
plugins.markview.settings = {
  preview.icon_provider = "mini";
  markdown.headings.__raw = ''require("markview.presets").headings.glow'';
  markdown.code_blocks.style = "simple";
};
```

Per host, without touching this repo, the same attrs go through
`extendModules` — see the README's "Customizing a host".

`g==` refuses the block above, by name: it is nix, and nix does not run in an
editor.
