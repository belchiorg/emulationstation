FROM debian:trixie-slim AS extractor

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        python3 \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

ARG ESDE_URL=https://gitlab.com/es-de/emulationstation-de/-/package_files/288156935/download

# Extract the SquashFS from the AppImage without running the ARM64 binary.
# AppImages are an ELF stub followed by a SquashFS; find the offset via magic bytes.
RUN curl -fL "$ESDE_URL" -o /tmp/es-de.AppImage \
    && offset=$(python3 -c "data=open('/tmp/es-de.AppImage','rb').read(); print(data.index(b'hsqs'))") \
    && echo "SquashFS offset: $offset" \
    && unsquashfs -d /opt/es-de -o "$offset" /tmp/es-de.AppImage \
    && rm /tmp/es-de.AppImage

FROM debian:trixie-slim

COPY --from=extractor /opt/es-de /opt/es-de

ENV HOME=/config \
    XDG_DATA_HOME=/config/.local/share

ENTRYPOINT ["/opt/es-de/AppRun", "--home", "/config"]
