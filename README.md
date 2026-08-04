# MAcordion 🪗
*Vibe coded by bruiselea*

[English](#english) | [日本語](#日本語)

## English

MAcordion turns your MacBook itself into a playable instrument. Open and close
the display to move the on-screen bellows, then use the Mac keyboard to play
notes. The hinge speed controls the airflow and expression, so the physical
movement of the computer becomes part of the performance.

![MAcordion performance interface](Design/macordion-studio-minimal-implementation.png)

## What MAcordion includes

- **Physical bellows control** — the vertical bellows follows the measured
  MacBook display angle directly, without visual spring lag.
- **Playable Mac keyboard** — notes remain responsive while the hinge is moving.
- **Native sensor access** — the hinge edition uses macOS IOHID directly, with
  no Python, pybooklid, or Homebrew dependency.
- **Focused performance UI** — the main window keeps only the instrument,
  essential controls, keyboard, and an unobtrusive air-expression meter.
- **Separate diagnostics** — connection state, hinge angle, and air pressure
  live in the native **MAcordion → Settings…** window.
- **English and Japanese** — interface copy, onboarding, accessibility labels,
  Settings, and permission descriptions follow the Mac's preferred language.
- **Three input editions** — Hinge, Breath, and Shisha variants share the same
  instrument and keyboard mapping.
- **Reproducible Universal 2 packages** — release ZIPs support Apple Silicon
  and Intel Macs.

<details>
<summary>Sensor diagnostics</summary>

Open **MAcordion → Settings…** to inspect the live sensor state without adding
diagnostic clutter to the performance view.

<img src="Design/macordion-settings-diagnostics.png" alt="MAcordion sensor diagnostics settings" width="420">

</details>

## Safety notice

> **USE AT YOUR OWN RISK:** This application reads MacBook hardware sensors
> (lid angle / hinge) and can access the microphone in Breath mode. Move the
> display gently and never force the hinge beyond its normal range. The
> developers assume no liability for device damage or data loss.

## Launch Options

Three separate apps share the same audio engine and key mapping:

- **MAcordion** — bellows driven by the MacBook lid angle sensor (classic accordion).
- **MAcordionBreath** — bellows driven by microphone amplitude (melodica style).
- **MAcordionShisha** — bellows driven by the USB-C-to-Shisha differential-pressure sensor (ESP32-C3 firmware).

With Swift Package Manager:

```bash
swift run MAcordion        # Hinge sensor version
swift run MAcordionBreath  # Breath (microphone) version
swift run MAcordionShisha  # Shisha sensor version
```

If the bellows source is unavailable (no hinge sensor, no mic permission, no shisha device plugged in), the app falls back to a keyboard-only mode with fixed expression.

### Shisha sensor setup
Flash `firmware/esp32c3/shisha_sensor/shisha_sensor.ino` onto an ESP32-C3 Supermini wired to an MPXV7002DP via a 10k/27k divider, plug it in via USB-C, then `swift run MAcordionShisha`. The app auto-detects `/dev/cu.usbmodem*`. Override with `SHISHA_PORT=/dev/cu.usbmodemXXXX swift run MAcordionShisha` if multiple devices are connected.

## Controls

| Key | Function |
|-----|----------|
| `A S D F G H J K L ;` | White keys (C D E F G A B C D E) |
| `W E T Y U O P` | Black keys (C# D# F# G# A# C# D#) |
| `Spacebar` | Air Valve — pump the bellows without sound |
| `Tab` | Toggle Sustain on/off |
| `Z` | Octave Down |
| `X` | Octave Up |

> Make sure the MAcordion window has focus before playing.

## Requirements

- macOS 13.0+
- Swift 5.9+ / Xcode 15+
- Hinge version: a supported MacBook lid-angle sensor
- Breath version: microphone access (macOS will prompt on first launch)

## Reproducible release packages

Create signed application bundles and deterministic ZIP archives with:

```bash
./scripts/package.sh
```

The command builds Universal 2 binaries for Apple Silicon and Intel, then
writes all three release variants to `dist/`:

- `MAcordion-<version>-<architecture>.zip`
- `MAcordionBreath-<version>-<architecture>.zip`
- `MAcordionShisha-<version>-<architecture>.zip`
- `SHA256SUMS` and `BUILD-INFO.txt`

The default signature is ad hoc, so these local packages are not notarized.
On another Mac, Control-click the app and choose **Open** on first launch.
For normal Gatekeeper-approved distribution, set `SIGN_IDENTITY` to a
Developer ID Application certificate and notarize the resulting archive.
Version and build metadata can also be overridden:

```bash
APP_VERSION=1.4.0 BUILD_NUMBER=1 \
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
./scripts/package.sh
```

For byte-for-byte ZIP reproduction, use the same source revision, Xcode/Swift
toolchain, macOS SDK, CPU architecture, signing identity, and
`SOURCE_DATE_EPOCH`. The exact build environment is recorded in
`dist/BUILD-INFO.txt`.

To build only one architecture, set `ARCHITECTURES`, for example:

```bash
ARCHITECTURES=arm64 ./scripts/package.sh
```

---

## 日本語

MAcordionは、MacBookそのものを楽器にするmacOSアプリです。ディスプレイの
開閉と画面上の蛇腹が同期し、ヒンジを動かす速さで空気の流れと音の表情を
コントロールできます。Macのキーボードで音階を演奏します。

### MAcordionの特徴

- **物理的な蛇腹操作** — MacBookのディスプレイ角度と、縦方向の蛇腹が
  遅延を加えず直接同期します。
- **キーボード演奏** — ヒンジを動かしている間も、Macのキーボードで
  音階を演奏できます。
- **ネイティブセンサー接続** — ヒンジ版はmacOSのIOHIDを直接利用します。
  Python、pybooklid、Homebrewは必要ありません。
- **演奏に集中できるUI** — メイン画面には楽器、必要な操作、鍵盤、
  最小限の空気量メーターだけを表示します。
- **診断情報を設定画面へ分離** — 接続状態、ヒンジ角度、空気圧は
  **MAcordion → 設定…** から確認できます。
- **英語・日本語対応** — メインUI、操作案内、アクセシビリティラベル、
  設定画面、権限説明がMacの優先言語に合わせて切り替わります。
- **3種類の入力モード** — Hinge、Breath、Shishaの各バージョンが、
  共通の音源とキーボード配置を使用します。
- **Universal 2配布パッケージ** — Apple SiliconとIntel Macの両方に
  対応する再現可能なZIPを作成できます。

<details>
<summary>センサー診断画面</summary>

演奏画面をシンプルに保ったまま、**MAcordion → 設定…** からセンサーの
接続状態、ヒンジ角度、空気圧を確認できます。

<img src="Design/macordion-settings-diagnostics.png" alt="MAcordionのセンサー診断設定画面" width="420">

</details>

### 安全上の注意

> **自己責任で使用してください：** このアプリはMacBookのハードウェア
> センサー（ヒンジ角度）を読み取り、Breath版ではマイクへアクセスします。
> ディスプレイはゆっくり動かし、通常の可動範囲を超えて無理に開閉しないで
> ください。端末の破損やデータ損失について、開発者は責任を負いません。

### 起動モード

3つのアプリが、共通の音源とキーボード配置を使用します。

- **MAcordion** — MacBookのヒンジ角度で蛇腹を操作するアコーディオン版
- **MAcordionBreath** — マイクの入力音量で空気量を操作する鍵盤ハーモニカ版
- **MAcordionShisha** — USB-C接続の差圧センサーで操作するShisha版

Swift Package Managerから起動する場合：

```bash
swift run MAcordion        # ヒンジセンサー版
swift run MAcordionBreath  # マイク入力版
swift run MAcordionShisha  # Shisha圧力センサー版
```

対応する入力機器が利用できない場合は、固定された音量で演奏できる
キーボードモードへ自動的に切り替わります。

#### Shishaセンサーの設定

MPXV7002DPを10k/27kの分圧回路で接続したESP32-C3 Superminiへ
`firmware/esp32c3/shisha_sensor/shisha_sensor.ino`を書き込み、USB-Cで
Macへ接続してください。通常は`/dev/cu.usbmodem*`を自動検出します。
複数のデバイスがある場合は、次のように接続先を指定できます。

```bash
SHISHA_PORT=/dev/cu.usbmodemXXXX swift run MAcordionShisha
```

### 操作方法

| キー | 機能 |
|---|---|
| `A S D F G H J K L ;` | 白鍵（C D E F G A B C D E） |
| `W E T Y U O P` | 黒鍵（C# D# F# G# A# C# D#） |
| `Space` | 空気弁を開き、音を出さずに蛇腹を動かす |
| `Tab` | サステインのオン／オフ |
| `Z` | オクターブを下げる |
| `X` | オクターブを上げる |

> 演奏前にMAcordionのウインドウをクリックし、操作対象にしてください。

### 動作要件

- macOS 13.0以降
- Swift 5.9以降／Xcode 15以降
- ヒンジ版：対応するMacBookのヒンジ角度センサー
- Breath版：マイクへのアクセス許可

### 再現可能な配布パッケージ

次のコマンドで、署名済みアプリバンドルと決定的なZIPを作成できます。

```bash
./scripts/package.sh
```

Apple SiliconとIntelに対応したUniversal 2バイナリをビルドし、`dist/`へ
3種類のZIP、`SHA256SUMS`、`BUILD-INFO.txt`を出力します。

標準ではアドホック署名のため、別のMacで初めて起動するときはアプリを
Controlキーを押しながらクリックし、**開く**を選択してください。
通常のGatekeeper承認済み配布を行う場合は、Developer ID Application証明書を
`SIGN_IDENTITY`へ指定し、生成したアーカイブを公証してください。

```bash
APP_VERSION=1.4.0 BUILD_NUMBER=1 \
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
./scripts/package.sh
```

単一アーキテクチャだけをビルドする場合：

```bash
ARCHITECTURES=arm64 ./scripts/package.sh
```
