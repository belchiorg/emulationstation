FROM debian:trixie-slim AS extractor

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        python3 \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

ARG ESDE_URL=https://gitlab.com/es-de/emulationstation-de/-/package_files/288156935/download

# find-squashfs-offset.py locates the SquashFS in the AppImage by parsing the ELF
# section table instead of naively searching for 'hsqs', which has a false positive
# inside the ELF data at a lower offset.
COPY find-squashfs-offset.py /usr/local/bin/find-squashfs-offset.py

RUN curl -fL "$ESDE_URL" -o /tmp/es-de.AppImage \
    && offset=$(python3 /usr/local/bin/find-squashfs-offset.py /tmp/es-de.AppImage) \
    && echo "SquashFS offset: $offset" \
    && unsquashfs -d /opt/es-de -o "$offset" /tmp/es-de.AppImage \
    && rm /tmp/es-de.AppImage

FROM debian:trixie-slim

# Runtime libraries not bundled inside the ES-DE AppImage
RUN apt-get update && apt-get install -y --no-install-recommends \
        libasound2t64 \
        libcom-err2 \
        libdrm2 \
        libegl1 \
        libfontconfig1 \
        libfreetype6 \
        libfribidi0 \
        libgpg-error0 \
        libharfbuzz0b \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcb-dri3-0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=extractor /opt/es-de /opt/es-de

ENV HOME=/config \
    XDG_DATA_HOME=/config/.local/share

ENTRYPOINT ["/opt/es-de/AppRun", "--home", "/config"]
