{ pkgs, ... }:
with pkgs;
[
  act
  awscli2
  editorconfig-checker
  go
  gofumpt
  gotools
  golangci-lint
  gopls
  hadolint
  k6
  nixfmt-rfc-style
  nodejs
  nodePackages.prettier
  nodePackages.markdownlint-cli2
  pre-commit
  shfmt
  statix
  xk6
]
