# Run the worked problems with nothing installed on the host but Docker.
#
# This repository holds no engine. It builds FROM the image the pol repository
# produces, which carries `pol`, the standard library at the path the resolver
# looks in, and git (for the `gitcompare` scenario, which `pol compare --git`
# needs at runtime).
#
#   in a pol checkout:   make image        -> tags pol:latest
#   here:                docker compose up
#
# POL_IMAGE is an ARG so the same Dockerfile works against a registry the day
# one exists — `--build-arg POL_IMAGE=ghcr.io/sajonaro/pol:0.1.0` — without
# anything here changing shape.
ARG POL_IMAGE=pol:latest
FROM ${POL_IMAGE}

# The scenarios only ever read; a non-root user keeps a stray write from
# landing in the image and makes the container match how anyone would run the
# suite on a host.
RUN useradd -m runner
WORKDIR /problems
COPY --chown=runner:runner . /problems
USER runner

# The runner finds `pol` on PATH by its own default (POL=${POL:-pol}), and
# `(load "stdlib.pol")` resolves from <bin>/../share/pol/lib — so nothing here
# has to be configured.
ENTRYPOINT ["./run-tests.sh"]
CMD ["all"]
