# Filza-27 — worse_query only

This follow-up packages a dedicated App Group request for SideStore and resolves
its signed team-suffixed ID automatically. It carries an ad-hoc entitlement request,
not an Apple-authorized signature/profile; SideStore must provision and re-sign it.
It also defers plist search attachment until loading finishes and suppresses the
recurring Not activated notice without modifying activation state. The latest
plist crash trace is still needed to confirm device behavior.

This branch patches the plist editor's deprecated search-controller NIB and
adds a UISearchController-backed adapter, removes the custom support popup,
and removes the music toolbar/shortcut entry. [Download the follow-up sideloadable IPA](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500/artifacts/13731775630).
See [static verification and search compatibility limits](docs/PLIST_SEARCH_FIX.md).
No simulator or app launch was used for verification.

A sideloadable Filza build with **worse_query as its only filesystem-access
backend**. A dedicated App Group, matching provisioning profile, and signing
entitlement are required. An unsigned IPA cannot supply that authorization.

The source removes MobileHouseArrest identity-trust access, direct MCM query
fallbacks, CMG, the kernel exploit/sandbox escape, kernel APFS helpers,
patchfinders, and Mond's WebKit respring crash. There is no fallback exploit.
Historical `bad_query` and `MCM*` function names are compatibility adapters only;
they execute worse_query/pathleak, not the removed implementations.

## Build and download

The [sideloadable IPA workflow](https://github.com/hubzzzgr/Filza-27/actions/workflows/build-unsigned-ipa.yml)
compiles on macOS with Xcode 26.2 and uploads `Filza-27-sideloadable-arm64`, containing
the IPA and SHA-256 checksum. Download an artifact from a successful run of the
**worse_query-only changes**; earlier artifacts contain the older mixed build.
[Latest sideloadable IPA artifact](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500/artifacts/13731775630).
Compilation, packaging, and static archive checks passed for source `3945c2d`
on branch `fix/plist-lifecycle-default-group` ([build](https://github.com/hubzzzgr/Filza-27/actions/runs/42746066500)).
Artifacts expire after 14 days. This IPA includes an ad-hoc request for the default
App Group; SideStore must provision and re-sign it. The app automatically resolves
the accessible signed group, including a team suffix. Select **Use packaged setting**
to clear a previously saved manual override. No device functionality is confirmed.
IPA SHA-256: `048e7241a3b0e5c47d37eaa7b2b97d79035d4a9bec5419aa38693c852983d63a`.

CI only compiles, generates metadata, packages, and uploads. It never launches
Filza, an exploit, or a simulator. A green build does not establish exploit or
device compatibility.

## Signing and compatibility

- Packaged app ID: `com.hubzzzgr.FilzaWorseQuery`. The MobileHouseArrest identity
  is not retained. Your signer may change this to an identifier you control.
- Default App Group request: `group.com.hubzzzgr.FilzaWorseQuery`. SideStore must
  register/assign it and sign a matching profile/entitlement. The app selects its
  accessible signed default automatically. The in-app setup screen retains an
  override for other already provisioned groups. CI also accepts an optional
  `app_group` input or `FILZA_WORSE_QUERY_APP_GROUP` repository variable.
- Use a dedicated, disposable group: upstream worse_query replaces its
  `Library/Caches` during a request. No group means no cross-container grants.
- Upstream advertises iOS 26.0–26.7.2 / 27.2. This is not a device-tested Filza
  compatibility matrix. The app's deployment target remains iOS 17 for UI and
  ordinary sandbox-local features; no alternate iOS 17/18 exploit remains.
- Access is per target. Discovery can miss containers because inode scanning is
  bounded. Read access does not imply write access or a writable system volume.

See [implementation, signing, validation, and limitations](docs/WORSE_QUERY.md).

## Features

The file browser, app/container browsing, 3105 patch workspace and ZIP/IPA
repackaging, shared device pairing, ByeTunes, Gestalt, PosterBoard/Tendies,
WebDAV, and SSH/SFTP remain. Their operations now depend on ordinary sandbox
permissions or worse_query grants. Some targets previously reached by other
backends will no longer be accessible. No full jailbreak or root access is
provided. WebDAV/SSH device behavior remains unverified.

Mond's former HouseArrest browser is labeled **Containers** and uses worse_query.
Changes that require a restart now prompt for a manual restart; no respring
exploit is included. Pairing-based services used by ByeTunes are ordinary paired
device functionality, not an alternate in-process filesystem escape.

## Credits

- [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop) / [FilzaJailedDS](https://github.com/34306/FilzaJailedDS)
- [worse_query](https://github.com/forcequitOS/worse_query)
- [Mond](https://github.com/rooootdev/mond), [3105](https://github.com/YangJiiii/3105), [ByeTunes](https://github.com/EduAlexxis/ByeTunes)
- GCDWebServer, idevice, wolfSSH/wolfSSL, libssh/Mbed TLS and their contributors

Upstream licenses and provenance remain in the source tree.
