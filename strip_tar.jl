using Printf

include(joinpath(@__DIR__, "strip.jl"))

function find_root_directory(extract_dir::AbstractString)
    entries = filter(name -> name != "." && name != "..", readdir(extract_dir))
    if length(entries) == 1
        return joinpath(extract_dir, entries[1])
    else
        return extract_dir
    end
end

function remove_macos_dotfiles!(root_dir::AbstractString; verbose::Bool=false)
    removed = String[]
    if ispath(joinpath(root_dir, "__MACOSX"))
        rm(joinpath(root_dir, "__MACOSX"); recursive=true, force=true)
        push!(removed, joinpath(root_dir, "__MACOSX"))
        verbose && println("Removed: ", joinpath(root_dir, "__MACOSX"))
    end
    for (dirpath, dirnames, filenames) in walkdir(root_dir)
        for f in filenames
            if startswith(f, "._") || f == ".DS_Store"
                fp = joinpath(dirpath, f)
                rm(fp; force=true)
                push!(removed, fp)
                verbose && println("Removed: ", fp)
            end
        end
        for d in dirnames
            if d == "__MACOSX"
                dp = joinpath(dirpath, d)
                rm(dp; recursive=true, force=true)
                push!(removed, dp)
                verbose && println("Removed: ", dp)
            end
        end
    end
    return removed
end

function list_stdlib_names(root_dir::AbstractString)
    stdlib_root = joinpath(root_dir, "share", "julia", "stdlib")
    if !isdir(stdlib_root)
        return Set{String}()
    end
    version_dirs = filter(name -> isdir(joinpath(stdlib_root, name)), readdir(stdlib_root))
    names = String[]
    for vdir in version_dirs
        for pkg in readdir(joinpath(stdlib_root, vdir))
            isdir(joinpath(stdlib_root, vdir, pkg)) && push!(names, pkg)
        end
    end
    return Set(names)
end

function delete_bundled_tests!(root_dir::AbstractString; verbose::Bool=false, keep_tests_for::Set{String}=Set(["REPL"]))
    deleted = String[]
    # Remove top-level Base tests
    base_tests = joinpath(root_dir, "share", "julia", "test")
    if ispath(base_tests)
        rm(base_tests; recursive=true, force=true)
        push!(deleted, base_tests)
        verbose && println("Removed: ", base_tests)
    end
    # Remove stdlib tests
    stdlib_root = joinpath(root_dir, "share", "julia", "stdlib")
    if isdir(stdlib_root)
        for vdir in readdir(stdlib_root)
            vpath = joinpath(stdlib_root, vdir)
            isdir(vpath) || continue
            for pkg in readdir(vpath)
                if pkg in keep_tests_for
                    continue
                end
                testdir = joinpath(vpath, pkg, "test")
                if ispath(testdir)
                    rm(testdir; recursive=true, force=true)
                    push!(deleted, testdir)
                    verbose && println("Removed: ", testdir)
                end
            end
        end
    end
    return deleted
end

is_checkbounds_enabled(ji_path::AbstractString) = begin
    cf = parse_ji_header(ji_path)[:cache_flags_decoded]
    return cf.check_bounds != 0
end

function remove_test_compiled_libs!(root_dir::AbstractString; verbose::Bool=false)
    removed = String[]
    stdlib_names = list_stdlib_names(root_dir)
    compiled_root = joinpath(root_dir, "share", "julia", "compiled")
    isdir(compiled_root) || return removed
    for vdir in readdir(compiled_root)
        vpath = joinpath(compiled_root, vdir)
        isdir(vpath) || continue
        for pkg in readdir(vpath)
            pkgpath = joinpath(vpath, pkg)
            isdir(pkgpath) || continue
            # Only consider stdlib packages
            pkg in stdlib_names || continue
            for entry in readdir(pkgpath)
                # Consider native code artifacts next to .ji
                (endswith(entry, ".dylib") || endswith(entry, ".so") || endswith(entry, ".dll")) || continue
                libpath = joinpath(pkgpath, entry)
                base = first(splitext(entry))
                jipath = joinpath(pkgpath, string(base, ".ji"))
                if isfile(jipath) && is_checkbounds_enabled(jipath)
                    rm(libpath; force=true)
                    # Remove dSYM bundle if present (macOS)
                    dsym = string(libpath, ".dSYM")
                    if ispath(dsym)
                        rm(dsym; recursive=true, force=true)
                        verbose && println("Removed: ", dsym)
                    end
                    push!(removed, libpath)
                    verbose && println("Removed: ", libpath)
                end
            end
        end
    end
    return removed
end

function remove_checkbounds_ji!(root_dir::AbstractString; verbose::Bool=false)
    removed_ji = String[]
    removed_libs = String[]
    stdlib_names = list_stdlib_names(root_dir)
    compiled_root = joinpath(root_dir, "share", "julia", "compiled")
    isdir(compiled_root) || return (removed_ji, removed_libs)
    for vdir in readdir(compiled_root)
        vpath = joinpath(compiled_root, vdir)
        isdir(vpath) || continue
        for pkg in readdir(vpath)
            pkgpath = joinpath(vpath, pkg)
            isdir(pkgpath) || continue
            # Only consider stdlib packages
            pkg in stdlib_names || continue
            for entry in readdir(pkgpath)
                endswith(entry, ".ji") || continue
                jipath = joinpath(pkgpath, entry)
                if is_checkbounds_enabled(jipath)
                    # Remove the .ji packageimage
                    rm(jipath; force=true)
                    push!(removed_ji, jipath)
                    verbose && println("Removed: ", jipath)
                    # And any adjacent native library with same stem
                    base = first(splitext(entry))
                    for ext in (".dylib", ".so", ".dll")
                        libpath = joinpath(pkgpath, string(base, ext))
                        if isfile(libpath)
                            rm(libpath; force=true)
                            dsym = string(libpath, ".dSYM")
                            if ispath(dsym)
                                rm(dsym; recursive=true, force=true)
                                verbose && println("Removed: ", dsym)
                            end
                            push!(removed_libs, libpath)
                            verbose && println("Removed: ", libpath)
                        end
                    end
                end
            end
        end
    end
    return (removed_ji, removed_libs)
end

function strip_tarball(in_tar_gz::AbstractString; out_tar_gz::Union{Nothing,AbstractString}=nothing, verbose::Bool=true)
    out_tar_gz === nothing && (out_tar_gz = replace(in_tar_gz, ".tar.gz" => "-stripped.tar.gz"))
    mktempdir() do td
        if verbose
            println("Extracting tarball: ", in_tar_gz)
        end
        # Use system tar and disable macOS copyfile metadata
        withenv("COPYFILE_DISABLE" => "1") do
            run(`tar --disable-copyfile -xzf $(abspath(in_tar_gz)) -C $(td)`)         
        end

        root_dir = find_root_directory(td)
        verbose && println("Root: ", root_dir)

        remove_macos_dotfiles!(root_dir; verbose)
        delete_bundled_tests!(root_dir; verbose)
        # Remove native libs compiled with checkbounds=1 first, then remove the .ji packageimages themselves
        remove_test_compiled_libs!(root_dir; verbose)
        remove_checkbounds_ji!(root_dir; verbose)

        if verbose
            println("Repacking into: ", out_tar_gz)
        end
        # Pack the top-level root directory back into a .tar.gz, disabling macOS metadata
        parent = dirname(root_dir)
        base = basename(root_dir)
        withenv("COPYFILE_DISABLE" => "1") do
            run(`tar --disable-copyfile -czf $(abspath(out_tar_gz)) -C $(parent) $(base)`) 
        end
    end
    return out_tar_gz
end

function strip_tree(root_dir::AbstractString; verbose::Bool=true)
    if !isdir(root_dir)
        error("Not a directory: " * root_dir)
    end
    verbose && println("Stripping in place: ", root_dir)
    remove_macos_dotfiles!(root_dir; verbose)
    delete_bundled_tests!(root_dir; verbose)
    remove_test_compiled_libs!(root_dir; verbose)
    remove_checkbounds_ji!(root_dir; verbose)
    return root_dir
end

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia strip_tar.jl <path-to-julia-*.tar.gz | extracted-root-dir> [<out.tar.gz>]")
        exit(1)
    end
    inpath = ARGS[1]
    if endswith(lowercase(inpath), ".tar.gz")
        outpath = length(ARGS) >= 2 ? ARGS[2] : nothing
        res = strip_tarball(inpath; out_tar_gz=outpath, verbose=true)
        println("Wrote: ", res)
    else
        res = strip_tree(inpath; verbose=true)
        println("Stripped: ", res)
    end
end

