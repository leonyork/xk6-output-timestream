{
  description = "xk6-output-timestream dev env (https://github.com/leonyork/xk6-output-timestream)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs =
    { nixpkgs, ... }:
    let
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      devShell = forAllSystems (
        { pkgs, ... }:
        pkgs.mkShell {
          buildInputs = import ./dependencies.nix { inherit pkgs; };
          shellHook = ''
            pre-commit install -f --hook-type commit-msg --hook-type pre-commit
            export AWS_SDK_LOAD_CONFIG=true
            # See https://github.com/NixOS/nixpkgs/issues/267864
            export PYTHONPATH=""
          '';
        }
      );
    };
}
