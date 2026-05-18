# Artemis Relay Runtime Docker Prototype

This prototype runs a relay payload that has already been synced onto the host, then mounted into the container.

For local testing, the payload path is:

```text
/Users/damullan/Resilio Sync/Artemis Dialogue Server
```

Copy `env.example` to `.env`, set `ARTEMIS_RELAY_PAYLOAD_PATH`, then run:

```sh
docker compose up --build
```

## Current Payload Status

The synced payload currently contains `CachedTTSRelay.dll`, but its `CachedTTSRelay.runtimeconfig.json` requires `Microsoft.WindowsDesktop.App` and the assembly tries to load `System.Windows.Forms`.

That means the current synced artifact is a Windows Desktop publish (`net7.0-windows`) and will not run in a Linux Docker runtime. The container validates this up front and exits with a clear error instead of failing later with a .NET framework-resolution message.

To make this runtime container viable, the relay needs a Linux-compatible publish that does not require WindowsDesktop/WinForms. Once that artifact exists, mount it at `/payload` with the same compose file.
