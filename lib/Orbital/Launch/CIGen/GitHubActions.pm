package Orbital::Launch::CIGen::GitHubActions;
# ABSTRACT: Generate GitHub Actions configuration

use Moo;
use Data::Section -setup;

1;
__DATA__
__[ orbital-transfer.yml ]__
name: CI

on:
  push:
    branches:
      - '*'
  pull_request:
    branches:
      - '*'

jobs:
  build:
    name: ${{ matrix.os }} ${{ matrix.joblabel }}
    runs-on: ${{ matrix.os }}
    env:
      ORBITAL_COVERAGE:    ${{ matrix.coverage }}
    strategy:
      fail-fast: true
      matrix:
        os: [macos-latest, windows-latest, ubuntu-latest]
        coverage: ['']
        include:
          - os: 'ubuntu-latest'
            coverage: coveralls
            joblabel: '(Coverage)'
    steps:
      - uses: actions/checkout@v2

      - name: Cache Orbital
        uses: actions/cache@v2
        env:
          cache-name: cache-orbital
        with:
          path:
	    ../_orbital/author-local
	    ../local
          key: ${{ runner.os }}-build-${{ env.cache-name }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-

      - name: Set up Orbital Transfer
        shell: bash
        run: |
          eval "$(curl https://raw.githubusercontent.com/orbital-transfer/launch-site/master/script/ci/github-actions-orbital.sh)"
      - name: Use Orbital Transfer
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          perl -S orbitalism bootstrap auto
          perl -S orbitalism
          perl -S orbitalism test
