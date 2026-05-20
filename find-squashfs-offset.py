import struct, math, sys

path = sys.argv[1]
data = open(path, 'rb').read()

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
