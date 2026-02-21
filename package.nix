# package.nix - Build irishbuoys as an installable R package derivation
#
# Used by push_to_cachix.sh to build and push to johngavin cachix.
# Uses same nixpkgs pin as default.nix (2026-01-19).
#
# Usage:
#   nix-build package.nix --no-out-link
#   # Push ONLY this package (not deps!) - pipe single path:
#   nix-build package.nix --no-out-link | cachix push johngavin

let
  pkgs = import (fetchTarball "https://github.com/rstats-on-nix/nixpkgs/archive/2026-01-19.tar.gz") {};

  irishbuoys = pkgs.rPackages.buildRPackage {
    name = "irishbuoys";
    src = ./.;

    # Imports from DESCRIPTION
    propagatedBuildInputs = with pkgs.rPackages; [
      arrow
      cli
      dbplyr
      DBI
      dplyr
      duckdb
      glue
      httr2
      jsonlite
      lubridate
      pointblank
      rlang
      tibble
    ];
  };

in irishbuoys
