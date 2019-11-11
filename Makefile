JSONNET_FMT := jsonnetfmt -n 2 --max-blank-lines 2 --string-style s --comment-style s

CONTAINER_CMD:=docker run --rm \
		-u="$(shell id -u):$(shell id -g)" \
		-v "$(shell go env GOCACHE):/.cache/go-build" \
		-v "$(PWD):/go/src/github.com/metalmatze/kube-thanos:Z" \
		-w "/go/src/github.com/metalmatze/kube-thanos" \
		-e USER=deadbeef \
		-e GO111MODULE=on \
		quay.io/coreos/jsonnet-ci

all: generate fmt

.PHONY: generate-in-docker
generate-in-docker:
	@echo ">> Compiling assets and generating Kubernetes manifests"
	$(CONTAINER_CMD) make $(MFLAGS) generate

.PHONY: generate
generate: manifests jsonnet/thanos-mixin/alerts.yaml jsonnet/thanos-mixin/rules.yaml dashboards **.md

**.md: $(shell find examples) build.sh example.jsonnet
	embedmd -w `find . -name "*.md" | grep -v vendor`

manifests: vendor example.jsonnet build.sh
	rm -rf manifests
	./build.sh

jsonnet/thanos-mixin/dashboards: jsonnet/thanos-mixin/mixin.libsonnet jsonnet/thanos-mixin/config.libsonnet jsonnet/thanos-mixin/dashboards/*
	rm -rf jsonnet/thanos-mixin/dashboards/*.json
	jsonnet -J vendor -m jsonnet/thanos-mixin/dashboards jsonnet/thanos-mixin/dashboards.jsonnet

jsonnet/thanos-mixin/alerts.yaml: jsonnet/thanos-mixin/mixin.libsonnet jsonnet/thanos-mixin/config.libsonnet jsonnet/thanos-mixin/alerts/*
	jsonnet jsonnet/thanos-mixin/alerts.jsonnet | gojsontoyaml > $@

jsonnet/thanos-mixin/rules.yaml: jsonnet/thanos-mixin/mixin.libsonnet jsonnet/thanos-mixin/config.libsonnet jsonnet/thanos-mixin/rules/*
	jsonnet jsonnet/thanos-mixin/rules.jsonnet | gojsontoyaml > $@

vendor: jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	jb install

.PHONY: fmt
fmt:
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNET_FMT) -i

.PHONY: lint
lint: fmt jsonnet/thanos-mixin/alerts.yaml jsonnet/thanos-mixin/rules.yaml
	promtool check rules jsonnet/thanos-mixin/alerts.yaml jsonnet/thanos-mixin/rules.yaml

.PHONY: test
test: jsonnet/thanos-mixin/alerts.yaml jsonnet/thanos-mixin/rules.yaml
	promtool test rules tests.yaml

.PHONY: clean
clean:
	rm -rf manifests/
	rm -rf jsonnet/thanos-mixin/alerts.yaml
	rm -rf dashboards/
