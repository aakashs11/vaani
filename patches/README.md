# FluidAudio compatibility patch

`fluidaudio-0.17.5-unified-repetition.patch` prevents Parakeet Unified's
single-window recordings from entering the overlap-seam duplicate filter.
That filter treats adjacent words differing only in capitalization as overlap
duplicates. In a one-window recording, an opening repetition such as “Yes yes”
can therefore lose its first word even though there is no overlap seam.

The patch passes the actual window count to the existing filter. Multiple-window
cleanup and other recognizers retain their existing behavior. This does not
recover speech that the recognizer never emitted, and it does not solve
repetitions within long recordings that resemble seam artifacts.

The compatibility script applies only to the reviewed FluidAudio 0.17.5
revision and source hashes. It accepts the exact already-patched sources and
refuses changed versions, edited sources, or partial patches. It never downloads
models or resolves dependencies. Run it after package resolution and before
compilation:

```sh
python3 scripts/apply-fluidaudio-patch.py
```

The durable patch lives here rather than only in `.build`. A raw `swift build`
on a fresh checkout does not apply it. Use the repository's documented build
entrypoints, or explicitly run the compatibility script first. Reassess and
remove this patch when upstream provides a suitable fix. Do not loosen its
version or source checks simply to make a dependency upgrade build.

The adapted source remains under FluidAudio's Apache-2.0 license. The original
files and notices stay in the dependency checkout.
