#!/bin/bash

# Requires `coursier` and `mx` to be on the PATH, and $SVM_CHECKOUT should be pointed to the
# substratevm/ subdirectory of the graal repo.

set -euxo pipefail

SCALA_VERSION='2.12.8'

echo "scalaVersion := \"${SCALA_VERSION}\"" > scalac-substitutions/build.sbt

pushd scalac-substitutions/
sbt package
popd

function is_osx {
  [[ "$(uname)" == 'Darwin' ]]
}

if is_osx; then
  if [[ ! -d 'openjdk1.8.0_212-jvmci-20-b04/Contents/Home' ]]; then
    curl -L -O https://github.com/graalvm/openjdk8-jvmci-builder/releases/download/jvmci-20-b04/openjdk-8u212-jvmci-20-b04-darwin-amd64.tar.gz
    tar zxvf openjdk-8u212-jvmci-20-b04-darwin-amd64.tar.gz
  fi
  export JAVA_HOME="$(pwd)/openjdk1.8.0_212-jvmci-20-b04/Contents/Home"
else
  if [[ ! -d 'openjdk1.8.0_212-jvmci-20-b04' ]]; then
    curl -L -O https://github.com/graalvm/openjdk8-jvmci-builder/releases/download/jvmci-20-b04/openjdk-8u212-jvmci-20-b04-linux-amd64.tar.gz
    tar zxvf openjdk-8u212-jvmci-20-b04-linux-amd64.tar.gz
  fi
  export JAVA_HOME="$(pwd)/openjdk1.8.0_212-jvmci-20-b04"
fi

function merge_jars {
  tr '\n' ':' | sed -re 's#:$##g'
}

SCALA_COMPILER_JARS="$(coursier fetch org.scala-lang:scala-{compiler,library,reflect}:"$SCALA_VERSION" | merge_jars)"

mx -p "$SVM_CHECKOUT" build

mx -p "$SVM_CHECKOUT" native-image \
   -cp "$SCALA_COMPILER_JARS":$PWD/scalac-substitutions/target/scala-2.12/scalac-substitutions_2.12-0.1.0-SNAPSHOT.jar \
   scala.tools.nsc.Main \
   -H:SubstitutionResources=substitutions.json,substitutions-2.12.json \
   -H:ReflectionConfigurationFiles=scalac-substitutions/reflection-config.json \
   -H:Name=scalac \
   -J-Xmx7g -O0 \
   --verbose -H:+ReportExceptionStackTraces \
   --no-fallback \
   -Djava.io.tmpdir=/tmp \
   --allow-incomplete-classpath --report-unsupported-elements-at-runtime \
   --initialize-at-build-time=scala.runtime.StructuralCallSite \
   --initialize-at-build-time=scala.runtime.EmptyMethodCache \
   $@
