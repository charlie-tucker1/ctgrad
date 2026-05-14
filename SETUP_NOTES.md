# Setup Notes

Environment-specific gotchas hit while setting up this project. Read this before
trying to build on a fresh machine, or after any major system update. Just getting the environment working properly took ~3 hours, would've taken much longer, thanks claude for the help.

## Target environment

- **OS:** Fedora 43
- **GPU:** NVIDIA RTX 5070 (Blackwell, sm_120, compute capability 12.0)
- **NVIDIA driver:** 580+ (supports CUDA 13.x runtime)
- **CUDA Toolkit:** 13.0
- **Host compiler:** gcc 15.2.1
- **Python:** 3.12.x (managed by uv)
- **Build:** CMake 3.27+ with Ninja, scikit-build-core, nanobind

## CUDA toolkit version requirements

CUDA toolkit version dictates the maximum supported gcc version, not the other
way around. Compatibility matrix that matters here:

| CUDA Toolkit | Max gcc | sm_120 (Blackwell) |
| ------------ | ------- | ------------------ |
| 12.7         | 13      | ❌                 |
| 12.8         | 14      | ✅                 |
| 12.9         | 14      | ✅                 |
| 13.0         | 15      | ✅                 |

Fedora 43 ships with gcc 15.2.1 by default, so **CUDA 13.0 is the minimum
version that works without a gcc compatibility package**. Do not install
CUDA 12.x and try to make gcc 15 work — install 13.0.

## Installing CUDA 13.0 on Fedora 43

NVIDIA does not ship a Fedora 43 RPM repo. Use the Fedora 42 repo, it works
on F43:

```bash
sudo dnf config-manager addrepo --from-repofile=\
https://developer.download.nvidia.com/compute/cuda/repos/fedora42/x86_64/cuda-fedora42.repo
sudo dnf clean all
sudo dnf -y install cuda-toolkit-13-0
```

Add to `~/.bashrc`:

```bash
export PATH=/usr/local/cuda-13.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-13.0
```

Verify:

```bash
nvcc --version    # should report 13.0
which nvcc        # should be /usr/local/cuda-13.0/bin/nvcc
```

## REQUIRED PATCH: math_functions.h (rsqrt/rsqrtf noexcept)

**You must apply this patch or no CUDA code will compile.**

### Symptom

```
/usr/include/bits/mathcalls.h(206): error: exception specification is
incompatible with that of previous function "rsqrt" (declared at line 629
of /usr/local/cuda-13.0/.../crt/math_functions.h)
```

Same error for `rsqrtf` at line 653.

### Cause

glibc 2.40+ declares `rsqrt(double)` and `rsqrtf(float)` with `noexcept(true)`.
CUDA 13.0's `math_functions.h` declares them without that exception specifier.
gcc 15 enforces matching exception specs strictly. NVIDIA has not fixed this as
of CUDA 13.1 (March 2026) — it's a known upstream bug.

### Fix

```bash
sudo cp /usr/local/cuda-13.0/targets/x86_64-linux/include/crt/math_functions.h{,.bak}

sudo sed -i 's/rsqrt(double x);$/rsqrt(double x) noexcept (true);/' \
  /usr/local/cuda-13.0/targets/x86_64-linux/include/crt/math_functions.h

sudo sed -i 's/rsqrtf(float x);$/rsqrtf(float x) noexcept (true);/' \
  /usr/local/cuda-13.0/targets/x86_64-linux/include/crt/math_functions.h
```

Verify exactly two lines come back:

```bash
grep -n "rsqrt.*noexcept" /usr/local/cuda-13.0/targets/x86_64-linux/include/crt/math_functions.h
# Expected:
# 629:extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double  rsqrt(double x) noexcept (true);
# 653:extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float   rsqrtf(float x) noexcept (true);
```

### When to reapply

Any `sudo dnf update` or reinstall of `cuda-toolkit-13-0` overwrites the header.
Reapply the patch. The `.bak` next to the file is the unpatched original.

## Python development headers

`uv` provides the Python interpreter, but CMake's `find_package(Python ...
Development.Module)` looks for headers under `/usr/include/python3.12/`. Those
are not installed by default on Fedora.

```bash
sudo dnf install python3.12-devel
```

Without this you get:

```
file STRINGS file "/usr/include/python3.12/patchlevel.h" cannot be read.
Could NOT find Python (missing: Development.Module)
```

## Conda interference

If conda's `(base)` env auto-activates, it puts a conda Python ahead of the uv
venv on PATH and CMake picks up the wrong one. Two options:

Per-shell: `conda deactivate` before working on this project.

Permanent (recommended if conda is not in active use):

```bash
conda config --set auto_activate_base false
```

Always work inside the project venv:

```bash
cd ~/projects/ctgrad
source .venv/bin/activate
```

Prompt should read `(ctgrad)`, not `(base)`.

## Fresh-machine build checklist

1. NVIDIA driver 580+ installed (`nvidia-smi` works)
2. CUDA 13.0 toolkit installed, PATH/LD_LIBRARY_PATH/CUDA_HOME exported
3. `math_functions.h` patch applied (grep returns two lines)
4. `python3.12-devel` installed
5. uv installed (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
6. conda deactivated or not auto-activating
7. System dev tools: `gcc-c++ cmake ninja-build ccache gdb clang-tools-extra`
8. `git clone` this repo
9. `cd ctgrad && uv venv && source .venv/bin/activate`
10. `uv pip install -e ".[dev]"`
11. Verify: `python -c "import ctgrad; ctgrad.hello()"` prints from 8 GPU threads

## Useful diagnostics

When a build fails, these are the first things to check:

```bash
# Which Python is uv actually using?
which python && python --version

# Where does that Python think its headers are?
python -c "import sysconfig; print(sysconfig.get_path('include'))"

# Is the nvcc on PATH the one you expect?
which nvcc && nvcc --version

# Is the GPU actually visible?
nvidia-smi

# Is the math_functions.h patch still in place?
grep -c "rsqrt.*noexcept" /usr/local/cuda-13.0/targets/x86_64-linux/include/crt/math_functions.h
# Should print 2
```

## References

- NVIDIA forum on rsqrt issue: https://forums.developer.nvidia.com/t/fedora-43-and-nvcc-cuda13-1-error-exception-specification-is-incompatible-rsqrt-rsqrtf/354510
- CUDA 13.0 release notes (gcc 15 support): https://developer.nvidia.com/blog/whats-new-and-important-in-cuda-toolkit-13-0/
- Fedora CUDA install guide: https://www.if-not-true-then-false.com/2018/install-nvidia-cuda-toolkit-on-fedora/
