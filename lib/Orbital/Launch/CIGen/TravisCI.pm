package Orbital::Launch::CIGen::TravisCI;
# ABSTRACT: Generate Travis CI configuration

use Moo;
use Data::Section -setup;

1;
__DATA__
__[ .travis.yml ]__
language: perl

matrix:
  include:
    - os: linux
      services: docker
    - os: linux
      services: docker
      env: ORBITAL_COVERAGE=coveralls
    - os: osx

before_install:
  - eval "$(curl https://raw.githubusercontent.com/orbital-transfer/launch-site/master/script/ci/travis-orbital.sh)"
  - travis-orbital before-install

install: travis-orbital install
script:  travis-orbital script
