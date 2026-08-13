# Run the worked problems with nothing installed on the host but Docker.
#
# This repository holds no engine. It builds FROM the image the writ repository
# produces, which carries `writ`, the standard library at the path the resolver
# looks in, and git (for the `gitcompare` scenario, which `writ compare --git`
# needs at runtime).
#
#   in a writ checkout:   make image        -> tags writ:latest
#   here:                docker compose up
#
# WRIT_IMAGE is an ARG so the same Dockerfile works against a registry the day
# one exists — `--build-arg WRIT_IMAGE=ghcr.io/writ-lang/writ:0.1.0` — without
# anything here changing shape.
ARG WRIT_IMAGE=writ:latest
FROM ${WRIT_IMAGE}

# The scenarios only ever read; a non-root user keeps a stray write from
# landing in the image and makes the container match how anyone would run the
# suite on a host.
RUN useradd -m runner
WORKDIR /problems
COPY --chown=runner:runner . /problems
USER runner

# The runner finds `writ` on PATH by its own default (WRIT=${WRIT:-writ}), and
# `(load "stdlib.writ")` resolves from <bin>/../share/writ/lib — so nothing here
# has to be configured.
ENTRYPOINT ["./run-tests.sh"]
CMD ["all"]
