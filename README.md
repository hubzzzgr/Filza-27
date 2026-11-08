# Filza-27 — worse_query only

A sideloadable Filza build with **worse_query as its only filesystem-access
backend**. A dedicated App Group, matching provisioning profile, and signing
entitlement are required. An unsigned IPA cannot supply that authorization.

The source removes MobileHouseArrest identity-trust access, direct MCM query
fallbacks, CMG, the kernel exploit/sandbox escape, kernel APFS helpers,
patchfinders, and Mond's WebKit respring crash. There is no fallback exploit.
Historical `bad_query` and `MCM*` function names are compatibility adapters only;
they execute worse_query/pathleak, not the removed implementations.

## Build and download

The [unsigned IPA workflow](https://github.com/hubzzzgr/Filza-27/actions/workflows/build-unsigned-ipa.yml)
compiles on macOS with Xcode 26.2 and uploads `Filza-27-unsigned-arm64`, containing
the IPA and SHA-256 checksum. Download an artifact from a successful run of the
**worse_query-only changes**; earlier artifacts contain the older mixed build.
[Latest worse_query-only IPA artifact](https://github.com/hubzzzgr/Filza-27/actions/runs/42527893233/artifacts/13636511880).
Compilation, packaging, and static archive checks passed for setup-fix source `f55e03b`
on branch `fix/worse-query-app-group-setup`.
Artifacts expire after 14 days. This artifact has no App Group configured; set
the group in the in-app setup screen (or Info.plist) and sign with a matching
provisioned group before use. The setting cannot create a missing entitlement.

CI only compiles, generates metadata, packages, and uploads. It never launches
Filza, an exploit, or a simulator. A green build does not establish exploit or
device compatibility.

## Signing and compatibility

- Packaged app ID: `com.hubzzzgr.FilzaWorseQuery`. The MobileHouseArrest identity
  is not retained. Your signer may change this to an identifier you control.
- Select an already provisioned group in **worse_query only → App Group setup**,
  or configure `FilzaWorseQueryAppGroup` in Info.plist. Provision the same group
  in `com.apple.security.application-groups`. CI accepts an optional `app_group`
  workflow input or `FILZA_WORSE_QUERY_APP_GROUP` repository variable.
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
