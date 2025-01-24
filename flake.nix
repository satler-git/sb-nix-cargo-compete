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

          packages.cargo-compete-unwrapped = pkgs.rustPlatform.buildRustPackage {
            pname = "cargo-compete-unwrapped";
            version = "${cargo-compete-src.rev}";

            buildInputs = [ pkgs.openssl ];
            nativeBuildInputs = [ pkgs.pkg-config ];

            src = cargo-compete-src;
            cargoHash = "sha256-r5QjwexX7btgT31xn59vG91g8DSMoUKWbi+nQxIdTvo=";

            doCheck = false; # tests in cargo-compete require network access

            meta = {
              description = "Unwrapped version of cargo-compete";
              mainProgram = "cargo-compete";
            };
          };

          packages.cargo-compete = pkgs.stdenvNoCC.mkDerivation {
            pname = "cargo-compete";
            inherit (self'.packages.cargo-compete-unwrapped) version meta;

            # buildInputs = [ self'.packages.cargo-compete-unwrapped ];
            nativeBuildInputs = with pkgs; [
              makeWrapper
            ];

            src = null;
            dontUnpack = true;

            postFixup = ''
              makeWrapper ${lib.getExe self'.packages.cargo-compete-unwrapped} $out/bin/cargo-compete \
                --prefix PATH : ${
                  lib.makeBinPath (
                    with pkgs;
                    [
                      rustup
                      gcc # いらないかも
                    ]
                  )
                } \
                --suffix PATH : \$HOME/.cache/cargo-compete/rustup/bin \
                --set-default RUSTUP_HOME \$HOME/.cache/cargo-compete/rustup \
                --set-default CARGO_HOME \$HOME/.cache/cargo-compete/rustup
            '';
          };

          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
