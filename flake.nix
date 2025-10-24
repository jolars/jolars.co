{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

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

        buildEnv = pkgs.buildFHSEnv {
          name = "build-env";
          targetPkgs = pkgs: [
            pkgs.bashInteractive
            pkgs.gcc-unwrapped
            pkgs.binutils-unwrapped
            pkgs.quartoMinimal
            pkgs.glibc
            pkgs.cmake
            pkgs.pkg-config
            pkgs.julia-bin
            (pkgs.rWrapper.override {
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
              ];
            })
            (pkgs.python3.withPackages (ps: [
              ps.matplotlib
              ps.numpy
              ps.pandas
              ps.jupyter
              ps.openai
              ps.pillow
              ps.requests
              sortedl1
            ]))
          ];
        };
      in
      {
        devShells.default = buildEnv.env;
      }
    );
}
