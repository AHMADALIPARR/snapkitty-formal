{
  description = "snapkitty-formal: OCaml formal verification stack";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    opam-nix.url = "github:tweag/opam-nix";
  };

  outputs = { self, nixpkgs, flake-utils, opam-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        scope = opam-nix.lib.${system}.buildOpamProject' { } ./. { };

        formalTools = with pkgs; [
          saw
          cryptol
          coq
          # acl2  # enable when available in your channel
        ];
      in {
        packages.default = scope.snapkitty-formal;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            opam
            dune_3
            ocamlPackages.ocaml-lsp
            ocamlPackages.utop
            ocamlPackages.ocamlformat
            ocamlPackages.findlib
          ] ++ formalTools;

          shellHook = ''
            echo "🔧 snapkitty-formal dev shell"
            echo " OCaml:   $(ocaml -version 2>/dev/null || echo n/a)"
            echo " Dune:    $(dune --version 2>/dev/null || echo n/a)"
            echo " SAW:     $(saw --version 2>/dev/null || echo 'not found')"
            echo " Cryptol: $(cryptol --version 2>/dev/null || echo 'not found')"
            echo " coqc:    $(coqc --version 2>/dev/null | head -1 || echo 'not found')"
          '';
        };
      });
}
