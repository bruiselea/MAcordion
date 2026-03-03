# 🪗 AcOrDiOn - MacBook Accordion

MacBookをアコーディオンに変えるアプリケーション。画面の開閉が蛇腹として機能し、キーボードで音を出します。

## 特徴

- **蛇腹シミュレーション**: MacBookの画面を動かす速度が音量を制御
- **リアルなアコーディオン音**: 複数リードのデチューン、トレモロ効果
- **2つのモード**:
  - ピアノモード（GarageBand風レイアウト）
  - ボタンアコーディオン（Bシステム・クロマチック）

## 動作環境

- macOS 13.0以上
- ヒンジ角度センサー対応MacBook（M1以降推奨）
- Python 3.10以上

## インストール

```bash
cd acordion_app
pip install -r requirements.txt
```

## 使い方

```bash
python main.py
```

### 操作方法

| キー | 動作 |
|------|------|
| `1` | ピアノモード |
| `2` | ボタンアコーディオンモード |
| `[` / `]` | オクターブ変更 |
| `Tab` | サスティン ON/OFF |
| `Esc` | 終了 |

### ピアノモード

```
白鍵: A S D F G H J K L ;
黒鍵: W E   T Y U   O P
```

### ボタンアコーディオンモード（Bシステム）

```
Row 1: Q W E R T Y U I O P
Row 2: A S D F G H J K L ;
Row 3: Z X C V B N M , . /
```

各行は短3度（3半音）ずれたクロマチック配列です。

## 演奏のコツ

1. キーを**押したまま**にする
2. MacBookの画面を**パタパタ動かす**
3. 速く動かすと大きな音、ゆっくりだと小さな音

本物のアコーディオンと同じ仕組みです！

## プロジェクト構成

```
acordion_app/
├── main.py          # メインエントリーポイント
├── config.py        # 設定値
├── keymaps.py       # キーボードマッピング
├── sound.py         # 音声生成
├── hinge.py         # ヒンジセンサー
├── ui.py            # ユーザーインターフェース
└── requirements.txt # 依存パッケージ
```

## ライセンス

MIT License
