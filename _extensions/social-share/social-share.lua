-- Minimal social-share filter.
--
-- Reads a `share` field from document metadata and appends a row of share
-- buttons to the END of the document body, so the buttons flow inside the
-- article's content column instead of being dumped after the page footer.
--
-- The share URL is resolved client-side from <link rel="canonical"> (Quarto
-- emits this when `canonical-url: true`) with a window.location fallback, so no
-- per-post permalink is needed.
--
-- Frontmatter:
--   share: true            # mastodon + bluesky + copy link
--   share:
--     mastodon: true
--     bluesky: true        # or: bsky: true
--     copy: false          # copy-link button, on by default

local function truthy(v)
  if v == nil then return false end
  if type(v) == "boolean" then return v end
  local s = pandoc.utils.stringify(v):lower()
  return s == "true" or s == "yes" or s == "1"
end

-- Read a key with a default, since some buttons are opt-out rather than opt-in.
local function flag(map, key, default)
  if map[key] == nil then return default end
  return truthy(map[key])
end

local BUTTONS = {
  bluesky = '<a class="social-share__btn social-share__btn--bluesky" '
    .. 'href="#" data-social-share="bluesky" rel="noopener" '
    .. 'aria-label="Share on Bluesky" title="Share on Bluesky">'
    .. '<i class="fa-brands fa-bluesky" aria-hidden="true"></i></a>',
  mastodon = '<a class="social-share__btn social-share__btn--mastodon" '
    .. 'href="#" data-social-share="mastodon" rel="noopener" '
    .. 'aria-label="Share on Mastodon" title="Share on Mastodon">'
    .. '<i class="fa-brands fa-mastodon" aria-hidden="true"></i></a>',
  copy = '<button class="social-share__btn social-share__btn--copy" '
    .. 'type="button" data-social-share="copy" '
    .. 'aria-label="Copy link" title="Copy link">'
    .. '<i class="fa-solid fa-link" aria-hidden="true"></i></button>',
}

function Pandoc(doc)
  if not quarto.doc.isFormat("html:js") then
    return doc
  end

  local share = doc.meta.share
  if share == nil then
    return doc
  end

  -- Skip listing pages (e.g. the blog index): they inherit `share` from
  -- _metadata.yml but are not articles, so they should not get share buttons.
  if doc.meta.listing ~= nil then
    return doc
  end

  local want = {}
  if type(share) == "boolean" or pandoc.utils.type(share) == "Inlines" then
    -- `share: true` (or any scalar) enables everything.
    if truthy(share) then
      want = { bluesky = true, mastodon = true, copy = true }
    end
  else
    -- `share:` map of per-network toggles.
    want = {
      bluesky = flag(share, "bluesky", false) or flag(share, "bsky", false),
      mastodon = flag(share, "mastodon", false),
      copy = flag(share, "copy", true),
    }
  end

  local order = { "bluesky", "mastodon", "copy" }
  local parts = {}
  for _, key in ipairs(order) do
    if want[key] then
      parts[#parts + 1] = BUTTONS[key]
    end
  end

  if #parts == 0 then
    return doc
  end

  quarto.doc.addHtmlDependency({
    name = "social-share",
    version = "1.0.0",
    stylesheets = { "social-share.css" },
    scripts = { "social-share.js" },
  })

  local html = '<nav class="social-share" aria-label="Share this page">'
    .. '<span class="social-share__label">Share</span>'
    .. '<div class="social-share__buttons">'
    .. table.concat(parts)
    .. "</div>"
    .. "</nav>"

  table.insert(doc.blocks, pandoc.RawBlock("html", html))
  return doc
end
