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
# PCSX2 extractor — fetches the latest ARM64 AppImage from GitHub releases
# and unpacks it with unsquashfs so we never need to execute the ARM binary
# on the x86 CI runner.
# ---------------------------------------------------------------------------
FROM debian:trixie-slim AS pcsx2-extractor

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        python3 \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

COPY find-squashfs-offset.py /usr/local/bin/find-squashfs-offset.py

RUN PCSX2_URL=$(curl -fsSL "https://api.github.com/repos/PCSX2/pcsx2/releases/latest" | \
        python3 -c "import sys,json;assets=json.load(sys.stdin)['assets'];url=next((a['browser_download_url'] for a in assets if ('aarch64' in a['name'].lower() or 'arm64' in a['name'].lower()) and a['name'].lower().endswith('.appimage')),None);print(url) if url else exit(1)") \
    && if [ -z "$PCSX2_URL" ]; then echo "ERROR: No PCSX2 ARM64 AppImage in latest release" && exit 1; fi \
    && echo "Downloading PCSX2: $PCSX2_URL" \
    && curl -fL "$PCSX2_URL" -o /tmp/pcsx2.AppImage \
    && offset=$(python3 /usr/local/bin/find-squashfs-offset.py /tmp/pcsx2.AppImage) \
    && echo "PCSX2 SquashFS offset: $offset" \
    && unsquashfs -d /opt/pcsx2 -o "$offset" /tmp/pcsx2.AppImage \
    && rm /tmp/pcsx2.AppImage

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
        # RetroArch + cores
        retroarch \
        retroarch-data \
        libretro-mgba \
        libretro-snes9x \
        libretro-genesis-plus-gx \
        libretro-nestopia \
        libretro-pcsx-rearmed \
        # Shared runtime deps for RetroArch and PCSX2
        libdbus-1-3 \
        libevdev2 \
        libglib2.0-0 \
        libsdl2-2.0-0 \
        libudev1 \
        libvulkan1 \
        libwayland-egl1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=extractor /opt/es-de /opt/es-de
COPY --from=pcsx2-extractor /opt/pcsx2 /opt/pcsx2

# Create PCSX2 wrapper that sets the library path and calls the Qt binary
RUN PCSX2_BIN=$(find /opt/pcsx2/usr/bin -type f \( -name "pcsx2-qt" -o -name "pcsx2" \) | head -1) \
    && echo "Found PCSX2 binary: $PCSX2_BIN" \
    && printf '#!/bin/sh\nexport LD_LIBRARY_PATH=/opt/pcsx2/usr/lib:$LD_LIBRARY_PATH\nexec %s "$@"\n' "$PCSX2_BIN" \
        > /usr/local/bin/pcsx2 \
    && chmod +x /usr/local/bin/pcsx2

ENV HOME=/config \
    XDG_DATA_HOME=/config/.local/share \
    APPDIR=/opt/es-de \
    LD_LIBRARY_PATH=/opt/es-de/usr/lib

ENTRYPOINT ["/opt/es-de/usr/bin/es-de", "--home", "/config"]
