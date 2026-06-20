{
  pkgs,
  ...
}:

{
  packages =
    let
      new-post = pkgs.writeShellScriptBin "new-post" ''
        ${builtins.readFile ./scripts/new-post.sh}
      '';
    in
    with pkgs;
    [
      new-post
      quartoMinimal
      bashInteractive
      cmake
      go-task
      google-lighthouse
      lychee
      rustfmt
      julia-bin
    ];

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
