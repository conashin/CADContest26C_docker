# Drop your submission here

Place your built artifacts in this folder, then mount it at `/submission`:

```
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/<owner>/cadcontest26c_docker:latest
```

Supported layouts (op_wrapper.py probes them in this order):

```
# PyInstaller --onefile
submission/
  my_optimizer            # the executable
  _includes/              # (optional) your dependency / data folder

# PyInstaller --onedir
submission/
  dist/my_optimizer/my_optimizer
  dist/my_optimizer/_internal/...
```

Override the lookup path with `MY_OPT_BIN` if your binary lives elsewhere:

```
docker run --rm -e MY_OPT_BIN=bin/my_optimizer \
  -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:latest
```

The contents of this folder (except this README) are git-ignored.
