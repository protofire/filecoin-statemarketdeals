NETWORK=calibration


KUBERNETES_NAMESPACE=default
DOCKER_TAG=docker.io/glif/lotus:statemarketdeals

build:
	docker build . -t $(DOCKER_TAG)

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