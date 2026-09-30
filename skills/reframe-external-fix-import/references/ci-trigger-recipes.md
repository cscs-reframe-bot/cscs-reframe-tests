# CI trigger recipes for external-fix PRs

When a PR imports a fix that adds or changes an opt-in ReFrame option,
test that option via the `CSCS_RFM_EXTRA` variable. The value is
appended to the `reframe` invocation by `ci/alps_uenv.yml` and
`ci/alps.yml`.

## Flexible allocation

The `mpi_cpi` check (and other tests that declare `flexible = variable(bool, value=False)`) defaults to a fixed allocation. To test the flexible path:

```shell
# Use ReFrame's default flex-alloc-nodes=idle
cscs-ci run alps-starlex-uenv;CSCS_RFM_UENV=prgenv-gnu/26.3:v1;CSCS_RFM_EXTRA="-S flexible=True"

# Allocate all partition nodes
cscs-ci run alps-starlex-uenv;CSCS_RFM_UENV=prgenv-gnu/26.3:v1;CSCS_RFM_EXTRA="-S flexible=True --flex-alloc-nodes=all"

# Non-uenv flexible run
cscs-ci run alps-starlex;CSCS_RFM_EXTRA="-S flexible=True"
```

## General pattern

```shell
cscs-ci run alps-<system>-uenv;CSCS_RFM_UENV=<uenv>;CSCS_RFM_EXTRA="<reframe-options>"
```

Multiple options can be combined in the same quoted string:

```shell
CSCS_RFM_EXTRA="-S flexible=True --flex-alloc-nodes=idle --max-retries=2"
```
