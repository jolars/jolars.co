const demo = document.getElementById("eunoia-demo");
const button = document.getElementById("eunoia-load");
const status = document.getElementById("eunoia-status");
const controls = document.getElementById("eunoia-controls");
const diagram = document.getElementById("eunoia-diagram");
const metrics = document.getElementById("eunoia-metrics");
const shape = document.getElementById("eunoia-shape");
const regions = [
  ["Adventure", "Adventure", 30, 20],
  ["Comedy", "Comedy", 30, 14],
  ["Drama", "Drama", 30, 18],
  ["Adventure&Comedy", "Adventure & Comedy", 15, 6],
  ["Adventure&Drama", "Adventure & Drama", 15, 5],
  ["Comedy&Drama", "Comedy & Drama", 15, 4],
  ["Adventure&Comedy&Drama", "All three", 10, 2],
];
let loading = false;
let attempt = 0;
let observer;

button.hidden = false;
status.textContent = "The static diagram shows the initial region sizes. Activate the demo to adjust them.";

async function activate() {
  if (loading) return;
  const activatedByButton = document.activeElement === button;
  loading = true;
  observer?.disconnect();
  button.disabled = true;
  status.textContent = "Loading the interactive demo…";

  try {
    // Browsers cache failed module loads, so retry with a fresh URL.
    const suffix = attempt++ ? `?retry=${attempt}` : "";
    const [web, svg] = await Promise.all([
      import(`https://cdn.jsdelivr.net/npm/@jolars/eunoia@1.4.0/web.js${suffix}`),
      import(`https://cdn.jsdelivr.net/npm/@jolars/eunoia@1.4.0/svg.js${suffix}`),
    ]);
    await web.init();
    const values = Object.fromEntries(regions.map(([key, , , value]) => [key, value]));

    function update() {
      try {
        const layout = web.euler({
          sets: values,
          shape: shape.value,
          output: "regions",
          inputType: "exclusive",
          seed: 1,
        });
        const container = document.createElement("div");
        container.innerHTML = svg.toSvg(layout, {
          fontFamily: "system-ui, sans-serif",
          setOrder: ["Adventure", "Comedy", "Drama"],
        });
        const image = container.querySelector("svg");
        image.setAttribute("width", "100%");
        image.removeAttribute("height");
        image.style.height = "auto";
        image.setAttribute("role", "img");
        image.setAttribute("aria-label", `Euler diagram using ${shape.value} shapes. Exclusive region sizes: ${regions.map(([key, label]) => `${label} ${values[key]}`).join(", ")}.`);
        diagram.replaceChildren(image);
        metrics.textContent = `Loss: ${layout.metrics.loss.toFixed(5)} · diagError: ${layout.metrics.diagError.toFixed(5)}—both closer to zero is better.`;
        status.textContent = "Interactive demo ready. Adjust the region sizes or shape below.";
        return true;
      } catch (error) {
        status.textContent = "These region sizes could not be fitted. Try another size or shape.";
        console.error(error);
        return false;
      }
    }

    const rows = regions.map(([key, label, max, value], index) => {
      const row = document.createElement("div");
      row.className = "mb-3";
      const id = `eunoia-region-${index}`;
      row.innerHTML = `<label id="${id}-label" for="${id}">${label}</label>
        <div style="display: flex; align-items: center; gap: 1rem;">
          <input id="${id}" type="range" min="0" max="${max}" step="1" value="${value}" style="flex: 1; min-width: 0;" aria-labelledby="${id}-label">
          <input type="number" min="0" max="${max}" step="1" value="${value}" style="width: 5rem;" class="form-control" aria-labelledby="${id}-label">
        </div>`;
      const [range, number] = row.querySelectorAll("input");
      for (const input of [range, number]) {
        input.addEventListener("input", () => {
          if (!input.validity.valid || input.value === "") return;
          values[key] = input.valueAsNumber;
          range.value = number.value = input.value;
          update();
        });
      }
      return row;
    });
    if (!update()) throw new Error("The initial diagram could not be fitted.");
    document.getElementById("eunoia-ranges").replaceChildren(...rows);
    shape.onchange = update;
    controls.onsubmit = (event) => event.preventDefault();
    controls.hidden = false;
    metrics.hidden = false;
    // Restore keyboard focus after a manual load, without moving it during automatic loading.
    button.textContent = "Interactive demo loaded";
    button.disabled = false;
    button.setAttribute("aria-expanded", "true");
    button.onclick = () => shape.focus();
    if (activatedByButton) button.focus();
  } catch (error) {
    loading = false;
    button.disabled = false;
    button.textContent = "Retry interactive demo";
    status.textContent = "The interactive demo could not load. The static diagram remains available; activate the button to retry.";
    if (activatedByButton) button.focus();
    console.error(error);
  }
}

button.onclick = activate;
if ("IntersectionObserver" in window) {
  observer = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) activate();
  }, { rootMargin: "300px" });
  observer.observe(demo);
}
