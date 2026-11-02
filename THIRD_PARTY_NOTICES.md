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

Some components of Curatare are derived from Arhivar (MIT, © Babadogan Tech and Edu,
https://github.com/berkbb/arhivar-mac-universal) and Copiator (GPL-3.0-or-later, © Babadogan Tech and Edu,
https://github.com/berkbb/copiator-mac-universal): the process runner, `ChildProcessGuard`, the `sandbox-exec`
profile generator, disk space helpers, open-safety helpers, the localization engine, the update checker and Ed25519
signature verification, the log console, and the build, packaging and release scripts.

```
MIT License

Copyright (c) 2026 Babadogan Tech and Edu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
