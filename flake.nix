{
  description = "Svarozhits";

  inputs = {
    fenix =
      {
        url = "github:nix-community/fenix";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, fenix, flake-utils, naersk, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (import nixpkgs) {
          inherit system;
        };

        toolchain = with fenix.packages.${system};
          combine [
            minimal.rustc
            minimal.cargo
            targets.x86_64-unknown-linux-gnu.latest.rust-std
            targets.aarch64-unknown-linux-gnu.latest.rust-std
          ];

        naersk' = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        naerskBuildPackage = target: args:
          naersk'.buildPackage (
            args
            // { CARGO_BUILD_TARGET = target; }
            // cargoConfig
          );

        cargoConfig = {
          CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.pkgsCross.aarch64-multiplatform.stdenv.cc}/bin/aarch64-unknown-linux-gnu-gcc";
        };

      in
      rec {
        defaultPackage = packages.x86_64-unknown-linux-gnu;

        packages.x86_64-unknown-linux-gnu = naerskBuildPackage "x86_64-unknown-linux-gnu" {
          src = ./.;
          doCheck = true;
        };

        packages.aarch64-unknown-linux-gnu = naerskBuildPackage "aarch64-unknown-linux-gnu" {
          src = ./.;
        };

        packages.docker-image-amd64 = pkgs.dockerTools.buildImage {
          name = "svarozhits";
          tag = "latest";
          config = {
            Cmd = [ "${packages.x86_64-unknown-linux-gnu}/bin/svarozhits" ];
          };
        };

        packages.docker-image-arm64 = pkgs.pkgsCross.aarch64-multiplatform.dockerTools.buildImage {
          name = "svarozhits";
          tag = "latest";
          config = {
            Cmd = [ "${packages.aarch64-unknown-linux-gnu}/bin/svarozhits" ];
          };
        };

        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ rustc cargo ];
        };
      }
    );
}
