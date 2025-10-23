using Printf

include(joinpath(@__DIR__, "strip.jl"))

function verify_tarball(tar_gz::AbstractString; verbose::Bool=true)
    mktempdir() do td
        verbose && println("Extracting: ", tar_gz)
        run(`tar -xzf $(abspath(tar_gz)) -C $(td)`)         
        # Find root
        entries = filter(name -> name != "." && name != "..", readdir(td))
        root_dir = length(entries) == 1 ? joinpath(td, entries[1]) : td

        # 1) Ensure tests are gone
        tests_ok = true
        remaining_tests = String[]
        base_tests = joinpath(root_dir, "share", "julia", "test")
        if ispath(base_tests)
            push!(remaining_tests, base_tests)
            tests_ok = false
        end
        stdlib_root = joinpath(root_dir, "share", "julia", "stdlib")
        if isdir(stdlib_root)
            for vdir in readdir(stdlib_root)
                vpath = joinpath(stdlib_root, vdir)
                isdir(vpath) || continue
                for pkg in readdir(vpath)
                    testdir = joinpath(vpath, pkg, "test")
                    if ispath(testdir)
                        push!(remaining_tests, testdir)
                        tests_ok = false
                    end
                end
            end
        end

        # 2) Check for .ji with checkbounds=true and adjacent native libs
        cb_ok = true
        ji_ok = true
        offenders = String[]
        bad_ji = String[]
        compiled_root = joinpath(root_dir, "share", "julia", "compiled")
        if isdir(compiled_root)
            for vdir in readdir(compiled_root)
                vpath = joinpath(compiled_root, vdir)
                isdir(vpath) || continue
                for pkg in readdir(vpath)
                    pkgpath = joinpath(vpath, pkg)
                    isdir(pkgpath) || continue
                    for f in readdir(pkgpath)
                        endswith(f, ".ji") || continue
                        jipath = joinpath(pkgpath, f)
                        if isfile(jipath)
                            info = nothing
                            try
                                info = parse_ji_header(jipath)
                            catch
                                continue
                            end
                            cf = info[:cache_flags_decoded]
                            if cf.check_bounds === true
                                push!(bad_ji, jipath)
                                ji_ok = false
                                base = first(splitext(f))
                                lib_candidates = [
                                    joinpath(pkgpath, string(base, ".dylib")),
                                    joinpath(pkgpath, string(base, ".so")),
                                    joinpath(pkgpath, string(base, ".dll")),
                                ]
                                for lib in lib_candidates
                                    if isfile(lib)
                                        push!(offenders, lib)
                                        cb_ok = false
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        verbose && println(@sprintf("Tests removed: %s", tests_ok ? "yes" : "NO"))
        if !tests_ok && verbose
            for t in remaining_tests
                println("  still present: ", t)
            end
        end
        verbose && println(@sprintf("No test-compiled native libs left: %s", cb_ok ? "yes" : "NO"))
        if !cb_ok && verbose
            for l in offenders
                println("  offending: ", l)
            end
        end
        verbose && println(@sprintf("No .ji with checkbounds=1 left: %s", ji_ok ? "yes" : "NO"))
        if !ji_ok && verbose
            for j in bad_ji
                println("  offending .ji: ", j)
            end
        end
        return (tests_ok=tests_ok, cb_ok=cb_ok, ji_ok=ji_ok, offenders=offenders, remaining_tests=remaining_tests, bad_ji=bad_ji)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia verify_strip.jl <path-to-*-stripped.tar.gz>")
        exit(1)
    end
    path = ARGS[1]
    res = verify_tarball(path; verbose=true)
    if res.tests_ok && res.cb_ok && res.ji_ok
        println("OK")
    else
        println("FAILED")
        exit(2)
    end
end


