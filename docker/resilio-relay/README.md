# Artemis Resilio Relay Docker Prototype

This is the Resilio Sync 2.x prototype for pulling the Artemis relay server content.

It intentionally uses the full Resilio share link through the Web UI API `addlink` action. Do not extract the raw key and call `addsyncfolder`; that creates the wrong unmanaged folder shape for this managed read-only share.

## Configuration

Copy `env.example` to `.env`, then set:

- `RESILIO_ACCEPT_TERMS=true` if you want the container to accept Resilio terms through the local Web UI API.
- `RESILIO_SHARE_LINK` to the full managed read-only link.
- `RESILIO_WEBUI_PASSWORD` to a local password, or leave it empty and the container will generate one in `data/config/config/artemis-relay/webui-password`.

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

Once the sync content is present, the next step is to add the relay server execution environment on top of the downloaded folder.
