# Markview styles, live

How markdown looks in cvim is markview's `markdown`, `markdown_inline` and
`preview` tables. This file is the console for them: put the cursor inside a
`lua` block below and press `g==`. The block runs **in this editor**, so the
style changes under you — no rebuild, no restart.

`g==` is neovim's own key for this, borrowed. Core binds it in help buffers
(`$VIMRUNTIME/ftplugin/help.lua`); `modules/zt/run-code-block.nix` adds the
markdown half. It runs `lua` and `vim` blocks only, and names any other
language back at you rather than guessing.

`gO` lists every heading here as an outline and jumps to the one you pick;
`]]` and `[[` step between them. Both are neovim's own markdown bindings, and
`<leader>xs` opens the same thing as a live sidebar.

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

## The whole surface

The sections below are a slice: a preset only ever sets the keys it cares
about, and every element has more. The full set is in the plugin, so read it
from there rather than from a list in this file that would be wrong the first
time cvim's pin moves.

Element names, per language:

```lua
local out = {}

for _, namespace in ipairs({ "markdown", "markdown_inline", "html", "latex", "typst", "yaml" }) do
  out[namespace] = vim.tbl_keys(require("markview.config." .. namespace))
  table.sort(out[namespace])
end

return out
```

Every option of one element, with the value it ships with — edit the two
words. This is the answer to "what else can I set here":

```lua
local namespace, element = "markdown", "tables"

return require("markview.config." .. namespace)[element]
```

And the prose for that element, from markview's own wiki at the pinned
version:

```lua
local page, element = "Markdown", "tables"

vim.cmd.edit(vim.api.nvim_get_runtime_file("markview.nvim.wiki/" .. page .. ".md", false)[1])
vim.fn.search("^## " .. element, "w")
```

## Headings

Edit the one word, then `g==`.

```lua
local preset = "slanted" -- glow | glow_center | slanted | arrowed | simple | marker | numbered

require("markview").setup({
  markdown = { headings = require("markview.presets").headings[preset] },
})
vim.cmd("Markview Render")
```

Heading indent is separate from the preset:

```lua
require("markview").setup({
  markdown = { headings = { shift_width = 1 } }, -- 1 is the default: one space per level
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

## List items

No presets here — the markers are set piece by piece.

```lua
require("markview").setup({
  markdown = {
    list_items = {
      shift_width = 4,  -- columns of indent added per nesting level
      wrap = true,      -- continuation lines line up under the text

      marker_minus = { text = "●", hl = "MarkviewListItemMinus", add_padding = true },
      marker_plus = { text = "◈", hl = "MarkviewListItemPlus", add_padding = true },
      marker_star = { text = "◇", hl = "MarkviewListItemStar", add_padding = true },
      -- marker_dot and marker_parenthesis take a function: (buffer, item) -> string
    },
  },
})
vim.cmd("Markview Render")
```

- minus

* star

1. dot
1) parenthesis

## Fenced code blocks

```lua
require("markview").setup({
  markdown = {
    code_blocks = {
      style = "simple",          -- "block" draws a padded frame, "simple" only labels
      sign = true,              -- language icon in the sign column
      label_direction = "right",
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
    tables = presets.tables.double,          -- none | single | double | rounded | solid
    horizontal_rules = presets.horizontal_rules.thick, -- thin | thick | double | dashed | dotted | solid | arrowed
  },
})
vim.cmd("Markview Render")
```

| what | preset |
|---|---|
| table borders | `rounded` |
| rule | `thin` |

A table preset is only `parts` and `hl`. Both are editable piece by piece, and
the three switches above them are not preset material at all:

```lua
require("markview").setup({
  markdown = {
    tables = {
      block_decorator = true,  -- draw the top and bottom borders
      use_virt_lines = false,  -- true puts those borders on virtual lines
      strict = false,          -- true drops leading/trailing cell whitespace

      parts = {
        top = { "┌", "─", "┐", "┬" },       -- left, fill, right, junction
        header = { "│", "│", "│" },         -- left, separator, right
        separator = { "├", "─", "┤", "┼" },
        row = { "│", "│", "│" },
        bottom = { "└", "─", "┘", "┴" },
        overlap = { "┝", "━", "┥", "┿" },   -- where a row meets a merged cell
        align_left = "╼",
        align_right = "╾",
        align_center = { "╴", "╶" },
      },

      hl = { -- same shape as parts, one highlight group per piece
        row = { "MarkviewTableBorder", "MarkviewTableBorder", "MarkviewTableBorder" },
      },
    },
  },
})
vim.cmd("Markview Render")
```

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

## Front matter

The block fenced by `---` at the top of a file. `metadata_minus` is the YAML
one, `metadata_plus` the TOML one; they take the same keys.

```lua
require("markview").setup({
  markdown = {
    metadata_minus = {
      hl = "MarkviewCode",
      border_hl = "MarkviewCodeFg",
      border_top = "▄",
      border_bottom = "▀",
    },
  },
})
vim.cmd("Markview Render")
```

## Inline markup

Links, images, inline code, footnotes and highlights live under
`markdown_inline`. Each takes a `default` table plus per-pattern overrides
keyed by a lua pattern — that is how markview gives `github.com/…` and `.png`
their own icons, and how you would add your own.

```lua
require("markview").setup({
  markdown_inline = {
    inline_codes = { hl = "MarkviewInlineCode", padding_left = " ", padding_right = " " },
    hyperlinks = {
      default = { icon = "󰌷 ", hl = "MarkviewHyperlink" },
      ["^https://github%.com/"] = { icon = " " },
    },
    images = { default = { icon = "󰥶 ", hl = "MarkviewImage" } },
    highlights = { default = { hl = "MarkviewPalette3", padding_left = " ", padding_right = " " } },
  },
})
vim.cmd("Markview Render")
```

`inline code`, a [link](https://github.com/OXY2DEV/markview.nvim), and
==highlighted text== to watch.

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

Which modes render, and when markview gives up, are `preview` keys rather than
commands:

```lua
require("markview").setup({
  preview = {
    modes = { "n", "no", "c" },     -- modes that render at all
    hybrid_modes = {},              -- modes where the cursor's node un-renders
    linewise_hybrid_mode = false,   -- true un-renders the whole line instead
    max_buf_lines = 1000,           -- above this, only the drawn range is done
    debounce = 150,                 -- ms after a change before redrawing
    filetypes = { "markdown", "quarto", "rmd", "typst", "asciidoc" },
    ignore_buftypes = { "nofile" },
  },
})
vim.cmd("Markview Render")
```

## Colours

Rendering draws with highlight groups and takes the colours from the
colorscheme — which is why the render follows cvim's day/night flip. Override
one group live:

```lua
vim.api.nvim_set_hl(0, "MarkviewHeading1", { fg = "#ff9e64", bold = true })
vim.cmd("Markview Render")
```

An override like that lasts until the next colorscheme load, which is every
appearance flip.

Every group markview has defined in this session:

```lua
local names = {}

for name in pairs(vim.api.nvim_get_hl(0, {})) do
  if name:find("^Markview") then
    names[#names + 1] = name
  end
end

table.sort(names)
return names
```

## Dimming the render

Backgrounds are computed rather than read: markview takes `Normal`'s background
and lightens it per element. Three globals say how far. None of them touches a
foreground, and lower is dimmer.

| global | what it tints | default here |
|---|---|---|
| `markview_alpha` | headings, callouts, checkboxes, highlights | `0.15` |
| `markview_code_alpha` | fenced code blocks | `0.15` |
| `markview_inline_code_alpha` | inline code | `0.2` |

The first mixes `Normal`'s background toward the element's own foreground in
Oklab; the other two scale that background's lightness by `1 + alpha` and leave
the hue alone. The defaults above are markview's dark branch, read off
tokyonight-night.

Setting a global and calling setup again changes nothing on its own —
`highlights.set_hl` returns early on a group that already exists. Blank
markview's groups first:

```lua
vim.g.markview_alpha = 0.08
vim.g.markview_code_alpha = 0.06
vim.g.markview_inline_code_alpha = 0.1

for name in pairs(vim.api.nvim_get_hl(0, {})) do
  if name:find("^Markview") then
    vim.api.nvim_set_hl(0, name, {})
  end
end

require("markview.highlights").setup()
vim.cmd("Markview Render")
```

A colorscheme load clears every group and markview recomputes on `ColorScheme`,
so a global survives the day/night flip where an `nvim_set_hl` override does
not.

The ink is the colorscheme's, not markview's: heading foregrounds come from
`@markup.heading.N.markdown`, inline code from `@markup.raw`. Dimming those is
`tokyonight.on_highlights` in `modules/ui/theme.nix`, and it moves the colour
everywhere rather than only in markdown.

## Reset to your config

`setup()` only ever merges, so the way back is to drop the accumulated table
and re-apply the shipped one. Nothing here is a copy: the settings come from
the build, so this stays a true reset after `modules/ui/markview.nix` changes.
It resets the settings table only — an alpha you set above lives in `vim.g` and
survives it.

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

The alphas are not settings — markview reads them off `vim.g` — so they go into
the same file as globals:

```nix
globals.markview_alpha = 0.08;
```

Per host, without touching this repo, the same attrs go through
`extendModules` — see the README's "Customizing a host".

`g==` refuses both blocks above, by name: they are nix, and nix does not run in
an editor.
