# Quickshell configuration

The bar has two launch profiles, `default` and `alt`. Each profile owns its visual tokens and `qmldir`; its QML component links point to the shared implementations.

```text
components/          Shared QML components and shell root
profiles/default/    Default profile theme and module entry points
profiles/alt/        Alternate profile theme and module entry points
native/              sysmon C++ source, Makefile, and compiled helper
run.sh               Profile launcher (`run.sh [default|alt]`)
reload.sh            Launcher alias
tests/               Isolated regression fixtures
```

Use `./run.sh` for the default profile and `./run.sh alt` for the alternate profile. `native/Makefile` builds `native/sysmon`; both profiles resolve the helper from there.
