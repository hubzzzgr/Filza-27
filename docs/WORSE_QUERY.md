# worse_query-only build

## Backend boundary

The first migration retained other Filza backends. This revision removes them:

- Kernel exploit, sandbox escape, APFS kernel writers, XPF/ChOma, and patchfinders
  are deleted from the repository/build. 3105 no longer autoruns a kernel exploit.
- MobileHouseArrest identity-trust queries, raw ContainerManager class/part-domain
  fallbacks, and experimental Files/consumer traversal probes are removed.
- CMG, arbitrary token generation/import controls, the sandbox SPI forwarding
  bridge, and Mond's WebKit respring crash are removed from compiled sources.
- The old Rie compatibility probe is removed too.

`FilzaQueryCompat.m` forwards the historical `bad_query`/`mond_bad_query` ABI to
one pinned worse_query provider. These names do not retain the old exploit.
`MCMBridge.m` is now a compatibility facade: it maps container kinds to known
roots, discovers paths with pathleak, grants per-container access with
worse_query, reads metadata, and verifies directory access. It performs no
private ContainerManager query or identity-trust activation of its own.

`MCMFilzaIntegration.m` now only creates local navigation directories/symlinks
and routes file-operation hooks. Old MHA/scoped/experimental access maps are no
longer generated. New App Data links live under `Device Storage/App Data`.
Previously generated links in an existing Documents directory are ordinary
symlinks; without a worse_query grant they confer no access.

`restrict-worse-query.py` runs last after pinned Mond/3105 staging and embedding
patches. It removes alternate methods and controls from generated sources,
removes the unlinked bad_query/CMG/token files, and removes kernel status UI.
Upstream source-completeness checks run before this explicit removal step.
Read-only upstream snapshots may still document removed methods; they are not
compiled or packaged. Staging no longer copies upstream kernel implementations.

Mond's Containers browser, Gestalt, PosterBoard, and file tools remain. Its
respring requests now display manual-restart guidance. 3105 grants access per
operation; there is no process-wide kernel/sandbox success state. Paired-device
services in ByeTunes remain normal pairing functionality, not a fallback escape.

## Signing

The package replaces the base's `com.apple.mobile.MobileHouseArrest` identity
with **`com.hubzzzgr.FilzaWorseQuery`**, and updates the share extension's prefix.
A signer can substitute its own registered ID. No privileged Apple identity is
required or preserved as an access route.

Register/provision a **dedicated, disposable App Group**, set Info.plist string
`FilzaWorseQueryAppGroup` to its ID, and sign with a matching profile/entitlement:

```xml
<key>com.apple.security.application-groups</key>
<array><string>group.your.registered.filza.group</string></array>
```

CI accepts optional workflow input `app_group`, or repository variable
`FILZA_WORSE_QUERY_APP_GROUP`, to package the Info.plist string. It does not create
an App Group or sign/provision the archive. Free-account or entitlement-stripping
signers may not meet the prerequisite. Upstream removes/recreates that group's
`Library/Caches`; do not use a group containing caches/data you need to preserve.
LiveContainer depends on its host's group entitlement, not the guest plist alone.

No configured/accessible group means no worse_query grants. Ordinary access to
the app's own files remains available; no alternate exploit is attempted.

## Limits

Upstream `forcequitOS/worse_query@d1540e20cd82b974d891e0551ced6d6aeb570ac2`
advertises iOS 26.0–26.7.2 / 27.2. This is an upstream claim, not verified Filza
compatibility. Building or installing does not establish exploit functionality.
The deployment target remains iOS 17 for UI and ordinary local features.

Upstream lists Application, InternalDaemon, PluginKitPlugin and AppGroup children,
and, on iOS 27, System/SystemGroup containers and the AppGroup parent. VPNPlugin,
Protected, arbitrary parent directories and `/System/Library` are not assumed to
work. Targets previously exposed by removed backends may be lost. Gestalt and
PosterBoard changes require their exact targets to be accessible/writable. The
signed system volume remains read-only. There is no full jailbreak or root shell.

The two-million-inode scan bound may miss containers. Discovery is not access;
operations still need grants and can fail. Negative errors are not fabricated
success handles. `-256` indicates missing/unavailable App Group configuration or
upstream's ambiguous extension-consumption failure; `-257` is symlink preparation
failure. Handles/releases and newline-separated caller-owned listing buffers keep
the old ABI. All clients serialize the complete upstream Caches transaction.

## Build and verification

The macOS workflow builds the same pinned idevice and SSH dependencies, compiles
arm64 iPhoneOS, generates AppIntents metadata, and packages the checksum-pinned
FilzaSlop binary/resources base. The old injected library is replaced completely.
It copies Mond/3105/ByeTunes resources and strips all Mach-O signatures/profiles.
The base app binary is prebuilt; this repository cannot rebuild proprietary
Filza internals. No claim of auditing every internal path of that binary is made.

CI additionally rejects known removed kernel, CMG/MCM traversal and WebKit
respring markers in the compiled integration library. It never launches the app,
an exploit, or a simulator. Only the IPA/checksum is uploaded as the build artifact.

The worse_query-only revision passed GitHub Actions build
[42525402798](https://github.com/hubzzzgr/Filza-27/actions/runs/42525402798),
source commit `3025bdce373a5a9d0a4e946c67a97abbc863962a`. The first attempt caught
a Swift header-nullability error; it was corrected before this successful run.
The companion 3105 source checks passed too.

[Download the unsigned IPA artifact](https://github.com/hubzzzgr/Filza-27/actions/runs/42525402798/artifacts/13635367665).
IPA SHA-256: `ffaec0e56df5199da7689e1ccf5fad955773eaf86112e384c0320c7ca3c7d09c`.
Static archive inspection verified that checksum, the ordinary app/extension
bundle IDs, `FilzaAccessBackend=worse_query`, status-screen strings, absence of
known removed-backend markers, and absence of profile/signature files.

**No device functionality has been confirmed.** The artifact has no App Group
configured. Set `FilzaWorseQueryAppGroup` and sign/provision the matching group
before expecting cross-container access. Read observations shown by the app are
not full feature tests; write access, Gestalt/PosterBoard changes, pairing,
ByeTunes, WebDAV and SSH behavior remain runtime-unverified. No simulator or
exploit was launched during CI or artifact inspection.

External prerequisites remain Xcode 26.2/macOS runner availability, Theos/ldid,
GNU make, Rust/aarch64-apple-ios and locked crates, CMake/Autotools, pinned native
libraries, the FilzaSlop base IPA, and the pinned ByeTunes v2.5 release used to
recover Config.plist. They were available in the earlier build. Signing and App
Group provisioning are separate runtime prerequisites outside CI.

For local macOS builds, initialize submodules and install the CI tools, then run
`build-idevice.sh`, `build-ssh-stack.sh`, `build-wolfssh-stack.sh`, and
`THEOS=/path/to/theos bash scripts/build_release_ipa.sh base.ipa output.ipa`.

## In-app status

The file browser displays a worse_query-only navigation prompt. Every embedded
feature panel has a `worse_query only` information button. It shows App Group
availability and feature limitations without claiming runtime compatibility.
Normal worse_query requests record up to 64 target read observations, based on
actual directory enumeration/file reads, not just returned handles. The status
view labels them historical, notes that leases may have been released, and does
not claim write access or end-to-end feature functionality. Refreshing the view
reads the snapshot; it does not launch an exploit or perform a write test.
