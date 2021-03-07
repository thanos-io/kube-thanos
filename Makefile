include .bingo/Variables.mk

FIRST_GOPATH := $(firstword $(subst :, ,$(shell go env GOPATH)))
JSONNET_SRC = $(shell find . -name 'vendor' -prune -o -name 'jsonnet/vendor' -prune -o -name 'tmp' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print)
JSONNETFMT_CMD := $(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s

EXAMPLES := examples
MANIFESTS := manifests
TMP := tmp

K8S_VERSION := 1.20.4
PROM_OPERATOR_VERSION := 0.46.0

PIP  := pip3
CRDS := \
	https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v$(PROM_OPERATOR_VERSION)/jsonnet/prometheus-operator/servicemonitor-crd.libsonnet \

all: fmt generate validate

.PHONY: generate
generate: vendor ${MANIFESTS} **.md

**.md: $(EMBEDMD) $(shell find ${EXAMPLES}) build.sh example.jsonnet
	$(EMBEDMD) -w `find . -name "*.md" | grep -v vendor`

.PHONY: ${MANIFESTS}
${MANIFESTS}: $(JSONNET) $(GOJSONTOYAML) vendor example.jsonnet all.jsonnet build.sh
	@rm -rf ${MANIFESTS}
	@mkdir -p ${MANIFESTS}
	JSONNET=$(JSONNET) GOJSONTOYAML=$(GOJSONTOYAML) ./build.sh

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

${TMP}/openapi2jsonschema.py:
	@$(PIP) show pyyaml >/dev/null
	@mkdir -p $(TMP)
	@curl -sSfo $@ https://raw.githubusercontent.com/yannh/kubeconform/v0.4.4/scripts/openapi2jsonschema.py
	@chmod +x $@

.kubeval/v${K8S_VERSION}-standalone-strict: $(TMP)/openapi2jsonschema.py
	@rm -rf .kubeval
	@mkdir -p $@
	@cd $@ && for crd in $(CRDS); do \
	  FILENAME_FORMAT='{kind}-{group}-{version}' ../../$(TMP)/openapi2jsonschema.py "$${crd}"; \
	done

.PHONY: validate
validate: $(KUBEVAL) $(MANIFESTS) $(EXAMPLES)/all/manifests
	$(KUBEVAL) --force-color --strict --kubernetes-version $(K8S_VERSION) \
		--schema-location https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master \
		--additional-schema-locations "file://$(CURDIR)/.kubeval" \
		$(MANIFESTS)/*.yaml $(EXAMPLES)/all/manifests/*.yaml
