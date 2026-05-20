FROM debian:trixie-slim AS extractor

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        python3 \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

ARG ESDE_URL=https://gitlab.com/es-de/emulationstation-de/-/package_files/288156935/download

# Extract the SquashFS from the AppImage without running the ARM64 binary.
# The ELF runtime stub is followed by a SquashFS at a 4096-aligned boundary.
# We locate it by parsing the ELF section table, not by searching the whole file,
# because 'hsqs' can appear as a false positive inside the ELF data itself.
RUN curl -fL "$ESDE_URL" -o /tmp/es-de.AppImage \
    && offset=$(python3 - <<'PY'
import struct, math
data = open('/tmp/es-de.AppImage', 'rb').read()
e_shoff     = struct.unpack_from('<Q', data, 40)[0]
e_shentsize = struct.unpack_from('<H', data, 58)[0]
e_shnum     = struct.unpack_from('<H', data, 60)[0]
max_end = 0
for i in range(e_shnum):
    o = e_shoff + i * e_shentsize
    sh_type   = struct.unpack_from('<I', data, o +  4)[0]
    sh_offset = struct.unpack_from('<Q', data, o + 24)[0]
    sh_size   = struct.unpack_from('<Q', data, o + 32)[0]
    if sh_type != 0:
        max_end = max(max_end, sh_offset + sh_size)
aligned = math.ceil(max_end / 4096) * 4096
print(data.index(b'hsqs', aligned))
PY
) \
    && echo "SquashFS offset: $offset" \
    && unsquashfs -d /opt/es-de -o "$offset" /tmp/es-de.AppImage \
    && rm /tmp/es-de.AppImage

FROM debian:trixie-slim

COPY --from=extractor /opt/es-de /opt/es-de

ENV HOME=/config \
    XDG_DATA_HOME=/config/.local/share

ENTRYPOINT ["/opt/es-de/AppRun", "--home", "/config"]
