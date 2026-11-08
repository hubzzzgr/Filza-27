# worse_query provenance

- Upstream: https://github.com/forcequitOS/worse_query
- Revision: `d1540e20cd82b974d891e0551ced6d6aeb570ac2`
- License: GPL-3.0-or-later (see source notices and `LICENSE`).

Only the two library translation units and their headers are vendored. The
upstream Swift app, lifecycle, sample group ID, project, and assets are excluded.

`worse_query.h` and `pathleak.h` are unchanged. Trailing whitespace was
removed from both `.m` files; `worse_query.m` is otherwise unchanged. Local
`pathleak.m` changes add explicit headers, normalize fsgetpath results from
`/private/var/` to `/var/`, and retain Mond's Data-volume statfs fallback when
the target itself is inaccessible. The Filza adapter normalizes the input too.
These preserve legacy listing behavior; they are not runtime compatibility evidence.

Original upstream file SHA-256 values:

```text
edad488641c58bdcfaa30622a5f1c8bcb08c1990d7dfeb1cb26c473ce3cd8c51  worse_query.m
02c919ddec399349ff0a8c1230fea01d590fd30880688da6edbb51ac38365408  worse_query.h
4fa8d48925f2deb0c262899e79fb6a9db41635cb5a6df384390f4e02f001a49d  pathleak.m
98ecc1f375371bb1601904cdfb2aa46279c56c09752d0d820f8275333f193f7c  pathleak.h
```
