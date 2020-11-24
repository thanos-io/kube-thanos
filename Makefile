include .bingo/Variables.mk

FIRST_GOPATH := $(firstword $(subst :, ,$(shell go env GOPATH)))
JSONNET_SRC = $(shell find . -name 'vendor' -prune -o -name 'jsonnet/vendor' -prune -o -name 'tmp' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print)
JSONNETFMT_CMD := $(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s

EXAMPLES := examples
MANIFESTS := manifests

all: fmt generate validate

.PHONY: generate
generate: vendor ${MANIFESTS} **.md

**.md: $(EMBEDMD) $(shell find ${EXAMPLES}) build.sh example.jsonnet
	$(EMBEDMD) -w `find . -name "*.md" | grep -v vendor`

.PHONY: ${MANIFESTS}
${MANIFESTS}: $(JSONNET) $(GOJSONTOYAML) vendor example.jsonnet build.sh
	@rm -rf ${MANIFESTS}
	@mkdir -p ${MANIFESTS}
	JSONNET=$(JSONNET) ./build.sh

.PHONY: fmt
fmt: $(JSONNETFMT)
	echo ${JSONNET_SRC} | xargs -n 1 -- $(JSONNETFMT_CMD) -i

.PHONY: lint
lint: $(JSONNET_LINT) vendor
	echo ${JSONNET_SRC} | xargs -n 1 -- $(JSONNET_LINT) -J vendor

.PHONY: vendor
vendor: | $(JB) jsonnetfile.json jsonnetfile.lock.json
	$(JB) install

.PHONY: clean
clean:
	-rm -rf tmp/bin
	rm -rf manifests/

.PHONY: validate
validate: $(KUBEVAL) $(MANIFESTS)
	$(KUBEVAL) --ignore-missing-schemas $(MANIFESTS)/*.yaml
