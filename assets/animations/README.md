# Xland transaction artwork · 21/10/2026

Source: `xland-nft-package.zip` supplied by the project owner on 21/10/2026.
Original artwork is described by its author as project-created vector geometry;
Xland lettering uses Noto Serif 500 and coin lettering uses Be Vietnam Pro,
converted to paths. Their SIL OFL licenses are retained alongside the assets.

The app uses the unchanged local Lottie composition (540×960, 30fps, 8 seconds,
17 layers, no external assets/fonts) and PNG poster as an error fallback.
The original background and coin SVGs are retained as editable design sources.
Only JSON and poster are declared as runtime assets. The preview HTML's controls,
build scripts and embedded web player are not used by the app.

The notice “Tính năng sắp ra mắt” is accessible Flutter text. The artwork does not
enable NFT commerce. Motion pauses outside the active transaction tab, when the
app is backgrounded/covered or the artwork is scrolled out of view, and respects
the system's reduced-motion preference. No full-frame raster cache is enabled.

SHA-256 of unchanged supplied assets:

| File | SHA-256 |
| --- | --- |
| xland-nft.json | 55a25ca6f1d76e90d9b21b9f45407ff08c0f375099418f4633de80d937a507b5 |
| xland-nft-poster.png | 1f57462af644b3b244c475a569343e5fd8e15fd44a78204d66cd6d069eff9365 |
| xland-nft-background.svg | 72c9f2a090b2dfeb0ebb7639d93e39c2f4616a07b083be6890e724a5a635e67f |
| xland-nft-coin.svg | f170f4d5eccbffbecc1641874a911396c5c22454a244c26c406c01ae7d418b4a |

Player dependency is pinned to the unchanged `lottie` 3.3.3 runtime in
`third_party/lottie`, matching the supplied Flutter sample. Its archive checksum,
per-file manifest and MIT license are retained there. The workspace path avoids
the external Windows Pub Cache path that failed in Android Studio.
Package documentation: https://pub.dev/packages/lottie/versions/3.3.3.
