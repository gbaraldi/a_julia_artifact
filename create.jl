using ArtifactUtils, Base.BinaryPlatforms
add_artifact!(
                     "Artifacts.toml",
                     "JuliaNoGPL",
                     "https://github.com/gbaraldi/a_julia_artifact/releases/download/julia-1.12-nogpl/julia-cde8038cc4-linux-x86_64.tar.gz",
                     force=true,
                     platform=Platform("x86_64", "linux")
                    )

using ArtifactUtils, Base.BinaryPlatforms
add_artifact!(
                     "Artifacts.toml",
                     "JuliaNoGPL",
                     "https://github.com/gbaraldi/a_julia_artifact/releases/download/julia-1.12-nogpl/julia-cde8038cc4-macos-aarch64.tar.gz",
                     force=true,
                     platform=Platform("aarch64", "macos")
                    )

add_artifact!(
    "Artifacts.toml",
    "JuliaNoGPL",
    "https://github.com/gbaraldi/a_julia_artifact/releases/download/julia-1.12-nogpl/julia-cde8038cc4-windows-x86_64.tar.gz",
    force=true,
    platform=Platform("x86_64", "windows")
)