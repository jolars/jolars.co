import { writeFile } from "node:fs/promises";

// Match the pinned engine and initial values in the article's interactive demo.
const base = "https://cdn.jsdelivr.net/npm/@jolars/eunoia@1.4.0/";
const modules = await Promise.all(["web.js", "svg.js"].map(async (name) => {
  const response = await fetch(new URL(name, base));
  if (!response.ok) throw new Error(`Could not download ${name}: ${response.status}`);
  const source = Buffer.from(await response.text()).toString("base64");
  return import(`data:text/javascript;base64,${source}`);
}));
const [web, svg] = modules;
await web.init();
const layout = web.euler({
  sets: {
    Adventure: 20,
    Comedy: 14,
    Drama: 18,
    "Adventure&Comedy": 6,
    "Adventure&Drama": 5,
    "Comedy&Drama": 4,
    "Adventure&Comedy&Drama": 2,
  },
  shape: "ellipse",
  output: "regions",
  inputType: "exclusive",
  seed: 1,
});
await writeFile(new URL("../blog/2026-07-04-eunoia/images/demo.svg", import.meta.url), svg.toSvg(layout, {
  fontFamily: "system-ui, sans-serif",
  setOrder: ["Adventure", "Comedy", "Drama"],
}));
