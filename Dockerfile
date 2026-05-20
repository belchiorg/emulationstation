FROM debian:trixie-slim AS extractor

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG ESDE_URL=https://gitlab.com/es-de/emulationstation-de/-/package_files/288156935/download

RUN curl -fL "$ESDE_URL" -o /tmp/es-de.AppImage \
    && chmod +x /tmp/es-de.AppImage \
    && /tmp/es-de.AppImage --appimage-extract \
    && mv squashfs-root /opt/es-de \
    && rm /tmp/es-de.AppImage

FROM debian:trixie-slim

COPY --from=extractor /opt/es-de /opt/es-de

ENV HOME=/config \
    XDG_DATA_HOME=/config/.local/share

ENTRYPOINT ["/opt/es-de/AppRun", "--home", "/config"]
