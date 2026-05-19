# Artemis Resilio Relay Docker Prototype

This is the Resilio Sync 2.x prototype for pulling the Artemis relay server content and starting the synced relay payload in a Linux .NET container.

It intentionally uses the full Resilio share link through the Web UI API `addlink` action. Do not extract the raw key and call `addsyncfolder`; that creates the wrong unmanaged folder shape for this managed read-only share.

The synced relay payload is a `net7.0-windows` publish. The container does not run its Windows-only `Main()` entrypoint. Instead, it runs a small Linux .NET shim that loads `CachedTTSRelay.dll` as a library and invokes the relay listener methods directly:

- `StartAudioRelay()` on port `5670`
- `StartServerListService()` on port `5677`
- `StartInformationService()` on port `5684`

## Configuration

Copy `env.example` to `.env`, then set:

- `RESILIO_ACCEPT_TERMS=true` if you want the container to accept Resilio terms through the local Web UI API.
- `RESILIO_SHARE_LINK` to the full managed read-only link.
- `RESILIO_WEBUI_PASSWORD` to a local password, or leave it empty and the container will generate one in `data/config/config/artemis-relay/webui-password`.
- `ARTEMIS_RELAY_BIND_HOST=0.0.0.0` if the relay should be reachable from other machines. The default is `127.0.0.1`.
- `ARTEMIS_RELAY_ENABLED=false` if you only want to sync content and not start the relay.

The default content path is `/mnt/mounted_folders/Artemis Dialogue Server`. Keep `RESILIO_SYNC_PATH` under `/mnt`; the official 2.x Docker image rejects destinations outside its `/mnt` root.

## Run

```sh
docker compose up --build
```

The Web UI is exposed at <http://127.0.0.1:18890/gui/>.

The first expected success state in the logs looks like:

```text
has_key=true onlinepeerscount=2 ismanaged=true iswritable=false access=2
```

Once the minimum relay payload is present, the same container starts the shim. Expected relay startup logs look like:

```text
[artemis-bootstrap] starting relay shim from /opt/artemis/relay-shim/ArtemisRelayShim.dll
[artemis-relay-shim] invoking StartAudioRelay
[artemis-relay-shim] invoking StartInformationService
[artemis-relay-shim] invoking StartServerListService
Information Server Started
Server started
```

The monitor loop logs both sync and relay health:

```text
[artemis-bootstrap] sync status: path=/mnt/mounted_folders/Artemis Dialogue Server has_key=true onlinepeerscount=1 ...
[artemis-bootstrap] relay status: pid=42 port_5670=listening port_5677=listening port_5684=listening
```

The relay ports expect specific POST body formats. The monitor checks that the ports are listening instead of issuing generic HTTP health requests, because blind `GET /` probes can create pending relay requests.

## Notes

This is still a compatibility approach: the shim bypasses the Windows-only updater/startup path, but the relay code and cache payload are still proprietary binaries from the sync share. If the relay internals begin using Windows-only APIs in the listener path, the container logs should show the shim or relay exception directly.
