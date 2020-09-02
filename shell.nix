{ pkgs ? import <nixpkgs> { } }:
with pkgs;
let
  inherit (lib) optional optionals;
  nodejs = nodejs-12_x;
  postgresql = postgresql_10;

in pkgs.mkShell {
  buildInputs = [
    nodejs
    (with nodePackages; [ node2nix nodejs bash-language-server eslint ])
    python
    postgresql
  ];
}
