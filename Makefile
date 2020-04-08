SHELL=/usr/bin/env bash -o pipefail
BIN_DIR ?= $(shell pwd)/tmp/bin

EMBEDMD ?= $(BIN_DIR)/embedmd
GOJSONTOYAML ?= $(BIN_DIR)/gojsontoyaml
JSONNET ?= $(BIN_DIR)/jsonnet
JSONNET_BUNDLER ?= $(BIN_DIR)/jb
JSONNET_FMT ?= $(BIN_DIR)/jsonnetfmt
JSONNET_SRC = $(shell find . -name 'vendor' -prune -o -name 'jsonnet/vendor' -prune -o -name 'tmp' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print)
JSONNET_FMT_CMD := $(JSONNET_FMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s

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

all: generate fmt

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
fmt: $(JSONNET_FMT)
	PATH=$$PATH:$$(pwd)/$(BIN_DIR) echo ${JSONNET_SRC} | xargs -n 1 -- $(JSONNET_FMT_CMD) -i

vendor: | $(JSONNET_BUNDLER) jsonnetfile.json jsonnetfile.lock.json
	$(JSONNET_BUNDLER) install

.PHONY: clean
clean:
	-rm -rf tmp/bin
	rm -rf manifests/

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(EMBEDMD): $(BIN_DIR)
	go get -d github.com/campoy/embedmd
	go build -o $@ github.com/campoy/embedmd

$(GOJSONTOYAML): $(BIN_DIR)
	go get -d github.com/brancz/gojsontoyaml
	go build -o $@ github.com/brancz/gojsontoyaml

$(JSONNET): $(BIN_DIR)
	go get -d github.com/google/go-jsonnet/cmd/jsonnet
	go build -o $@ github.com/google/go-jsonnet/cmd/jsonnet

$(JSONNET_FMT): $(BIN_DIR)
	go get -d github.com/google/go-jsonnet/cmd/jsonnetfmt
	go build -o $@ github.com/google/go-jsonnet/cmd/jsonnetfmt

$(JSONNET_BUNDLER): $(BIN_DIR)
	curl -L -o $(JSONNET_BUNDLER) "https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v0.3.1/jb-$(shell go env GOOS)-$(shell go env GOARCH)"
	chmod +x $(JSONNET_BUNDLER)
