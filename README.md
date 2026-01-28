# jupyter-uv
Jupyter kernel using uv for package and environment management.

# Common tasks

## Launch jupyterlab

```bash
uv run jupyter lab \
    --notebook-dir=/home/dennis/workspace/dennisobrien/ \
    --ServerApp.allow_origin='*' \
    --ServerApp.ip='0.0.0.0'
```

## Adding a kernel

This makes a few assumptions:

1. The other project is managed by `uv`.
2. Both projects are in a directory under `/home/dennis/workspace/dennisobrien/`.

In the other project directory, run:

First, make sure that the environment includes `ipykernel`:
```bash
uv add ipykernel
```

Then, add the kernel to jupyter:
```bash
uv run python -m ipykernel install \
    --name myproject \
    --display-name "Python (MyProject)" \
    --env VIRTUAL_ENV $(pwd)/.venv \
    --prefix /home/dennis/workspace/dennisobrien/jupyter-uv/.venv/
```

# Plugins

https://jupyter-ai.readthedocs.io/en/latest/users/index.html