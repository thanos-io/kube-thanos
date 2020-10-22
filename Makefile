all: fmt generate validate

include .bingo/Variables.mk

JSONNET_SRC = $(shell find . -name 'vendor' -prune -o -name 'jsonnet/vendor' -prune -o -name 'tmp' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print)
JSONNETFMT_CMD := $(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s

CONTAINER_CMD:=docker run --rm \
		-u="$(shell id -u):$(shell id -g)" \
		-v "$(shell go env GOCACHE):/.cache/go-build" \
		-v "$(PWD):/go/src/github.com/thanos-io/kube-thanos:Z" \
		-w "/go/src/github.com/thanos-io/kube-thanos" \
		-e USER=deadbeef \
		-e GO111MODULE=on \
		quay.io/coreos/jsonnet-ci

EXAMPLES := examples
MANIFESTS := manifests


.PHONY: generate-in-docker
generate-in-docker:
	@echo ">> Compiling assets and generating Kubernetes manifests"
	$(CONTAINER_CMD) make $(MFLAGS) generate

.PHONY: generate
generate: vendor ${MANIFESTS} **.md

**.md: $(EMBEDMD) $(shell find ${EXAMPLES}) build.sh example.jsonnet
	$(EMBEDMD) -w `find . -name "*.md" | grep -v vendor`

.PHONY: ${MANIFESTS}
${MANIFESTS}: $(JSONNET) $(GOJSONTOYAML) vendor example.jsonnet build.sh
	@rm -rf ${MANIFESTS}
	@mkdir -p ${MANIFESTS}
	PATH=$$PATH:$$(pwd)/$(BIN_DIR) ./build.sh

.PHONY: fmt
fmt: $(JSONNETFMT)
	PATH=$$PATH:$$(pwd)/$(BIN_DIR) echo ${JSONNET_SRC} | xargs -n 1 -- $(JSONNETFMT_CMD) -i

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
