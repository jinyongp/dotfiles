# Commands

`cmd/bin` is the directory added to `PATH`. Each command there is a relative
symlink to `../run.sh`. The shared launcher uses the invoked name to load
`cmd/<name>/main.sh` in the same Bash process, preserving the public command name
in `$0`, arguments, exit status, and signal handling.

Keep small commands in `main.sh`. Add supporting files and command-specific tests
inside the command's directory when needed. Shared repository helpers remain in
`scripts/lib`.

Run commands through `cmd/bin/<name>` or their name on `PATH`; `main.sh` is an
internal implementation file. To add a command, create `cmd/<name>/main.sh` and
link its entrypoint from the repository root:

```sh
ln -s ../run.sh cmd/bin/<name>
```
