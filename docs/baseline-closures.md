# Baseline closure sizes — cnixvim, the config cvim replaces

Measured baseline for the `default` and `server` outputs of **cnixvim** at the
rev below. cvim's closure-size targets are anchored to this file, so the
measurement lives in the repo rather than only in the session that produced it.
Bytes are authoritative; the human-readable columns are for quoting.

Measured 2026-07-27 for cvim Unit 1. Source of record:
`results/unit1-baseline-closures.md` in session `27-07-nvim-distro`.

## Subject under measurement

| Field | Value |
|---|---|
| Repo | `/Users/Shared/projects/caoer/cnixvim` |
| Rev | `abe9eb687cc6d0211ec524487294bc573a0e743f` |
| Commit | `2026-07-27 04:21:24 -0400` — "zt-extras: cap shada register persistence at 10 lines" |
| Working tree | **clean** (`git status --porcelain` empty) |
| Measuring host | aarch64-darwin |
| Measured at | 2026-07-27 |

`packages.<system>.default` and `packages.<system>.neovim` are the **same
derivation** — verified by identical `drvPath`, not assumed.

## Results

Closure size = sum of `narSize` over the whole closure, i.e. what
`nix path-info -S` reports. "Self" is the root path's own `narSize`.

| System | Output | Store path | Self (B) | Closure (B) | GiB | GB | Paths | Method |
|---|---|---|---|---|---|---|---|---|
| aarch64-darwin | `server`  | `/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim` | 665,968 | **1,165,950,912** | 1.09 | 1.17 | 561 | local `path-info` |
| aarch64-darwin | `default` | `/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim` | 665,968 | **12,530,080,704** | 11.67 | 12.53 | 1194 | local `path-info` |
| x86_64-linux | `server`  | `/nix/store/62hzk4f8ldkgl3hvgij6hjmq2q9x8lyg-nixvim` | — | **2,756,661,328** | 2.57 | 2.76 | 650 | cache narinfo walk |
| x86_64-linux | `default` | `/nix/store/4yfavx7dkkxvhvhs4akwfc2690ckbca1-nixvim` | — | **13,776,235,480** | 12.83 | 13.78 | 1361 | cache narinfo walk |
| aarch64-linux | `server`  | `/nix/store/11979pnpa3yrv1m6pfaagw8ghnsp98nb-nixvim` | — | **2,806,455,680** | 2.61 | 2.81 | 648 | cache narinfo walk |
| aarch64-linux | `default` | `/nix/store/fczci45xd9i12jmqyjacp1dbb9flhahz-nixvim` | — | **13,629,754,600** | 12.69 | 13.63 | 1361 | cache narinfo walk |

GiB = /2^30, GB = /10^9. The darwin rows were built locally. The linux rows are
read from the binary cache and are included because the CI-disk risk is a linux
number (see F2).

## Findings

### F1 — The remembered `~1.3GB` server figure is a **darwin** number. Linux is 2.4x that.

- aarch64-darwin server measured **1.17 GB** — close to the remembered ~1.3GB.
- x86_64-linux server measured **2.76 GB**, aarch64-linux **2.81 GB**.

The `server` output is the small-host build, and small hosts are linux. The
remembered figure therefore describes the platform the target does not ship to.
Required reduction to reach `900MB`:

| System | Output | Measured | → 900MB / 8GB (decimal) |
|---|---|---|---|
| aarch64-darwin | server | 1.17 GB | −22.8 % |
| x86_64-linux | server | 2.76 GB | **−67.4 %** |
| aarch64-linux | server | 2.81 GB | **−67.9 %** |
| aarch64-darwin | default | 12.53 GB | −36.2 % |
| x86_64-linux | default | 13.78 GB | −41.9 % |
| aarch64-linux | default | 13.63 GB | −41.3 % |

The server target is a two-thirds cut on the platform that matters, not a
quarter. The justification "carries LSP toolchains cvim's server won't" has to
account for ~1.9 GB on linux, not ~0.27 GB.

### F2 — the closure number is right; the runner-disk premise it was compared against is wrong.

Measured x86_64-linux `default` is **13.78 GB (12.83 GiB)**, not ~13 GB. That was
originally compared against an assumed ~14 GB of runner free space, giving ~0.22 GB
of headroom and making `nix-store --gc` between outputs the only reason CI could
pass.

**The runner side has since been measured, and it is 6–8x larger than assumed.**
From the "Disk before build" step of run 30254354601, before any build:

| Runner | Filesystem | Size | Used | Avail |
|---|---|---|---|---|
| x86_64-linux (`ubuntu-latest`) | `/dev/root` | 145G | 58G | **87G** |
| aarch64-linux (`ubuntu-24.04-arm`) | `/dev/root` | 145G | 37G | **108G** |
| aarch64-darwin (`macos-latest`) | `/dev/disk3s1s1` | 320Gi | 12Gi | **94Gi** |

So `default` and `server` fit in one store together with tens of GB spare. The
`nix-store --gc` steps stay in the workflow — they cost seconds and they absorb
both a future image shrink and the closure growth still ahead as layers land — but
they are insurance, not load-bearing.

**Do not set closure-size targets against a 14 GB CI ceiling.** There is no such
ceiling. A size target has to be justified by the small-host delivery target
instead, which is the platform F1 is about.

### F3 — `default` ≈ remembered `~13GB`; the number holds.

12.53 GB darwin / 13.63–13.78 GB linux against a remembered ~13GB. No material
correction beyond F2's precision.

### F4 — State targets in bytes.

`900MB` and `8GB` are ambiguous by a factor that matters at these sizes:

| Target | Decimal | Binary |
|---|---|---|
| 900MB | 900,000,000 | 943,718,400 |
| 8GB | 8,000,000,000 | 8,589,934,592 |

Every reduction above uses the **decimal** reading. Targets should be restated
in bytes so later diffs are unambiguous.

## Reproduction

Run from `/Users/Shared/projects/caoer/cnixvim` at rev
`abe9eb687cc6d0211ec524487294bc573a0e743f`.

### Rev and tree state

```console
$ git -C /Users/Shared/projects/caoer/cnixvim rev-parse HEAD
abe9eb687cc6d0211ec524487294bc573a0e743f

$ git -C /Users/Shared/projects/caoer/cnixvim status --porcelain
                        # (empty — clean)

$ git -C /Users/Shared/projects/caoer/cnixvim log -1 --format='%H %ci %s'
abe9eb687cc6d0211ec524487294bc573a0e743f 2026-07-27 04:21:24 -0400 zt-extras: cap shada register persistence at 10 lines
```

### Outputs exposed, and measuring system

```console
$ nix flake show --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps({k:list(v.keys()) for k,v in d['packages'].items()}))"
{"aarch64-darwin": ["default", "neovim", "server"], "aarch64-linux": ["default", "neovim", "server"], "x86_64-darwin": ["default", "neovim", "server"], "x86_64-linux": ["default", "neovim", "server"]}

$ nix eval --impure --raw --expr 'builtins.currentSystem'
aarch64-darwin
```

### `default` and `neovim` are one derivation

```console
$ nix eval --raw '.#default.drvPath'
/nix/store/mgdnvqviwpadb435rdk0lzdqcbz9wxp0-nixvim.drv
$ nix eval --raw '.#neovim.drvPath'
/nix/store/mgdnvqviwpadb435rdk0lzdqcbz9wxp0-nixvim.drv
```

### Realise both outputs

```console
$ nix build --no-link --print-out-paths '.#server'
/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim

$ nix build --no-link --print-out-paths '.#default'
/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim
```

### Measure — aarch64-darwin (authoritative)

```console
$ nix path-info -S '.#server' '.#default'
/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim	 1165950912
/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim	12530080704

$ nix path-info -Sh '.#server' '.#default'
/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim	   1.1 GiB
/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim	  11.7 GiB

$ nix path-info -S --json '.#server' '.#default' | python3 -c "import json,sys; d=json.load(sys.stdin); [print(k, v.get('narSize'), v.get('closureSize')) for k,v in d.items()]"
/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim 665968 1165950912
/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim 665968 12530080704

$ nix path-info -r '.#server' | wc -l
     561
$ nix path-info -r '.#default' | wc -l
    1194
```

### Measure — linux (from the binary cache)

The linux outputs cannot be built on a darwin host. Their store paths evaluate
fine and `cache.0xtau.com` already holds them, so the closure is summed from
narinfo (`NarSize` + `References`) instead:

```console
$ for s in aarch64-linux x86_64-linux; do for p in server default; do
    echo -n "$s.$p = "; nix eval --raw ".#packages.$s.$p.outPath"; echo; done; done
aarch64-linux.server = /nix/store/11979pnpa3yrv1m6pfaagw8ghnsp98nb-nixvim
aarch64-linux.default = /nix/store/fczci45xd9i12jmqyjacp1dbb9flhahz-nixvim
x86_64-linux.server = /nix/store/62hzk4f8ldkgl3hvgij6hjmq2q9x8lyg-nixvim
x86_64-linux.default = /nix/store/4yfavx7dkkxvhvhs4akwfc2690ckbca1-nixvim
```

The walker is `walk2.py`, reproduced in the appendix. Output:

```console
$ python3 walk2.py /nix/store/62hzk4f8ldkgl3hvgij6hjmq2q9x8lyg-nixvim \
    /nix/store/4yfavx7dkkxvhvhs4akwfc2690ckbca1-nixvim \
    /nix/store/11979pnpa3yrv1m6pfaagw8ghnsp98nb-nixvim \
    /nix/store/fczci45xd9i12jmqyjacp1dbb9flhahz-nixvim
/nix/store/62hzk4f8ldkgl3hvgij6hjmq2q9x8lyg-nixvim	2756661328	paths=650	COMPLETE
/nix/store/4yfavx7dkkxvhvhs4akwfc2690ckbca1-nixvim	13776235480	paths=1361	COMPLETE
/nix/store/11979pnpa3yrv1m6pfaagw8ghnsp98nb-nixvim	2806455680	paths=648	COMPLETE
/nix/store/fczci45xd9i12jmqyjacp1dbb9flhahz-nixvim	13629754600	paths=1361	COMPLETE
```

`COMPLETE` means every path in the closure resolved. A run reporting
`INCOMPLETE` yields a lower bound and must be discarded.

### Walker validation

The linux numbers come from a script, not from `nix`. The script is validated by
running it against the two darwin paths whose true size `nix` already reported —
byte-exact and path-count-exact on both:

```console
$ python3 walk2.py /nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim \
    /nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim
/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim	1165950912	paths=561	COMPLETE
/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim	12530080704	paths=1194	COMPLETE

$ nix path-info -S /nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim \
    /nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim
/nix/store/qxqgwhk9lj34dsf1nlivkx61w14a0csz-nixvim	 1165950912
/nix/store/x88qyf6z0lwi079hasxxnvd1w9fgafy6-nixvim	12530080704
```

## Gotchas hit while measuring

- **`cache.0xtau.com` 403s on the default Python User-Agent.** `curl` and `Nix/*`
  get 200 for the same narinfo URL; `Python-urllib/3.x` gets `403 Forbidden`.
  Any narinfo tooling must set a UA. It presents as "path not in cache".
- **`nix path-info -S --store https://cache.0xtau.com …` is unusably slow.** It
  walks the closure over serial HTTP and did not finish in 5 minutes for one
  path. The concurrent walker does the same work in seconds.
- **`timeout` is not on PATH on the darwin host.** Wrapping `nix eval` in it
  produces `(eval):1: command not found`, which reads like a Nix error.
- **TLS handshake timeouts silently truncate a closure walk.** The first walk
  reported totals 1–20 % low with a handful of unresolved paths. Retries are
  mandatory, and the walker must report completeness rather than just a sum.

## Appendix — `walk2.py`

```python
import sys, time, urllib.request, concurrent.futures as cf
CACHE = "https://cache.0xtau.com"
UA = {"User-Agent": "curl/8.7.1"}
def hashpart(p): return p.split("/")[-1].split("-")[0]
def fetch(h):
    last = None
    for attempt in range(6):
        try:
            req = urllib.request.Request(f"{CACHE}/{h}.narinfo", headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read().decode()
            size, refs = None, []
            for line in body.splitlines():
                if line.startswith("NarSize:"): size = int(line.split(":",1)[1].strip())
                elif line.startswith("References:"): refs = line.split(":",1)[1].split()
            return h, size, refs, None
        except Exception as e:
            last = str(e); time.sleep(1.5 * (attempt + 1))
    return h, None, [], last
def closure(root):
    seen, sizes, missing = set(), {}, []
    frontier = {hashpart(root)}
    with cf.ThreadPoolExecutor(max_workers=16) as ex:
        while frontier:
            todo = [h for h in frontier if h not in seen]
            seen.update(todo); frontier = set()
            for h, size, refs, err in ex.map(fetch, todo):
                if size is None: missing.append((h, err)); continue
                sizes[h] = size
                for r in refs:
                    rh = hashpart(r)
                    if rh not in seen: frontier.add(rh)
    return sum(sizes.values()), len(sizes), missing
for root in sys.argv[1:]:
    total, n, missing = closure(root)
    status = "COMPLETE" if not missing else f"INCOMPLETE({len(missing)} unresolved)"
    print(f"{root}\t{total}\tpaths={n}\t{status}", flush=True)
    for h, e in missing: print(f"    UNRESOLVED {h}: {e}", file=sys.stderr, flush=True)
```
