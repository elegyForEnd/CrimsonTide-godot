# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm AS engine
ARG TARGETARCH
ARG GODOT_VERSION=4.7.2
WORKDIR /tmp/godot
RUN test "$TARGETARCH" = amd64 || (echo 'This image currently supports linux/amd64 only.' >&2; exit 1)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    archive="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"; \
    release="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"; \
    curl -fSL --retry 3 "$release/$archive" -o "$archive"; \
    curl -fSL --retry 3 "$release/SHA512-SUMS.txt" -o SHA512-SUMS.txt; \
    grep "  $archive\$" SHA512-SUMS.txt > selected.sha512; \
    sha512sum -c selected.sha512; \
    unzip "$archive"; \
    install -m 0755 "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot
RUN mkdir -p /usr/local/share/licenses/godot \
    && curl -fSL --retry 3 "https://raw.githubusercontent.com/godotengine/godot/${GODOT_VERSION}-stable/LICENSE.txt" \
       -o /usr/local/share/licenses/godot/LICENSE.txt

FROM python:3.12-slim-bookworm AS prepared
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libfontconfig1 libx11-6 libxcursor1 libxinerama1 \
    libgl1 libxi6 libxrandr2 libasound2 libpulse0 libvulkan1 \
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=engine /usr/local/bin/godot /usr/local/bin/godot
COPY --from=engine /usr/local/share/licenses/godot /usr/local/share/licenses/godot
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 \
    HOME=/home/crimson GODOT=/usr/local/bin/godot \
    PUBLIC_HOST=example.com ROOM_PORT_START=24900 MAX_ROOMS=16
RUN groupadd --gid 10001 crimson \
    && useradd --uid 10001 --gid crimson --create-home crimson \
    && install -d -o crimson -g crimson -m 0700 /data /opt/crimson-tide
WORKDIR /opt/crimson-tide
COPY --chown=crimson:crimson project.godot game.cfg ./
COPY --chown=crimson:crimson scripts/ scripts/
COPY --chown=crimson:crimson scenes/ scenes/
COPY --chown=crimson:crimson pv/pv.ogv pv/
COPY --chown=crimson:crimson resources/ resources/
COPY --chown=crimson:crimson assets/ assets/
COPY --chown=crimson:crimson server/app.py server/room.gd server/docker_entrypoint.py server/
COPY --chown=crimson:crimson AUDIO-CREDITS.txt VOICE-CREDITS.txt ./
USER crimson
# Never reuse the host's .godot cache; generate Linux resources and class metadata.
RUN godot --headless --path . --editor --import --quit > /tmp/import.log 2>&1 \
    && cat /tmp/import.log \
    && ! grep -E 'SCRIPT ERROR:|ERROR:' /tmp/import.log

FROM prepared AS test
COPY --chown=crimson:crimson tests/ tests/
RUN python tests/test_server.py \
    && godot --headless --path . --script tests/systems.gd

FROM prepared AS runtime
LABEL org.opencontainers.image.title="Crimson Tide Server" \
    org.opencontainers.image.description="Account/cloud API and Godot 4.7.2 ENet room workers"
EXPOSE 8080/tcp 24900-24915/udp
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=3).read()"]
STOPSIGNAL SIGTERM
ENTRYPOINT ["python", "/opt/crimson-tide/server/docker_entrypoint.py"]
