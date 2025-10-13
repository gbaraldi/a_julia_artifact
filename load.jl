root = first(readdir(artifact"JuliaNoGPL"))
julia_exe = joinpath(artifact"JuliaNoGPL", root, "bin", "julia")