FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS filexp-build

ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache upx git

RUN git clone https://github.com/aschmahmann/filexp.git -b f05dump /filexp --recurse-submodules

WORKDIR /filexp

# Target lotus version, example: v1.32.3
ARG LOTUS_VERSION
RUN go get github.com/filecoin-project/lotus@${LOTUS_VERSION} && go mod tidy

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags "-s -w" -o /filexp/filexp .

RUN upx -9 /filexp/filexp


FROM --platform=$BUILDPLATFORM alpine:3.21 AS runtime

RUN apk add --no-cache aws-cli zstd

COPY --from=filexp-build /filexp/filexp /usr/local/bin/filexp

COPY ./run.sh /run.sh

CMD [ "sh", "/run.sh" ]