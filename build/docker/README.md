# Docker Build Harness

Build the Dalamud plugin from macOS without installing the .NET SDK on the host:

```bash
VERSION=0.6.0.3 build/docker/run-build.sh
```

The script builds a small .NET 10 SDK image, downloads the Dalamud dev bundle into
`.cache/dalamud`, restores packages into `.cache/nuget`, and writes the plugin zip to
`artifacts/RoleplayingVoiceDalamud-$VERSION.zip`.

`VERSION` must be numeric because Dalamud uses it as the plugin assembly version.
