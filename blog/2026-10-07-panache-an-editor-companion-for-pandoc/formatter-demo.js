const demo = document.getElementById("panache-demo");
const input = demo.querySelector("#panache-demo-input");
const output = demo.querySelector("#panache-demo-output");
const width = demo.querySelector("#panache-demo-width");
const wrap = demo.querySelector("#panache-demo-wrap");
const math = demo.querySelector("#panache-demo-math");
const status = demo.querySelector("#panache-demo-status");
const copy = demo.querySelector("#panache-demo-copy");
const retry = demo.querySelector("#panache-demo-retry");
const examples = {
  callout: input.value,
  table: `|Method|Estimate|Standard error|
|-|--:|--:|
|Least squares|1.23|0.45|
|Ridge|1.18|0.32|
|Lasso|1.09|0.28|

: Estimates from three regression models. {#tbl-estimates}
`,
  math: String.raw`$$
\begin{aligned}
\hat{\beta}&=(X^\top X)^{-1}X^\top y \\
\hat{y}&=X\hat{\beta} \\
r&=y-\hat{y}
\end{aligned}
$$
`,
};

let currentExample = "callout";
let formatter;
let loading;
let formatTimer;

function setStatus(message, isError = false) {
  if (status.textContent !== message) {
    status.textContent = message;
  }
  status.dataset.error = String(isError);
}

function format() {
  if (!formatter) return;

  copy.disabled = true;
  if (!width.checkValidity()) {
    output.value = "";
    setStatus("Choose a line width between 30 and 120.", true);
    return;
  }

  try {
    output.value = formatter(
      input.value,
      width.valueAsNumber,
      "quarto",
      wrap.value,
      undefined,
      "lf",
      "preserve",
      math.value,
    );
    copy.disabled = false;
    setStatus("Formatted in your browser.");
  } catch (error) {
    output.value = "";
    setStatus(`Formatting failed: ${error.message ?? String(error)}`, true);
  }
}

async function loadFormatter() {
  if (formatter) return;
  if (loading) return loading;

  retry.hidden = true;
  setStatus("Loading the formatter…");
  // Keep the WASM download off the article's initial loading path.
  loading = (async () => {
    try {
      const module = await import("./wasm/panache_wasm.js");
      await module.default();
      formatter = module.format_qmd_with_options;
      format();
    } catch {
      setStatus("Could not load the formatter. Try loading it again.", true);
      retry.hidden = false;
    } finally {
      loading = undefined;
    }
  })();
  return loading;
}

function scheduleFormat() {
  clearTimeout(formatTimer);
  copy.disabled = true;
  formatTimer = setTimeout(format, 120);
  void loadFormatter();
}

input.addEventListener("input", scheduleFormat);
for (const control of [width, wrap, math]) {
  control.addEventListener("input", scheduleFormat);
}

for (const button of demo.querySelectorAll("[data-example]")) {
  button.addEventListener("click", () => {
    currentExample = button.dataset.example;
    input.value = examples[currentExample];
    for (const exampleButton of demo.querySelectorAll("[data-example]")) {
      exampleButton.setAttribute(
        "aria-pressed",
        String(exampleButton === button),
      );
    }
    format();
    void loadFormatter();
  });
}

demo.querySelector("#panache-demo-reset").addEventListener("click", () => {
  input.value = examples[currentExample];
  format();
  void loadFormatter();
});

copy.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(output.value);
    setStatus("Formatted source copied.");
  } catch {
    output.focus();
    output.select();
    setStatus("Select and copy the formatted source.");
  }
});

retry.addEventListener("click", loadFormatter);
demo.addEventListener("focusin", loadFormatter);

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        observer.disconnect();
        void loadFormatter();
      }
    },
    { rootMargin: "200px" },
  );
  observer.observe(demo);
} else {
  void loadFormatter();
}
