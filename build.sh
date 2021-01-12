#!/usr/bin/env bash

# This script uses arg $1 (name of *.jsonnet file to use) to generate the manifests/*.yaml files.

set -e
set -x
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

JSONNET=${JSONNET:-jsonnet}
GOJSONTOYAML=${GOJSONTOYAML:-gojsontoyaml}

# Make sure to start with a clean 'manifests' dir
rm -rf manifests
mkdir manifests

# optional, but we would like to generate yaml, not json
${JSONNET} -J vendor -m manifests "${1-example.jsonnet}" | xargs -I{} sh -c "cat {} | ${GOJSONTOYAML} > {}.yaml; rm -f {}" -- {}
find manifests -type f ! -name '*.yaml' -delete

# The following script generates all components, mostly used for testing

rm -rf examples/all/manifests
mkdir examples/all/manifests

${JSONNET} -J vendor -m examples/all/manifests "${1-all.jsonnet}" | xargs -I{} sh -c "cat {} | ${GOJSONTOYAML} > {}.yaml; rm -f {}" -- {}
find examples/all/manifests -type f ! -name '*.yaml' -delete
