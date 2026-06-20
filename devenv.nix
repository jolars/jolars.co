{
  pkgs,
  ...
}:

let
  new-post = pkgs.writeShellScriptBin "new-post" ''
    ${builtins.readFile ./scripts/new-post.sh}
  '';
  # LaTeX for rendering the CV to PDF. A medium scheme plus the font and
  # icon packages the CV partials pull in (academicons, fontawesome6,
  # libertine), which live in fontsextra and aren't in the base schemes.
  tex = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      academicons
      fontawesome6
      libertine
      enumitem
      microtype
      fancyhdr
      etoolbox
      ;
  };
  # nixpkgs ships pandoc 3.7.0.2, but quartoMinimal 1.9.37 emits the
  # `syntax-highlighting` defaults key (from `highlight-style`), which only
  # exists in pandoc >= 3.8. We vendor the official 3.8.3 release (the version
  # quarto expects) and pin quarto to it via QUARTO_PANDOC below. Without this,
  # quarto falls back to a too-old pandoc and fails with
  # `Unknown option "syntax-highlighting"` (e.g. the CI runner's system pandoc).
  pandoc = pkgs.stdenv.mkDerivation rec {
    pname = "pandoc-bin";
    version = "3.8.3";
    src = pkgs.fetchurl {
      url = "https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-linux-amd64.tar.gz";
      hash = "sha256-wiT6uJ+CfTYjOA7LfBB4wWPHachJoUrCfo07+7kUybQ=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.gmp
      pkgs.zlib
      pkgs.lua5_4
    ];
    installPhase = ''
      runHook preInstall
      install -Dm755 bin/pandoc $out/bin/pandoc
      runHook postInstall
    '';
  };

  # eulerr 8.0.0 ships the Rust-backed Eunoia core; the nixpkgs pin is still on
  # the old C++ 7.1.0. Build it straight from the CRAN source, which vendors its
  # crates (src/rust/vendor.tar.xz) for an offline compile, so we only need a
  # Rust toolchain on top of base R.
  eulerr = pkgs.rPackages.buildRPackage {
    name = "eulerr-8.0.0";
    src = pkgs.fetchurl {
      url = "https://cran.r-project.org/src/contrib/eulerr_8.0.0.tar.gz";
      sha256 = "sha256-HiYalT29VHBdseSk2eo/lwLkbcTCL4qQW3+RepVdEQk=";
    };
    nativeBuildInputs = [
      pkgs.cargo
      pkgs.rustc
    ];
    # configure uses `#!/usr/bin/env sh`, which the build sandbox lacks.
    postPatch = "patchShebangs configure";
  };

  # Python bindings for Eunoia, not in nixpkgs. Install the prebuilt PyPI wheel
  # and patch its compiled extension to find libgcc.
  eunoia = pkgs.python3.pkgs.buildPythonPackage {
    pname = "eunoia";
    version = "0.4.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/32/c1/8c6b9653839ec29a7653035c98d28976a7b95547dacf35aea6c8eb9f8d94/eunoia-0.4.0-cp311-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-dKOe6QwhJK4vV1ZEiUmzHKCMVNSmXmYJBt+l9GgfKkk=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    propagatedBuildInputs = with pkgs.python3.pkgs; [
      matplotlib
      narwhals
      numpy
    ];
    pythonImportsCheck = [ "eunoia" ];
  };

  sortedl1 = (
    pkgs.python3.pkgs.buildPythonPackage rec {
      pname = "sortedl1";
      version = "1.1.0";
      pyproject = true;

      src = pkgs.fetchPypi {
        inherit pname version;
        hash = "sha256-bon1d6r18eayuqhhK8zAckFWGSilX3eUc213HSeO2dQ=";
      };

      dontUseCmakeConfigure = true;

      build-system = [
        pkgs.python3.pkgs.scikit-build-core
        pkgs.python3.pkgs.pybind11
        pkgs.cmake
        pkgs.ninja
      ];

      dependencies = with pkgs.python3.pkgs; [
        numpy
        scikit-learn
        scipy
        furo
        sphinx-copybutton
        myst-parser
        pytest
      ];

      disabledTests = [
        "test_cdist"
      ];

      pythonImportsCheck = [
        "sortedl1"
      ];
    }
  );

  # The Python environment that ends up on PATH and that reticulate points at
  # (see RETICULATE_PYTHON below), so knitr `{python}` chunks can import eunoia.
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.matplotlib
    ps.numpy
    ps.pandas
    ps.jupyter
    ps.openai
    ps.pillow
    ps.requests
    sortedl1
    eunoia
  ]);
in
{
  packages = with pkgs; [
    new-post
    tex
    quartoMinimal
    pandoc
    bashInteractive
    cmake
    go-task
    google-lighthouse
    lychee
    rustfmt
    julia-bin
  ];

  # Pin quarto to the vendored pandoc deterministically, regardless of PATH
  # order (quarto's own pandoc lookup doesn't strictly follow PATH).
  env.QUARTO_PANDOC = "${pandoc}/bin/pandoc";
  # reticulate (used by the knitr engine for `{python}` chunks) honors this over
  # any auto-discovery, so the eulerr/eunoia blog post renders against the env
  # that actually has eunoia installed.
  env.RETICULATE_PYTHON = "${pythonEnv}/bin/python";

  languages = {
    r = {
      enable = true;
      package = (
        pkgs.rWrapper.override {
          packages =
            (with pkgs.rPackages; [
              SLOPE
              maps
              qualpalr
              rgl
              reticulate
              venneuler
              languageserver
              JuliaCall
              magick
            ])
            ++ [ eulerr ];
        }
      );
    };

    julia = {
      enable = true;
      package = pythonEnv;
    };

    python = {
      enable = true;
    };
  };

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;
}
