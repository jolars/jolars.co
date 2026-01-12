{
  description = "A basic flake with a shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          shellHook = ''
            echo "📝 Quarto blog development environment"
            echo ""
            echo "Available commands:"
            echo "  new-post [title]  - Create a new blog post"
            echo "  quarto preview    - Preview the site locally"
            echo "  quarto render     - Build the entire site"
            echo ""
          '';

          packages =
            let
              pkgs = nixpkgs.legacyPackages.${system};

              qualpalpy = (
                pkgs.python3.pkgs.buildPythonPackage rec {
                  pname = "qualpal";
                  version = "1.1.0";
                  pyproject = true;

                  src = pkgs.fetchPypi {
                    inherit pname version;
                    hash = "";
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
                    "qualpal"
                  ];
                }
              );

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

              qualpalr = pkgs.rPackages.buildRPackage {
                name = "qualpalr";
                src = pkgs.fetchFromGitHub {
                  owner = "jolars";
                  repo = "qualpalr";
                  rev = "fe1e4201e11f68c8b8d97a89d6f1426c88a53295";
                  hash = "sha256-yiqRJl+mtfrjblzLflV28plQGRoMF+LPlg8nKibXyxw=";
                };
                propagatedBuildInputs = with pkgs.rPackages; [
                  Rcpp
                ];
              };
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
              julia-bin
              (rWrapper.override {
                packages = with rPackages; [
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
              (python3.withPackages (ps: [
                ps.matplotlib
                ps.numpy
                ps.pandas
                ps.jupyter
                ps.openai
                ps.pillow
                ps.requests
                sortedl1
                qualpalpy
              ]))
            ];
        };
      }
    );
}
