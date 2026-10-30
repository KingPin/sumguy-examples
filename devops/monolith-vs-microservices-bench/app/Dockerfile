ARG GO_IMAGE=golang:1.27
ARG DISTROLESS_IMAGE=gcr.io/distroless/static-debian13:nonroot

FROM ${GO_IMAGE} AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG CMD
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/${CMD}

FROM ${DISTROLESS_IMAGE}
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
