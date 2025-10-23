const JI_MAGIC_BYTES = UInt8[0xfb, 0x6a, 0x6c, 0x69, 0x0d, 0x0a, 0x1a, 0x0a]  # "\373jli\r\n\032\n"
const JI_FORMAT_VERSION = UInt16(12)   # from src/staticdata_utils.c
const JI_BOM = UInt16(0xFEFF)

_read_cstring(io::IO) = String(readuntil(io, UInt8(0x00)))

function parse_ji_header(io::IO)
    # Fixed header
    magic = Vector{UInt8}(undef, 8); read!(io, magic)
    magic == JI_MAGIC_BYTES || throw(ArgumentError("Invalid JI magic bytes"))

    version = read(io, UInt16)
    version == JI_FORMAT_VERSION || throw(ArgumentError("Unsupported JI format version $version (expected $JI_FORMAT_VERSION)"))

    bom = read(io, UInt16)
    bom == JI_BOM || throw(ArgumentError("Invalid BOM $bom (expected $JI_BOM)"))

    ptr_size = read(io, UInt8)  # returned but not validated

    # Build metadata strings
    build_uname = _read_cstring(io)
    build_arch = _read_cstring(io)
    julia_version = _read_cstring(io)
    git_branch = _read_cstring(io)
    git_commit = _read_cstring(io)

    # Trailer of jl_read_verify_header
    pkgimage = read(io, UInt8)
    checksum = read(io, UInt64)
    datastartpos = Int64(read(io, UInt64))
    dataendpos = Int64(read(io, UInt64))

    # Next byte after header block: CacheFlagshttps://www.youtube.com/
    cache_flags = read(io, UInt8)

    return Dict{Symbol,Any}(
        :magic => magic,
        :version => version,
        :bom => bom,
        :ptr_size => ptr_size,
        :build_uname => build_uname,
        :build_arch => build_arch,
        :julia_version => julia_version,
        :git_branch => git_branch,
        :git_commit => git_commit,
        :pkgimage => pkgimage,
        :checksum => checksum,
        :datastartpos => datastartpos,
        :dataendpos => dataendpos,
        :cache_flags => cache_flags,
        :cache_flags_decoded => Base.CacheFlags(cache_flags),
    )
end

parse_ji_header(path::AbstractString) = open(path, "r") do io
    parse_ji_header(io)
end