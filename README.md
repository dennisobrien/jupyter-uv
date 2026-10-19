# jupyter-uv
A lightweight, reproducible local JupyterLab server managed by `uv`, with kernels
from other `uv` projects plugged in.

The server's notebook root defaults to the parent directory of this repo, so
sibling projects (e.g. `~/workspace/jupyter-uv`, `~/workspace/myproject`) are all
browsable from one JupyterLab.

# Setup

```bash
uv sync
cp .env.example .env
# Generate a token and put it in .env as JUPYTER_TOKEN:
python3 -c "import secrets; print(secrets.token_hex(24))"
```

`.env` is gitignored. Besides `JUPYTER_TOKEN`, it can set `JUPYTER_PORT`,
`JUPYTER_IP`, and `JUPYTER_NOTEBOOK_DIR` (see `.env.example`). Variables already
set in your environment take precedence over `.env`.

# Common tasks

## Start / stop JupyterLab

```bash
scripts/jupyter-server.sh start     # background server, waits until it responds
scripts/jupyter-server.sh status
scripts/jupyter-server.sh stop      # clean shutdown, including kernels
scripts/jupyter-server.sh restart
```

Then open `http://localhost:8888/lab?token=<JUPYTER_TOKEN>`.

- Logs go to `.run/jupyter.log` (the previous run's log is kept as
  `.run/jupyter.log.1`).
- The server listens on `127.0.0.1` only. Set `JUPYTER_IP=0.0.0.0` to expose it on
  your network.
- If the port is already in use, `start` fails instead of silently picking
  another port (which would break clients configured for the expected port).
- Extra arguments to `start`/`restart` are passed to `jupyter lab`, e.g.
  `scripts/jupyter-server.sh start --ServerApp.allow_origin='*'`.

## Adding a kernel

This assumes the other project is managed by `uv`. In the other project
directory, make sure the environment includes `ipykernel`:

```bash
uv add --dev ipykernel
```

Then register the kernel for your user:

```bash
uv run python -m ipykernel install --user \
    --name myproject \
    --display-name "Python (myproject)" \
    --env VIRTUAL_ENV "$(pwd)/.venv"
```

Kernels installed with `--user` live in `~/.local/share/jupyter/kernels`, so
they survive this repo's `.venv` being recreated. List and remove kernels with
`uv run jupyter kernelspec list` and `uv run jupyter kernelspec remove <name>`.

## Claude Code notebook control (MCP)

Claude Code can drive JupyterLab directly (open notebooks, pick a kernel, edit and
execute cells, read outputs) while you watch the same notebook update live in your
browser.

How it fits together:

- `jupyter-collaboration` and `jupyter-mcp-tools` (in `pyproject.toml`) provide
  real-time sync, so browser and MCP edits stay consistent. Collaboration history
  is stored in `.run/jupyter_ystore.db`.
- `scripts/jupyter-server.sh` runs the server with the fixed `JUPYTER_TOKEN` from
  `.env`, which the MCP client also uses.

Register the `jupyter` MCP server with Claude Code (stored in your local Claude
config, not in this repo). Run this from the repo root:

```bash
claude mcp add jupyter \
    -e JUPYTER_URL=http://localhost:8888 \
    -e JUPYTER_TOKEN="$(grep '^JUPYTER_TOKEN=' .env | cut -d= -f2-)" \
    -e ALLOW_IMG_OUTPUT=true \
    -- uvx jupyter-mcp-server@2.2.4
```

If you change the token or port, remove and re-add the MCP server
(`claude mcp remove jupyter`). MCP servers are loaded when a Claude Code session
starts, so restart the session (or run `/mcp`) after adding or changing it.

Day-to-day usage:

1. Start the server: `scripts/jupyter-server.sh start` (or ask Claude to do it).
2. Open `http://localhost:8888/lab?token=<JUPYTER_TOKEN>` in your browser to watch
   live.
3. Ask Claude to open or create a notebook and run cells. The kernel follows the
   notebook's saved kernelspec (see `uv run jupyter kernelspec list`).
4. Stop the server: `scripts/jupyter-server.sh stop`.

# Plugins

https://jupyter-ai.readthedocs.io/en/latest/users/index.html
