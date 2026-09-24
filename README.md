# Storage Monitor — Website (`docs/`)

Three static, self-contained HTML pages that make up the project's public
site. No build step, no framework, no server — open any file directly in a
browser, or host the folder as-is via GitHub Pages.

## Pages

| File | Purpose | Style |
|---|---|---|
| `index.html` | Home page. Big overlapping "LINUX / SYSTEM REPORT" cover typography. | Cream / red / black |
| `dashboard.html` | Interactive sample dashboard: a CSS-only 3D pie chart of storage breakdown, stat cards, and a 7-day growth bar chart. | Cream / red / black |
| `product.html` | Marketing/feature page for the CLI toolkit itself: install instructions, feature grid. | Kinetic orange / black |

All three share the same navigation bar (`HOME` · `DASHBOARD` · `PRODUCT` ·
`GITHUB`), styled to match each page's own palette, with the current page
indicated.

## Important: the dashboard shows sample data

`dashboard.html` is a **static demo page** — it cannot read the visitor's
actual disk, since it runs in their browser, not their terminal. The numbers
and chart are representative sample data, clearly labeled with an on-page
notice. For real numbers from an actual machine, run the CLI toolkit's own
`generate-report` command, which produces a live HTML report from that
machine's real `df`/`du` output (see the main project README).



## Preview locally

```bash
open docs/index.html        # macOS
xdg-open docs/index.html    # Linux
```

Or just double-click any of the three files in Finder/Explorer/file manager.

## Deploy with GitHub Pages

1. Push the `docs/` folder to your repo's `main` branch.
2. In the repo on GitHub: **Settings → Pages → Source**, select the `main`
   branch and the `/docs` folder, then save.
3. The site goes live at `https://<your-username>.github.io/storage-monitor/`.

```bash
git add docs/
git commit -m "Update site"
git push
```

## Editing

- No build tools, bundlers, or `node_modules` — edit the HTML/CSS/JS
  directly in each file.
- Fonts (Anton, Archivo Black, IBM Plex Mono) load from Google Fonts via
  `<link>` tags; an internet connection is needed for fonts to render as
  designed, but the pages still function without one.
- `dashboard.html`'s sample data lives in a small `data` array near the
  bottom of the file's `<script>` block — edit the `label`/`value`/`color`
  fields there to change what the demo chart shows.
