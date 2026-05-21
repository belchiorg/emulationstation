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

# ---------------------------------------------------------------------------
# Final image
# ---------------------------------------------------------------------------
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        # ES-DE runtime deps
        libasound2t64 \
        libcom-err2 \
        libdrm2 \
        libegl1 \
        libegl-mesa0 \
        libfontconfig1 \
        libfreetype6 \
        libfribidi0 \
        libgpg-error0 \
        libharfbuzz0b \
        libwayland-client0 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcb-dri3-0 \
        xkb-data \
        # RetroArch + cores (arm64-available packages only)
        retroarch \
        libretro-mgba \
        libretro-nestopia \
        # RetroArch runtime deps
        libdbus-1-3 \
        libevdev2 \
        libglib2.0-0 \
        libsdl2-2.0-0 \
        libudev1 \
        libvulkan1 \
        libwayland-egl1 \
        # PCSX2 runtime deps (host-built binary bind-mounted at /opt/pcsx2)
        libsdl3-0 \
        libpcap0.8 \
        libqt6core6t64 \
        libqt6gui6 \
        libqt6widgets6 \
        libqt6dbus6 \
        libcurl4t64 \
        qt6-wayland \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/lib/aarch64-linux-gnu/libretro /usr/lib/libretro

COPY --from=extractor /opt/es-de /opt/es-de

# Wrapper for PCSX2 installed on the host and bind-mounted at /opt/pcsx2
RUN printf '#!/bin/sh\nexport LD_LIBRARY_PATH=/opt/pcsx2/lib:$LD_LIBRARY_PATH\nexec /opt/pcsx2/bin/pcsx2-qt "$@"\n' \
        > /usr/local/bin/pcsx2-qt \
    && chmod +x /usr/local/bin/pcsx2-qt

ENV HOME=/config \
    XDG_DATA_HOME=/config/.local/share \
    APPDIR=/opt/es-de \
    LD_LIBRARY_PATH=/opt/es-de/usr/lib

ENTRYPOINT ["/opt/es-de/usr/bin/es-de", "--home", "/config"]
