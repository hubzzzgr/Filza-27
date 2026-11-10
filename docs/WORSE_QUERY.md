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

Register/provision a **dedicated, disposable App Group**, sign with a matching profile/entitlement, then select that group in the in-app
**worse_query only → App Group setup** screen. Alternatively, package its ID in
Info.plist string `FilzaWorseQueryAppGroup`:

```xml
<key>com.apple.security.application-groups</key>
<array><string>group.your.registered.filza.group</string></array>
```

CI accepts optional workflow input `app_group`, or repository variable
`FILZA_WORSE_QUERY_APP_GROUP`, to override the dedicated default request in
Info.plist and the main executable's ad-hoc entitlements. CI does not register
an App Group or obtain Apple signing/provisioning. SideStore must provision and
re-sign the request. Entitlement-stripping signers may not meet the prerequisite. Upstream removes/recreates that group's
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
success handles. In the setup-fix revision, `-256` indicates missing/inaccessible
App Group configuration, `-257` is symlink preparation failure, `-258` preserves
upstream's ambiguous group-loss/extension-consumption failure, and `-259` means
a returned handle failed the read check and was released. Earlier IPA versions
used `-256` for both configuration and consumption failures. Handles/releases and newline-separated caller-owned listing buffers keep
the old ABI. All clients serialize the complete upstream Caches transaction.

## Build and verification

The macOS workflow builds the same pinned idevice and SSH dependencies, compiles
arm64 iPhoneOS, generates AppIntents metadata, and packages the checksum-pinned
FilzaSlop binary/resources base. The old injected library is replaced completely.
It copies Mond/3105/ByeTunes resources and strips existing signatures/profiles,
then ad-hoc signs the main executable with the dedicated App Group request.
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

## Setup/logging fix

The original Mond log formatter printed its success message for unrecognized
negative errors, including `-256`. That did not mean access was granted. The
coordinator now uses a dedicated failure branch with descriptive error text.
When no accessible App Group is selected, it marks all grants unavailable and
skips dependent MobileGestalt, PosterBoard and container requests. Concurrent
coordinator invocations are suppressed. A positive Mond handle must also pass
an actual target read check (including the MobileGestalt plist when requested);
this still does not prove write access or full feature compatibility.

The in-app group setting selects a group already provisioned for the signed
app; it cannot add entitlements or register a group. It validates accessibility
before saving, never automatically chooses another app's group, and keeps the
packaged setting as a fallback. Restart Filza after changing it to refresh
startup container discovery. Missing provisioning must be fixed by signing.

The setup/logging fix built successfully in run
[42527893233](https://github.com/hubzzzgr/Filza-27/actions/runs/42527893233),
source `f55e03be09c79f730fd2dd6687fb7d8c624d0d29`, on isolated branch
`fix/worse-query-app-group-setup`; `main` remains unchanged.
[Download this fix's artifact](https://github.com/hubzzzgr/Filza-27/actions/runs/42527893233/artifacts/13636511880).
IPA SHA-256: `dbc7aea359a45f56aa85a677ec81967647ed45f204d991c9c315479bc34b38ea`.
Static archive inspection confirmed the setup button and corrected log strings,
absence of the old false-success/generic kernel-rejection messages, the ordinary
bundle identity, and absence of known removed-backend markers. No runtime
exploit or device feature test was performed; provisioning remains a device-side
prerequisite. Existing Tweak/activation/file-operation hooks were not modified
by this focused fix.

## Bundled default group request

The new package requests `group.com.hubzzzgr.FilzaWorseQuery` by default. Its main
executable has an **ad-hoc signature containing only the App Group request**, so
SideStore can detect the request and register/assign the group when it provisions
and re-signs the app. It is not Apple-signed or pre-provisioned, and cannot be
installed/run directly as an authorized app. CI has no Apple account credentials.
This package is named sideloadable, not fully unsigned. Other signatures/profiles
are stripped before the request is applied; SideStore signs them for installation.

At runtime the default resolver reads this process's signed App Group entitlement
through SecTask, and selects a single accessible exact/default-plus-suffix match.
This handles SideStore's `.TEAMID` suffix without choosing unrelated groups. If
entitlement inspection is unavailable or provisioning failed, the app stays
blocked and shows the setup error. There is no entitlement bypass or fallback
exploit. Existing manual overrides still take precedence; select Use packaged
setting to restore the automatic default. The group is dedicated and disposable
because worse_query recreates its Library/Caches during a request.

The default-group follow-up was compiled and packaged successfully in
[run 42746066500](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500) for source `3945c2d`.
[Download the IPA and checksum](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500/artifacts/13731775630).
IPA SHA-256: `048e7241a3b0e5c47d37eaa7b2b97d79035d4a9bec5419aa38693c852983d63a`.
Static Mach-O signature inspection confirmed the dedicated group request and
ad-hoc flag; no Apple provisioning profile is bundled. Device access remains
unverified. Older build results above describe their historical artifacts, not
the new default-group package.

The subsequent plist navigation-selector fix preserves this group request and
backend setup: [build 42748910629](https://github.com/hubzzzgr/Filza-27/actions/runs/42748910629), source `766d555`.
[Latest IPA](https://github.com/hubzzzgr/Filza-27/actions/runs/42748910629/artifacts/13733062239), SHA-256
`9cc0dd1325d181c3042279c52d41b554865e35e7e337d6e892075035875304f1`. Static inspection reconfirmed the default entitlement request;
this UI fix adds no runtime exploit compatibility evidence.
