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
        "aarch64-linux"
        "i686-linux"
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
                      self'.packages.wrapped-rustup
                      gcc # いらないかも
                    ]
                  )
                } \
                --run 'export PATH=$PATH:"$HOME/.cache/cargo-compete/rustup/bin"' \
                --run 'export RUSTUP_HOME=''${RUSTUP_HOME-"$HOME/.cache/cargo-compete/rustup"}' \
                --run 'export CARGO_HOME=''${CARGO_HOME-"$HOME/.cache/cargo-compete/rustup"}' \
                --run 'rustup default stable'
            '';
          };

          # 普通のrustupは自動でランタイムをインストールしないからユーザーがコマンドを打つ必要があるけど、rustupにアクセスできないから、
          # rustupを自動的にランタイムをインストールするようにwrapする
          packages.wrapped-rustup = pkgs.writeShellApplication {
            name = "rustup";

            runtimeInputs = with pkgs; [
              rustup
            ];

            # $2がrunの場合に--installを$2と$3の間に付ける
            text = ''
              if [ "''${1:-}" = "run" ]; then
                # Shift the first argument (removing 'run')
                command=$1
                shift

                # Ensure $2 and $3 exist
                if [ $# -ge 3 ]; then
                  # Insert --install between $2 and $3
                  new_args=("$command" "$1" "--install" "$2" "$3" "''${@:4}")
                  rustup "''${new_args[@]}"
                else
                  echo "Error: Missing required arguments for --install insertion."
                  exit 1
                fi
              else
                rustup "$@"
              fi
            '';
          };

          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
