{ pkgs ? import <nixpkgs> { } }:
with pkgs;
let
  inherit (lib) optional optionals;
  nodejs = nodejs-12_x;
  postgresql = postgresql_10;

in pkgs.mkShell {
  buildInputs = [
    nodejs
    (with nodePackages; [ nodejs bash-language-server ])
    python
    postgresql
  ];
}
