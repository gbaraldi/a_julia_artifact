using ArtifactUtils, Base.BinaryPlatforms
add_artifact!(
    "Artifacts.toml",
    "JuliaNoGPL",
    "https://github.com/gbaraldi/a_julia_artifact/releases/download/julia-1.12-nogpl-1/julia-cdaa753cd7-linux-x86_64-stripped.tar.gz",
    force=true,
    platform=Platform("x86_64", "linux")
)

add_artifact!(
    "Artifacts.toml",
    "JuliaNoGPL",
    "https://github.com/gbaraldi/a_julia_artifact/releases/download/julia-1.12-nogpl-1/julia-cdaa753cd7-macos-aarch64-stripped.tar.gz",
    force=true,
    platform=Platform("aarch64", "macos")
)

add_artifact!(
    "Artifacts.toml",
    "JuliaNoGPL",
    "https://github.com/gbaraldi/a_julia_artifact/releases/download/julia-1.12-nogpl-1/julia-cdaa753cd7-windows-x86_64-stripped.tar.gz",
    force=true,
    platform=Platform("x86_64", "windows")
)