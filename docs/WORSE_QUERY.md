# worse_query migration and unsigned builds

Base inspected: `R0GUEEE/Filza-27@3e1790a`.
Replacement inspected: `forcequitOS/worse_query@d1540e20cd82b974d891e0551ced6d6aeb570ac2`.

## Integration boundary

Previously, `Makefile` compiled both the `73ef6da` bad_query submodule for
Filza/3105 and a namespaced Mond 2.2 bad_query snapshot generated during staging.
Consumers include Apps Manager discovery/access, 3105 browsing/patches/IPA
repackaging, Gestalt, system-path diagnostics, and Mond's access coordinator.

The build now compiles one vendored worse_query implementation plus pathleak
and `FilzaQueryCompat.m`. The old submodule is removed. Vendoring these four
small source files avoids pulling in the proof-of-concept app; provenance and
GPL notices are in `ThirdParty/worse_query/`. Mond staging still retains its
old C snapshot for provenance/source-completeness checks, but neither that
implementation nor its header is linked/imported into the combined target.

The adapter preserves the existing `bad_query` and `mond_bad_query` ABIs,
nonnegative extension handles, release calls, and the malloc-owned,
newline-separated list returned to existing ObjC/Swift consumers. `pathleak`
replaces inode enumeration; `/private/var` and `/var` aliases are normalized.
The existing two-million-inode scan limit remains and can miss containers on
larger/older filesystems. Enumeration alone does not grant access.

`create=true` retains its old meaning of skipping the existence preflight; it
is not a promise to create a target directory. iOS 26 AppGroup targets use the
alternate flags shown by upstream, including when a legacy caller passes
`is_group=false`. All three clients share a lock around worse_query's complete
Caches symlink/query/cleanup operation to avoid racing each other. Handles
remain caller-owned after that operation. Mond's fifth `probe_leaf` argument
was diagnostic only; its old retained diagnostic write-FD probe is omitted.
Existing file-operation/access checks are retained. A handle alone does not
establish readable or writable access.

Filza file browsing, MobileHouseArrest/MCM fallbacks, legacy kernel backends,
3105 tools, pairing, ByeTunes, Mond UI/CMG, PosterBoard, WebDAV, and SSH sources
remain in the build. Their existing OS, identity, permission, service, and
runtime limitations still apply. No new kernel capability is supplied.

## Signing prerequisite

worse_query requires an accessible App Group owned by the signed app. Unlike
bad_query's default system-group route, there is no group-free equivalent.

1. Register/provision a **dedicated, disposable App Group** with your signing
   account. Upstream removes and recreates that group's `Library/Caches`; do
   not reuse a group containing other app data or caches you need to preserve.
2. Set the app's `Info.plist` string `FilzaWorseQueryAppGroup` to that group ID.
   CI accepts the optional `app_group` manual-workflow input, or repository
   variable `FILZA_WORSE_QUERY_APP_GROUP`, and packages this string. This is
   configuration, not an entitlement.
3. When sideloading, sign with a matching provisioning profile and entitlement:

   ```xml
   <key>com.apple.security.application-groups</key>
   <array><string>group.your.registered.filza.group</string></array>
   ```

Without a configured/accessible group, the adapter returns a negative error;
existing features that already have access can still work. The workflow emits
an unsigned IPA and does not create an Apple group, profile, or signing identity.
Ordinary free-account or entitlement-stripping signers may not satisfy this
requirement. A group in Info.plist alone cannot make it accessible.

The base bundle ID remains `com.apple.mobile.MobileHouseArrest` to preserve
Filza's existing identity-dependent route. Normal signing accounts may require
changing it; doing so can break MobileHouseArrest behavior. A signer must resolve
both identity and group provisioning. LiveContainer uses its host identity and
group entitlements, so standalone group access is not implied there either.

New adapter errors: `-256` means missing group configuration, unavailable group,
or upstream's ambiguous `-1` extension-consumption failure; `-257` means Caches
symlink preparation failed. Legacy path errors `-255`/`-254` and query errors
`-1` through `-4` retain their diagnostic meanings. No handles are fabricated.

## Compatibility limits

Upstream's README advertises **iOS 26.0–26.7.2 / 27.2**. This is an upstream
claim, not a device-tested Filza support matrix. Filza's minimum deployment
target stays **iOS 17.0** for its other backends and UI. Compiling or installing
on an OS does not show that worse_query works there.

Upstream lists these paths (normalize `/var`/`/private/var` as appropriate):

```text
/var/containers/Data/System                         (iOS 27)
/var/containers/Shared/SystemGroup/*                 (iOS 27)
/var/mobile/Containers/Data/Application/*
/var/mobile/Containers/Data/InternalDaemon/*
/var/mobile/Containers/Data/PluginKitPlugin/*
/var/mobile/Containers/Shared/AppGroup/*
/var/mobile/Containers/Shared/AppGroup               (iOS 27)
```

The older Filza target list is broader. In particular, do not assume access to
`/System/Library`, VPNPlugin, Protected, other system roots, or arbitrary parent
directories. Gestalt and PosterBoard continue to depend on their precise target
being accessible/writable; the signed system volume remains read-only. No full
jailbreak or unrestricted filesystem access is inferred.

Legacy `bad_query` UI labels/preferences/log keys and 3105 support-policy ranges
remain for compatibility with upstream staging and saved settings. They describe
the old integration and are **not verification of the replacement**. The adapter
does not expand those gates based on upstream's README. Later advertised OS
versions may still be blocked by an embedded feature's older gate.

## Build and artifact

`.github/workflows/build-unsigned-ipa.yml` runs on `macos-15` with Xcode 26.2.
Pushes/PRs to `main` and manual dispatch compile arm64 iPhoneOS sources, generate
AppIntents metadata, and package the unsigned IPA. Download the
`Filza-27-unsigned-arm64` artifact; it contains the IPA and SHA-256 checksum.
The archive must be signed/provisioned by a sideloading tool before installation.

The workflow builds the pinned idevice FFI, libssh/Mbed TLS, and wolfSSH/wolfSSL
libraries before Theos. Generated Mond/3105 sources are staged before Theos
expands its source lists, avoiding fresh-checkout missing-input failures. Existing
build hooks apply the same feature-preserving embedding transformations.

`package-unsigned-ipa.sh` replaces the already-injected dylib in the pinned
FilzaSlop v1.0.2 unsigned base and checks that the base executable has the load
command for it. It copies the Mond/3105 bundles, ByeTunes 2.5 icon/plist/config,
AppIntents metadata, and license, preserving sharing, shortcuts, background audio,
and network declarations. It strips Mach-O signatures/profiles before zipping
`Payload/`. The stale pre-v2.4 YouTubeKit resource requirement was removed because
the pinned ByeTunes 2.5 staging script no longer supplies those JS files.

The previous release publisher is archived under `.github/disabled-workflows/`
so CI uploads artifacts only and cannot publish an unrelated old successful run.
The existing 3105 source-contract workflow remains enabled. No workflow invokes
a simulator, starts Filza, launches an exploit, or performs device/runtime tests.

For a local macOS build, initialize submodules, install Theos/GNU make/ldid and
the native build tools used by CI, then:

```sh
bash scripts/build-idevice.sh
bash scripts/build-ssh-stack.sh
bash scripts/build-wolfssh-stack.sh
# Obtain the checksum-pinned base IPA from the URL in the workflow.
THEOS=/path/to/theos bash scripts/build_release_ipa.sh base.ipa Filza-27-unsigned.ipa
```

The wrapper stages generated sources, compiles, generates metadata, and calls
the same packager. `FILZA_WORSE_QUERY_APP_GROUP` is optional here too.

## Validation and outstanding dependencies

Validated in the Linux editing environment: pinned Mond/3105 source staging
(using a temporary plist-reading shim), every source-transformation hook,
Mond source completeness, base IPA download/SHA-256 and arm64 dylib load command,
ByeTunes v2.5 IPA checksum/configuration staging, YAML parsing, actionlint,
and shell syntax. No app/exploit execution or simulator testing was performed.

**GitHub Actions compilation and unsigned IPA packaging passed** on 2026-11-08:
[build run 42521929984](https://github.com/hubzzzgr/Filza-27/actions/runs/42521929984),
source commit `3e6ccedb90eefdd0fb8f2d215e4dc63787bac58e`. The artifact is
`Filza-27-unsigned-arm64` (IPA plus checksum). The companion 3105 source-contract
workflow passed too. No compiler/linker dependency remained unresolved in this
run. Compilation/packaging do not establish device or exploit compatibility.

The successful build still depends on the selected macOS/Xcode runner image,
Theos/ldid/GNU make, Rust plus the `aarch64-apple-ios` target and locked crates,
CMake/Autotools, and the pinned native-library sources. Downloads also require
GitHub/codeload/raw content, GitLab's libssh mirror, crates.io, the FilzaSlop base
IPA, and the checksum-pinned ByeTunes v2.5 release IPA used to recover Config.plist.
The Filza base binary and ByeTunes runtime configuration are external assets;
they cannot be regenerated entirely from this checkout. Source revisions and
release IPA checksums are pinned, but runner/toolchain availability remains an
external dependency. Device signing/App Group provisioning is a separate,
unresolved runtime prerequisite and is intentionally outside CI.
