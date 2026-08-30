# Entering a cold project from two shells at once kills one of them

`devenv shell` initializes its per-project state under `.devenv/` without
guarding against another `devenv` doing the same thing in the same directory.
When two entries reach a project that has no `.devenv/` yet, one of them exits
non-zero:

```
× Failed to initialize eval cache database: Database error: error returned from database: (code: 5) database is locked
```

The project is the one `devenv init` generates, unmodified. Nothing in this
folder is contrived apart from `repro.sh`.

## Reproduce

```
./repro.sh        # 2 concurrent entries, the case that matters
./repro.sh 10     # any N
```

`repro.sh` deletes `.devenv/`, starts N `devenv shell -q -- true` at once,
prints each exit status and each shell's output, and exits non-zero if any
entry died.

## Observed

devenv 2.2.2, aarch64-darwin.

| entries | `.devenv/` | result |
| --- | --- | --- |
| 1 | cold | 0 of 1 failed, 5 trials |
| 2 | cold | 1 of 2 failed, 5 of 5 trials |
| 2 | warm | 0 of 2 failed, 5 trials |
| 3–10 | cold | 1–4 failed, varying |

Two concurrent entries into a cold project failed on every trial. A warm
`.devenv/` never failed. More than two entries is not worse — the race is at
creation, and the entries that arrive after the file exists are fine.

The eval cache is not the only contended state. Runs at N=3 and above also
produced:

```
× Failed to initialize task cache
```

and the same concurrent entry against a warm `.devenv/` in another project
produced:

```
× Failed to remove existing GC root: No such file or directory (os error 2)
```

The SQLite error under the eval-cache message varies between
`(code: 5) database is locked` and `(code: 5898) disk I/O error`.

Adding a language module (`languages.elixir.enable = true;`) lengthens the
evaluation and widens the window — 4 of 10 rather than 1 of 10 — but does not
change the failure.

## Why two entries at once is ordinary

A process supervisor starts a project's processes together. Manifester runs
each declared process as `devenv shell -- bash -c ...` in the project
directory, so a project declaring a server process and an interactive shell
process gets exactly two concurrent entries every time it is raised. Against a
warm `.devenv/` they miss each other. The first raise in a fresh checkout is
the cold case, and a process dies at startup.
