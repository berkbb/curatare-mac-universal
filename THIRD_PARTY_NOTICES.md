# Third-Party Notices

Curatare is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version (`GPL-3.0-or-later`, full text in `LICENSE`). Curatare bundles, runs or derives from the following
third-party works. Their license terms are listed below.

## Mole (`tw93/mole`)

- Author: Tw93 and contributors — https://mole.fit / https://github.com/tw93/mole
- Source code: https://github.com/tw93/mole (the exact version, tag, and source of the bundled engine are recorded
  in `Vendor/mole/SOURCE.txt`; inside the app as `Mole-SOURCE.txt`)
- License: GNU General Public License v3.0 (`GPL-3.0`). The full text ships with the app as `Mole-LICENSE.txt`.

```
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU General Public License is a free, copyleft license for
software and other kinds of works.
```

Curatare invokes the bundled `mole`, `analyze-go`, and `status-go` executables as separate child processes and can
update them directly from official `tw93/Mole` GitHub releases via `Scripts/update-mole.sh` or `Mole-Guncelle.command`.

## Arhivar & Copiator (derived components)

Some components of Curatare are derived from Arhivar (GPL-3.0, © Babadogan Tech and Edu,
https://github.com/berkbb/arhivar-mac-universal) and Copiator (GPL-3.0-or-later, © Babadogan Tech and Edu,
https://github.com/berkbb/copiator-mac-universal): the process runner, `ChildProcessGuard`, the `sandbox-exec`
profile generator, disk space helpers, open-safety helpers, the localization engine, the update checker and Ed25519
signature verification, the log console, and the build, packaging and release scripts.

Both projects are licensed under the GNU General Public License version 3 (Copiator: version 3 or later), the same
license family as Curatare; the full license text is in [LICENSE](LICENSE).
