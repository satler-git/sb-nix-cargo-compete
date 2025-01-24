{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    cargo-compete-src = {
      url = "github:qryxip/cargo-compete";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        # Put your original flake attributes here.
      };
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
      ];
      perSystem =
        {
          pkgs,
          lib,
          self',
          ...
        }:
        let
          inherit (inputs) cargo-compete-src;
        in
        {
          packages.default = self'.packages.cargo-compete;

          packages.cargo-compete = pkgs.rustPlatform.buildRustPackage {
            pname = "cargo-compete";
            version = "${cargo-compete-src.rev}";

            buildInputs = with pkgs; [
              openssl
            ];
            nativeBuildInputs = with pkgs; [
              pkg-config
              makeWrapper
            ];

            src = cargo-compete-src;
            cargoHash = "sha256-69TeTY1o94uU3SbwxdRK9LQ0jXiaQTfeNbVKspLpK2g=";

            postFixup = ''
              wrapProgram $out/bin/cargo-compete \
                --prefix PATH : ${
                  lib.makeBinPath (
                    with pkgs;
                    [
                      rustup
                    ]
                  )
                } \
                --suffix PATH : \$HOME/.cache/cargo-compete/rustup/bin \
                --set-default RUSTUP_HOME \$HOME/.cache/cargo-compete/rustup \
                --set-default CARGO_HOME \$HOME/.cache/cargo-compete/rustup
            '';

            doCheck = false; # tests in cargo-compete require network access
          };

          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
