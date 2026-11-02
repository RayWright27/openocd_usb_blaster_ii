# winbuild: сборка и измерения OpenOCD на Windows

В git входят только сборочные `build.ps1`, `build.sh`, этот README и
`winbuild/.gitignore`. Тулчейн, каталоги сборки, бинарники, логи, архивы и
локальные скрипты запуска не коммитятся и перечислены в `winbuild/.gitignore`.

## Состав

| Путь | Что это |
|---|---|
| `build.ps1` | сборка одной командой (PowerShell) |
| `build.sh` | то же внутри MSYS2 (вызывается из `build.ps1`) |
| `toolchain/msys64/` | MSYS2 (UCRT64) с gcc 16.2, autotools, libusb 1.0.30, libftdi 1.5, git (≈1,5 ГБ) |
| `dl/` | исходный архив MSYS2 `msys2-base-x86_64-20260927.tar.zst` (для воссоздания тулчейна) |
| `build/<имя>/` | каталоги сборки (вне дерева исходников) |
| `bin/<имя>/` | готовые `openocd.exe` + `libusb-1.0.dll`, `libftdi1.dll` |
| `scripts/` | локальные `aco_prep_local.tcl`, `run_ocd.ps1`, `selftest_wrapper.tcl` (не в git) |
| `logs/` | логи сборки и запусков |

В репозиторий входят `build.ps1`, `build.sh`, `README.md` и `.gitignore`.
Остальные пути локальные и игнорируются.

## Быстрый старт на другом ПК

Если MSYS2 UCRT64 уже лежит в `winbuild/toolchain/msys64`:

```powershell
.\winbuild\build.ps1
```

Если сабмодуль `jimtcl` ещё не инициализирован, `build.sh` сделает
`git submodule update --init jimtcl` автоматически.

## Как собрать

```powershell
.\winbuild\build.ps1                 # build\base  ->  bin\base\openocd.exe
.\winbuild\build.ps1 -Name dev       # отдельная сборка (bin\dev), эталон base остаётся нетронутым
.\winbuild\build.ps1 -Reconfigure    # заново bootstrap + configure
.\winbuild\build.ps1 -Clean          # стереть build\<имя> и собрать заново
```

Или из терминала MSYS2: запустить `winbuild\toolchain\msys64\ucrt64.exe`, затем
из корня репозитория выполнить `bash winbuild/build.sh base`.

Конфигурация: `--enable-internal-jimtcl --enable-usb-blaster --enable-usb-blaster-2 --disable-jlink
--disable-internal-libjaylink --disable-werror`. Подмодуль `jimtcl` инициализируется автоматически,
если его ещё нет. `libjaylink` не нужен.

## LF вместо CRLF (важно)

У Git for Windows системный `core.autocrlf=true`, поэтому дерево по умолчанию лежит в CRLF, а на CRLF
autotools падают. Типичный симптом: `configure.ac:798: error: '\ ' is already registered with AC_CONFIG_FILES`
(дело не в версии autoconf). Поэтому в этом репозитории **локально** (`.git/config` и
`.git/modules/jimtcl/config`) выставлено `core.autocrlf=false`, `core.eol=lf`, а файлы дерева переписаны
из индекса. `build.sh` проверяет `configure.ac` и останавливается с понятной ошибкой, если там снова CRLF.

Для нового клона на Windows:

```powershell
git -c core.autocrlf=false clone <репозиторий> openocd_usb_blaster_ii
cd openocd_usb_blaster_ii
git config core.autocrlf false
git config core.eol lf
git submodule update --init jimtcl
git -C jimtcl config core.autocrlf false
git -C jimtcl config core.eol lf
```

Откат к CRLF (не проверялся): выставить `core.autocrlf true`, затем
`git ls-files -z | grep -zv '^\.gitignore$' | xargs -0 touch` и
`git ls-files -z | grep -zv '^\.gitignore$' | xargs -0 git checkout-index -f -u --`.
Сборка при этом перестанет работать.

## Запуск OpenOCD на плате

Локальные скрипты (не входят в git) используют внешние компоненты этого ПК:
xPack-скрипты `C:/Program Files (x86)/xpack-openocd-0.12.0-7/openocd/scripts`,
прошивку адаптера `C:/altera/14.1/qprogrammer/bin64/blaster_6810.hex`,
`readelf`/`nm` из `C:/altera/14.1/embedded/...`. Каталоги `test/` с образами и
`scripts/` тоже локальные и в git не входят.

- `scripts/aco_prep_local.tcl`: обёртка над `test/dbg-2cores.tcl` (он не меняется). `aco_prep` =
  первая половина `aco_boot` (halt, CPU1 в сбросе, SPL до `spl_boot_device`, проверка ПЛИС, стоп).
  В сеансе OpenOCD (`telnet localhost 4444`):
  `source <репозиторий>/winbuild/scripts/aco_prep_local.tcl`, затем `aco_prep`.
- `scripts/run_ocd.ps1`: один запуск `openocd` с жёстким таймаутом и логом в `logs/`. Адаптер не
  открывается, пока в `-Cmds` нет `init`.
- `scripts/selftest_wrapper.tcl`: проверка обёртки без железа (`bin\base\openocd.exe -f winbuild/scripts/selftest_wrapper.tcl`).

Правила работы с платой: см. `CLAUDE.md` (проект прошивки только для чтения; в память платы и флеш
без подтверждения не писать).

## USB-Blaster II: batch TDO (патч в `bin/dev`)

В `bin/dev` включён патч драйвера `usb_blaster`:

- TDO одного скана читается одним USB-обменом вместо двух;
- команда `usb_blaster batch <n>` накапливает TDO нескольких сканов;
- по умолчанию `batch=1` — поведение без накопления;
- накопление ограничено 128 байтами TDO, большие batch дробятся автоматически.

Пример для загрузки и проверки:

```tcl
usb_blaster batch 16
load_image test/ACO_firmware_core0.axf 0 elf
usb_blaster batch 8
verify_image test/ACO_firmware_core0.axf 0 elf
```

Безопасные значения на проверенной плате:

| batch | Core0 266 320 Б | примечание |
|---:|---|---|
| 1 | 11,4–13,8 с, 18,9–22,9 KiB/s | безопасно всегда |
| 2 | 9,4–9,5 с, 27,3–27,5 KiB/s | безопасно |
| 4 | 8,5–9,7 с, 26,9–30,5 KiB/s | безопасно |
| 8 | 8,3–9,8 с, 26,5–31,4 KiB/s | безопасно для загрузки и чтения |
| 16 | 7,7–9,2 с, 28,4–33,5 KiB/s | быстро, но `verify_image` при 16 вешает адаптер |
| 24+ | — | не использовать: USB timeout |

Практическая схема: **load при `batch=16`, verify/чтение при `batch=8`**. Для
`aco_boot` целиком используйте `batch=8` — он безопасен и для загрузки, и для
финального `halt`/чтения регистров.

### CLion / рабочая машина

Если используется локально собранный `openocd.exe`, а скрипты берутся из xPack,
нужно явно указать путь к скриптам и положить рядом `libusb-1.0.dll` и
`libftdi1.dll`:

```text
-s H:/xpack-openocd-0.12.0-7/openocd/scripts
```

В конфигурации Embedded GDB Server команду batch добавляют между `init` и
`aco_boot`:

```text
-c init -c "usb_blaster batch 8" -c aco_boot
```

`OpenOCD Download & Run` для этой платы не подходит: он рассчитан на загрузку
одного ELF через GDB и reset, а здесь нужна последовательность SPL → Core1 →
Core0.

## Тулчейн: как воссоздать

1. Распаковать `dl/msys2-base-x86_64-20260927.tar.zst` (`tar -xf ... -C <папка>`), перенести содержимое
   `msys64/` в `toolchain/msys64/`.
2. Один раз запустить `toolchain\msys64\usr\bin\bash.exe -l` (первичная настройка keyring).
3. Обновить систему: `pacman -Syu --noconfirm`. **Первый проход закрывает собственный терминал**
   (штатно для MSYS2), запустить его ещё раз.
4. Поставить пакеты:
   `pacman -S --needed --noconfirm git make autoconf automake libtool texinfo patch diffutils`
   `mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-pkgconf mingw-w64-ucrt-x86_64-libusb mingw-w64-ucrt-x86_64-libftdi`.

Почему UCRT64, а не MINGW64: в репозитории `mingw64` MSYS2 (2026) нет `libusb`, `libftdi`, `hidapi`.
Подпись архива MSYS2 не проверялась (по решению владельца).

## Предостережения

- `git clean -fdx` удалит локальный тулчейн и артефакты в `winbuild/` (≈1,5 ГБ); отслеживаемые
  скрипты останутся. Безопасно: `git clean -fd` (без `-x`).
- Не используйте ключ `-l` у `openocd`: обратные слэши в пути он разбирает как escape-последовательности
  и создаёт файл с искажённым именем в текущем каталоге.
- Если открыть репозиторий в IDE, исключите из индексации только `toolchain/`, `build/`, `bin/`, `logs/`.
- Версия OpenOCD в `--version` оканчивается на `-dirty`, пока в дереве есть изменения (в том числе правка `.gitignore`).
