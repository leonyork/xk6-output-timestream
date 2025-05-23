{
  description = "Home Manager configuration of devcontainer root";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = builtins.currentSystem;
      pkgs = nixpkgs.legacyPackages.${system};
      tools = import "${builtins.getEnv "NIX_TOOLS_PATH"}";
    in
    {
      home-manager.useUserPackages = true;
      home-manager.news.enable = false;

      homeConfigurations."root" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          {
            home.username = "root";
            home.homeDirectory = "/root";
          }
          tools
        ];

        extraSpecialArgs = { inherit system; };
      };
    };
}
