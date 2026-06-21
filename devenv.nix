{
  pkgs,
  ...
}:

let
  new-post = pkgs.writeShellScriptBin "new-post" ''
    ${builtins.readFile ./scripts/new-post.sh}
  '';
  # LaTeX for rendering the CV to PDF. A medium scheme plus the font and
  # icon packages the CV partials pull in (academicons, fontawesome5,
  # libertine), which live in fontsextra and aren't in the base schemes.
  tex = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      academicons
      fontawesome5
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
in

{
  packages =
    with pkgs;
    [
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

  languages = {
    r = {
      enable = true;
      package = (
        pkgs.rWrapper.override {
          packages = with pkgs.rPackages; [
            SLOPE
            eulerr
            maps
            qualpalr
            rgl
            reticulate
            venneuler
            languageserver
            JuliaCall
            magick
          ];
        }
      );
    };

    julia = {
      enable = true;
      package =
        let
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
        in

        (pkgs.python3.withPackages (ps: [
          ps.matplotlib
          ps.numpy
          ps.pandas
          ps.jupyter
          ps.openai
          ps.pillow
          ps.requests
          sortedl1
        ]));
    };

    python = {
      enable = true;
    };
  };

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;
}
