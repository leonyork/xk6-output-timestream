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
  prettier
  markdownlint-cli2
  pre-commit
  shfmt
  statix
]
