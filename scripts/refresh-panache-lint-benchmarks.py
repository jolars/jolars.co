#!/usr/bin/env python3
"""Refresh the Panache post's lint timings from a local Panache checkout.

Run in the Panache checkout's devenv shell so its comparison tools are on PATH.
"""

import argparse
import hashlib
import json
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError("The upstream benchmark runner changed; review the adapter.")
    return source.replace(old, new, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("panache_repo", type=Path)
    args = parser.parse_args()
    repo = args.panache_repo.resolve()
    post = (
        Path(__file__).resolve().parents[1]
        / "blog/2026-10-09-panache-an-editor-companion-for-markdown"
    )
    documents = {
        "tables": "tables.qmd",
        "math": "math.qmd",
        "pandoc_manual": "pandoc_manual.md",
    }
    tools = ("rumdl", "mado", "markdownlint", "hyperfine", "jq", "cargo")
    for tool in tools:
        if shutil.which(tool) is None:
            raise RuntimeError(f"Missing {tool}; run this in Panache's devenv shell.")

    revision = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repo, text=True
    ).strip()
    subprocess.run(["git", "diff", "--quiet", "HEAD"], cwd=repo, check=True)
    source = (repo / "benches/compare_lint_single.sh").read_text()
    subprocess.run(
        ["cargo", "build", "--release", "--bin", "panache", "--quiet"],
        cwd=repo,
        check=True,
    )

    with tempfile.TemporaryDirectory(prefix="panache-lint-benchmark-") as temporary:
        directory = Path(temporary)
        for name, filename in documents.items():
            fixture = repo / "benches/documents" / filename
            # Mado skips .qmd files, so give it the same bytes with a recognized suffix.
            (directory / f"{name}.md").write_bytes(fixture.read_bytes())

        commands = {
            "panache": [
                str(repo / "target/release/panache"),
                "lint",
                "--isolated",
                "--no-cache",
            ],
            "rumdl": [
                "rumdl",
                "check",
                "--isolated",
                "--no-cache",
                "--fail-on",
                "never",
            ],
            "mado": ["mado", "check"],
            "markdownlint": ["markdownlint"],
        }
        for tool, command in commands.items():
            for name, filename in documents.items():
                fixture = (
                    directory / f"{name}.md"
                    if tool == "mado"
                    else repo / "benches/documents" / filename
                )
                result = subprocess.run(
                    [*command, str(fixture)],
                    cwd=repo,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if result.returncode not in (0, 1):
                    raise RuntimeError(f"{tool} failed on {filename}: {result.stderr}")
                if not (result.stdout + result.stderr).strip():
                    raise RuntimeError(
                        f"{tool} produced no preflight output for {filename}."
                    )

        runner = replace_once(
            source,
            'REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"',
            f"REPO_ROOT={shlex.quote(str(repo))}\nMADO_DOCS_DIR={shlex.quote(str(directory))}",
        )
        runner = replace_once(
            runner,
            "[panache]=\"$PANACHE lint --isolated --no-cache --quiet '$DOCS_DIR/$file' >/dev/null 2>&1\"",
            "[panache]=\"$PANACHE lint --isolated --no-cache --quiet '$DOCS_DIR/$file' >/dev/null 2>&1 || test \\$? -eq 1\"",
        )
        runner = replace_once(
            runner,
            "mado check --quiet '$DOCS_DIR/$file'",
            "mado check --quiet '$MADO_DOCS_DIR/${file%.*}.md'",
        )
        # Diagnostic findings are expected; crashes must still fail the measurement.
        runner = runner.replace(' || true"', ' || test \\$? -eq 1"')
        lines = []
        for line in runner.splitlines():
            if line.startswith("HAVE_MARKDOWNLINT_CLI2="):
                line = "HAVE_MARKDOWNLINT_CLI2=no"
            if line.startswith('benchmark_document "') and not any(
                line.startswith(f'benchmark_document "{name}"') for name in documents
            ):
                continue
            lines.append(line)
        runner = "\n".join(lines) + "\n"
        runner = runner.replace("Tables Document (19 KB)", "Tables Document")
        runner = runner.replace("Math Document (29 KB)", "Math Document")
        script = directory / "runner.sh"
        script.write_text(runner)
        output = directory / "results.json"
        subprocess.run(
            ["bash", str(script), "--out", str(output)], cwd=repo, check=True
        )

        snapshot = json.loads(output.read_text())
        expected = {(document, tool) for document in documents for tool in commands}
        actual = {(row["document"], row["tool"]) for row in snapshot["results"]}
        if actual != expected or len(snapshot["results"]) != len(expected):
            raise RuntimeError(
                "The benchmark did not produce all 12 expected measurements."
            )
        for row in snapshot["results"]:
            if row["mean_ms"] <= 0 or row["runs"] < 3:
                raise RuntimeError(f"Invalid benchmark measurement: {row}")
        snapshot["meta"]["provenance"] = {
            "repository": "https://github.com/jolars/panache",
            "revision": revision,
            "runner": "benches/compare_lint_single.sh",
            "adapter": "scripts/refresh-panache-lint-benchmarks.py",
            "adaptations": [
                "Select three documents and four tools.",
                "Accept lint diagnostic exit code 1 without accepting other failures.",
                "Give mado byte-identical .md copies because it skips .qmd files.",
            ],
        }
        for document in snapshot["documents"]:
            fixture = repo / "benches/documents" / document["file"]
            document["sha256"] = hashlib.sha256(fixture.read_bytes()).hexdigest()
        final_revision = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repo, text=True
        ).strip()
        if final_revision != revision:
            raise RuntimeError("The Panache revision changed during the benchmark.")
        subprocess.run(["git", "diff", "--quiet", "HEAD"], cwd=repo, check=True)
        destination = post / "performance_lint_single_data.json"
        destination.write_text(json.dumps(snapshot, indent=2) + "\n")
        print(f"Wrote {destination}")


if __name__ == "__main__":
    main()
