"""フォントを画面に出す字だけに絞る(GameDesign.md 10章 / Architecture.md 6章)。

python tools/subset_font.py          元のフォントから絞って assets/fonts/ へ書く
python tools/subset_font.py --check  使っている字が assets/fonts/ のフォントにあるかを確かめる(足りなければ終了コード1)
"""

import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
FONT_NAME = "ZenKakuGothicNew-Bold.ttf"
SOURCE_FONT = ROOT / "tools" / "font_src" / FONT_NAME
OUTPUT_FONT = ROOT / "assets" / "fonts" / FONT_NAME
TEXT_DIRS = ["scripts", "data", "scenes"]
TEXT_SUFFIXES = {".gd", ".tres", ".tscn"}

# 文言を足すたびに絞り直さずに済むよう、いつも残す字の範囲
BASE_RANGES = [
    (0x0020, 0x007E),  # ASCII
    (0x2010, 0x2027),  # ダッシュ・引用符・…
    (0x2190, 0x2193),  # ← ↑ → ↓
    (0x25A0, 0x25FF),  # ■ ● ◆ ▲ ▼ など
    (0x2605, 0x2606),  # ★ ☆
    (0x3000, 0x303F),  # 和文の句読点・括弧
    (0x3040, 0x309F),  # ひらがな
    (0x30A0, 0x30FF),  # カタカナ
    (0xFF01, 0xFF5E),  # 全角英数・記号
    (0xFFE5, 0xFFE5),  # ¥(全角)
]

GD_STRING = re.compile(r'"""(.*?)"""|"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'', re.DOTALL)


def used_chars() -> set[str]:
    chars: set[str] = set()
    for folder in TEXT_DIRS:
        for path in (ROOT / folder).rglob("*"):
            if path.suffix not in TEXT_SUFFIXES:
                continue
            text = path.read_text(encoding="utf-8")
            if path.suffix == ".gd":
                # コメントの字まで残さないよう、文字列の中だけを拾う
                text = "".join("".join(groups) for groups in GD_STRING.findall(text))
            chars.update(c for c in text if not c.isspace() or c == " ")
    return chars


def base_chars() -> set[str]:
    return {chr(code) for start, end in BASE_RANGES for code in range(start, end + 1)}


def missing_chars(font_path: Path) -> list[str]:
    cmap = TTFont(font_path).getBestCmap()
    return sorted(c for c in used_chars() if ord(c) not in cmap)


def build() -> None:
    source_cmap = TTFont(SOURCE_FONT).getBestCmap()
    unicodes = sorted(ord(c) for c in used_chars() | base_chars() if ord(c) in source_cmap)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    font = subset.load_font(str(SOURCE_FONT), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    subset.save_font(font, str(OUTPUT_FONT), options)
    kb = OUTPUT_FONT.stat().st_size // 1024
    print(f"{len(unicodes)} 字 / {kb} KB -> {OUTPUT_FONT.relative_to(ROOT)}")
    not_in_source = sorted(c for c in used_chars() if ord(c) not in source_cmap)
    if not_in_source:
        print("元のフォントにも無い字(UiDraw で描くか別の字にする): " + " ".join(not_in_source))


def check() -> int:
    missing = missing_chars(OUTPUT_FONT)
    if not missing:
        print("ok")
        return 0
    print("フォントに無い字: " + " ".join(missing))
    print("python tools/subset_font.py で絞り直す")
    return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(check() if "--check" in sys.argv else build())
