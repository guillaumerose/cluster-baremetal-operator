
# Image URL to use all building/pushing image targets
IMG ?= controller:latest
# Controller-gen tool
CONTROLLER_GEN ?= go run vendor/sigs.k8s.io/controller-tools/cmd/controller-gen/main.go

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif
ifeq (/,${HOME})
GOLANGCI_LINT_CACHE=/tmp/golangci-lint-cache/
else
GOLANGCI_LINT_CACHE=${HOME}/.cache/golangci-lint
endif

# Set VERBOSE to -v to make tests produce more output
VERBOSE ?= ""

all: cluster-baremetal-operator

# Run tests
test: generate lint manifests
	go test $(VERBOSE) ./... -coverprofile cover.out

# Alias for CI
unit: test

# Build cluster-baremetal-operator binary
cluster-baremetal-operator: generate lint
	go build -o bin/cluster-baremetal-operator main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate lint manifests
	go run ./main.go

# Install CRDs into a cluster
install: manifests
	kustomize build config/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall: manifests
	kustomize build config/crd | kubectl delete -f -

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	cd config/cluster-baremetal-operator && kustomize edit set image controller=${IMG}
	kustomize build config/default | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
.PHONY: manifests
manifests:
	hack/gen-crd.sh

# Run go fmt against code
.PHONY: fmt
fmt:

# Run go lint against code
.PHONY: lint
lint: $(GOBIN)/golangci-lint
	GOLANGCI_LINT_CACHE=$(GOLANGCI_LINT_CACHE) $(GOBIN)/golangci-lint run

$(GOBIN)/golangci-lint:
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GOBIN) v1.31.0

# Run go vet against code
.PHONY: vet
vet: lint

# Generate code
.PHONY: generate
generate: $(GOBIN)/golangci-lint
	$(CONTROLLER_GEN) object:headerFile=./hack/boilerplate.go.txt paths="./..."
	GOLANGCI_LINT_CACHE=$(GOLANGCI_LINT_CACHE) $(GOBIN)/golangci-lint run --fix

# Build the docker image
docker-build: test
	docker build . -t ${IMG}

# Push the docker image
docker-push:
	docker push ${IMG}

vendor: lint
	go mod tidy
	go mod vendor
	go mod verify

.PHONY: generate-check
generate-check:
	./hack/generate.sh

.PHONY: bmh-crd
bmh-crd:
	./hack/get-bmh-crd.sh
