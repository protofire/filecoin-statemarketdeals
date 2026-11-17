NETWORK=mainnet
VALUES_FILE=calibration

# Must match the version of the lotus full node
LOTUS_VERSION=v1.37.0

KUBERNETES_NAMESPACE=default
DOCKER_TAG=docker.io/glif/lotus:statemarketdeals-$(LOTUS_VERSION)-$(NETWORK)

ifeq ($(NETWORK),calibration)
	GOFLAGS=-tags=calibnet
endif

build:
	docker build . -t $(DOCKER_TAG) --build-arg GOFLAGS=$(GOFLAGS) --build-arg LOTUS_VERSION=$(LOTUS_VERSION) --build-arg NETWORK=$(NETWORK) --no-cache

push:
	docker push $(DOCKER_TAG)

diff:
	helm diff upgrade --install \
		--namespace $(KUBERNETES_NAMESPACE) \
		--values values.yaml \
		--values values/$(VALUES_FILE).yaml \
		filecoin-statemarketdeals-$(VALUES_FILE) \
		.

install:
	helm upgrade --install \
		--namespace $(KUBERNETES_NAMESPACE) \
		--values values.yaml \
		--values values/$(VALUES_FILE).yaml \
		filecoin-statemarketdeals-$(VALUES_FILE) \
		.

delete:
	helm delete filecoin-statemarketdeals-$(VALUES_FILE)

start:
	kubectl create job \
		--namespace $(KUBERNETES_NAMESPACE) \
		--from=cronjob/filecoin-statemarketdeals-$(VALUES_FILE) \
		test-statemarketdeals-$(VALUES_FILE)
