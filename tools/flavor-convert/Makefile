GITTAG := $(shell git describe --tags --abbrev=0 2> /dev/null)
VERSION := $(or ${GITTAG}, v0.0.0)

all:
	go build -ldflags "-X main.BuildVersion=$(VERSION)" -o flavor-convert-$(VERSION)
