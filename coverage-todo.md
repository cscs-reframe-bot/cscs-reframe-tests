# Alps Test Coverage Action Items

Actionable todo list derived from PR #654 (`test_coverage.md`).
Each item is ordered by priority, includes difficulty, and notes the underlying gap.

Priority rationale:

- **P1 (Critical)**: Production-blocking gaps in core Alps functionality or bugs that silently break existing tests.
- **P2 (High)**: Important coverage gaps that affect operational confidence or are prerequisites for P1.
- **P3 (Medium)**: Useful additions or fixes that improve coverage but are not immediately blocking.
- **P4 (Low)**: Nice-to-have or documentation-only follow-ups.

Difficulty levels:

- **Easy**: Small code fix or adding a new sanity-only test.
- **Medium**: Requires new ReFrame test, reference values, or validation logic.
- **Hard**: Multi-node tests, performance baselines, or cross-system coordination.
- **Investigation**: Needs more scoping before effort can be estimated.

| Priority | Area | Action | Motivation | Difficulty | Notes / Suggested Test |
|:---|:---|:---|:---|:---|:---|
| P1 | Scheduler | Fix walltime enforcement gap | Slurm walltime kills are a core scheduler contract; currently untested. | Medium | Add small ReFrame test that submits a job with `--time` and asserts it is killed at the limit. Use `srun sleep` or similar. |
| P1 | CPU & Memory | Fix `dd_blk_size.py` loop bug | The `for ntasks in 1 2` loop never changes task count, so multi-process I/O is not actually exercised. | Easy | Update shell script to set `num_tasks` per iteration or split into two test variants. |
| P1 | MPI / Network | Fix `osu_tests.py` reference lookup bug | `osu_collective_check` never gets a performance reference because of wrong dict indexing. Existing test is broken. | Easy | Change `self.allref[self.num_nodes]` to `self.allref[self.benchmark_info[0]][self.num_nodes]`. |
| P1 | MPI | Fix `mpi_cpi.py` `num_tasks` override | Appscheckout MPI test runs on a single rank despite requesting multi-node. | Easy | Remove or correct `setup_job` override so `num_tasks = -2` is honored when `flexible=False`. |
| P1 | GPU | Fix `coralgemm.py` phantom-GPU guard | Misconfigured nodes with extra phantom GPUs are not detected correctly. | Easy | Change `device_{self.num_gpus+1}` to `device_{self.num_gpus}`. |
| P2 | Scheduler | Add job array test (`sbatch --array`) | Common production workflow, currently uncovered. | Medium | Create small test that runs an array job and checks each task output. |
| P2 | System | Add kernel version consistency check | OS/runtime consistency across nodes is a common source of subtle failures. | Easy | Add test that runs `uname -r` across allocated nodes and diffs output. |
| P2 | System | Add CPU topology consistency check (`lscpu` diff) | Detects BIOS/microcode/configuration drift across nodes. | Medium | Multi-node test that diffs `lscpu` output; must normalize or compare relevant fields. |
| P2 | GPU | Add GPU topology check (`nvidia-smi topo -m`) | Important for multi-GPU and GPU-aware MPI placement. | Medium | Parse `nvidia-smi topo -m` and assert expected NVLink/PCIe topology. |
| P2 | Storage | Fix or replace stale IOR checks (`IorWriteCheck`, `IorReadCheck`) | They have `production` tag but `valid_systems` matches no current system. | Medium | Update `valid_systems` and add Alps-specific reference values. |
| P2 | Network | Add MPI latency sanity test | Critical network health metric; existing OSU latency tests are untagged. | Medium | Tag or re-enable `OSULatency` / `osu_pt2pt_check` for Alps and add references. |
| P2 | Network | Add MPI allreduce sanity test | Collectives are core to many workloads; current test is broken + untagged and CE skips it. | Medium | Fix `osu_collective_check` reference bug (above) and add it to a suite; also re-evaluate `omb.py` `osu_alltoall` skip. |
| P2 | Network | Add `fi_info` / CXI provider checks | Verify libfabric/CXI is usable on plain MPI and CPU partitions. | Medium | Add `fi_info` and `fi_info -p cxi` tests, parse provider output. |
| P3 | System | Add time synchronization check | Detects clock drift that breaks MPI and filesystem operations. | Medium | Run `timedatectl` or `chronyc tracking` and compare across nodes. |
| P3 | System | Add hostname / domain consistency check | Complement to existing `HostnameCheck`. | Easy | Extend `HostnameCheck` or add new test for `hostname -f`. |
| P3 | CPU & Memory | Add CPU frequency under load check | Detects frequency capping or governor misconfiguration. | Medium | Run short stress test and check `/proc/cpuinfo` or `lscpu` reported frequency. |
| P3 | CPU & Memory | Re-enable or replace `DefaultRequest`/`LoginEnvCheck` | Disabled tests that would cover login-vs-compute environment differences. | Medium | Re-enable and update `valid_systems`/expected values for Alps. |
| P3 | CPU & Memory | Add single vs multi-core scaling test | Characterizes CPU performance scaling. | Medium | Add OpenMP/MKL DGEMM test at 1 vs N threads with references. |
| P3 | GPU | Add explicit GPU driver/runtime compatibility check | Current coverage is indirect; a direct version assertion would catch mismatches. | Medium | Compare `nvidia-smi` driver version with CUDA runtime version. |
| P3 | GPU | Add small HIP smoke test | AMD GPUs on Alps are not covered by any basic execution test. | Medium | Minimal HIP kernel test; requires ROCm environment setup. |
| P3 | GPU | Add `--gpus=1` allocation visibility test | Verify Slurm correctly isolates a subset of GPUs. | Medium | Request `--gpus=1` on multi-GPU node and check process sees one GPU. |
| P3 | Storage | Add home / project filesystem read/write tests | User-facing filesystems currently uncovered. | Medium | Lightweight write/read test for `/users` and `/capstor/store`. |
| P3 | Storage | Add metadata stress test (`mdtest` or equivalent) | Small-file performance is a common pain point. | Hard | Add `mdtest`-based test; requires reference values and cleanup handling. |
| P3 | Storage | Add cross-node file visibility test | Sanity check for shared filesystem consistency. | Medium | Node 0 writes, node 1 reads; needs multi-node job. |
| P3 | Network | Add MPI rank distribution test (`srun -N2 -n8 hostname`) | Basic sanity that ranks land as expected across nodes. | Easy | New test or fix `mpi_cpi.py` to run with multiple ranks. |
| P3 | Network | Add `MPICH_OFI_VERBOSE` fabric debug test | Useful for diagnosing fabric issues. | Medium | Run a short MPI job with `MPICH_OFI_VERBOSE=1` and check CXI provider selection. |
| P3 | Network | Add multi-node scaling sanity test | Compare timings across 2 vs 4 nodes for a simple kernel. | Hard | Requires stable reference values and controlled environment. |
| P4 | GPU | Add `nvidia-smi topo` / link matrix check | Detailed GPU interconnect verification. | Medium | Related to P2 GPU topology item; can be separate more detailed test. |
| P4 | GPU | Add GPU isolation between jobs test | Verify Slurm GPU GRES isolation between concurrent jobs. | Hard | Requires job orchestration and concurrent execution; complex to automate reliably. |
| P4 | CPU & Memory | Re-enable NUMA topology / locality tests | `OneTaskPerNumaNode` and `CPUBandwidthCrossSocket` are stale/disabled. | Medium | Update tags and `valid_systems`; may need new reference values. |
| P4 | CPU & Memory | Add cache behavior / stride tests | Currently pinned to old systems. | Medium | Port `strides.py` / `latency.py` to Alps with new references. |
| P4 | Network | Tag or remove stale network tests | `cxi_stat_hsn.py`, `cxi_gpu_loopback_bw.py` have no tags. | Easy | Decide if they should be added to a suite or deprecated. |
| P4 | Storage | Add sequential read/write throughput tests | Replace stale IOR tests with a lightweight alternative if needed. | Medium | `dd_blk_size.py` currently does not report bandwidth. |
| P4 | Tooling / Docs | Keep `test_coverage.md` updated | Coverage audit becomes stale as tests are added/fixed. | Easy | Document update cadence or integrate into release checklist. |

## Recommended sequencing

1. **Merge the easy bug fixes first** (`osu_tests.py`, `mpi_cpi.py`, `coralgemm.py`, `dd_blk_size.py`) — these are P1, low-effort, and fix silently broken tests.
2. **Add core scheduler/system sanity tests** (walltime, kernel consistency, job arrays) — high operational value.
3. **Fix and re-enable MPI/Network coverage** (OSU latency/allreduce, `fi_info`, IOR) — these touch many production workloads.
4. **Add GPU topology and sanity checks** — important for GPU partitions.
5. **Address storage coverage** — filesystem tests require environment knowledge and stable reference values.
6. **Periodically update `test_coverage.md`** to reflect progress and avoid audit drift.
