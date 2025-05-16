NETWORK=mainnet

# Must match the version of the lotus full node
LOTUS_VERSION=v1.32.3

KUBERNETES_NAMESPACE=default
DOCKER_TAG=docker.io/glif/lotus:statemarketdeals-$(LOTUS_VERSION)

build:
	docker build . -t $(DOCKER_TAG) --build-arg LOTUS_VERSION=$(LOTUS_VERSION)

push:
	docker push $(DOCKER_TAG)

diff:
	helm diff upgrade --install \
		--namespace $(KUBERNETES_NAMESPACE) \
		--values values.yaml \
		--values values/$(NETWORK).yaml \
		filecoin-statemarketdeals-$(NETWORK) \
		.

install:
	helm upgrade --install \
		--namespace $(KUBERNETES_NAMESPACE) \
		--values values.yaml \
		--values values/$(NETWORK).yaml \
		filecoin-statemarketdeals-$(NETWORK) \
		.

delete:
	helm delete filecoin-statemarketdeals-$(NETWORK)

start:
	kubectl create job \
		--namespace $(KUBERNETES_NAMESPACE) \
		--from=cronjob/filecoin-statemarketdeals-$(NETWORK) \
		test-statemarketdeals-$(NETWORK)