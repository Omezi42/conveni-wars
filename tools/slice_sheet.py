"""生成AIで作った「無地の背景に絵を格子状に並べた1枚」を切り分け、背景を抜いた正方形のPNGにする。

python tools/slice_sheet.py [--rim 幅px] <シート画像> <列数> <行数> <出力フォルダ> <名前1> <名前2> ...
名前は左上から右へ、行ごとに並べる。"-" を渡したマスは出力しない。
背景の色はマスの外周でいちばん多い色から取る。マスの端は少し削る(格子の区切り線を拾わないため)。背景は外周から塗りつぶしでつながった所と、絵の中に閉じ込められた広い背景色の所を抜く。
--rim を付けると、輪郭線の外側の白い縁取り(ステッカーの縁)のうち背景から指定の幅までを抜く
(生成AIによって縁が付いたり付かなかったりするため、付いたシートにだけ使う)。
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

SIZE = 256
## 背景とみなす色の近さ(RGBの距離)と、絵の中の閉じた背景を抜く最小の面積(px)
BG_DISTANCE = 70.0
HOLE_DISTANCE = 40.0
HOLE_MIN_AREA = 30
## 背景との境目のにじみを消すために削る幅(px)と、絵のまわりに残す余白(辺に対する割合)
EDGE_ERODE = 2
MARGIN = 0.06
## 白い縁取りとみなす色の近さ(背景の色と白を結ぶ線からのRGBの距離。縁は背景の色と混ざることがあるため)
RIM_DISTANCE = 60.0
WHITE = np.array([255.0, 255.0, 255.0])
## マスの端を削る幅(マスの辺に対する割合)と、背景の色を数えるときの色の粗さ
CELL_INSET = 0.02
COLOR_STEP = 16
## 絵とみなす最小の面積(マスの面積に対する割合)。これより小さいゴミは捨てる
MIN_PART = 0.002


def _distance_to_segment(colors: np.ndarray, start: np.ndarray, end: np.ndarray) -> np.ndarray:
    line = end - start
    t = np.clip(((colors - start) @ line) / (line @ line), 0.0, 1.0)
    return np.linalg.norm(colors - (start + t[..., None] * line), axis=2)


def background_mask(rgb: np.ndarray, rim: int) -> np.ndarray:
    ring = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]).astype(int)
    bins = ring // COLOR_STEP
    keys, inverse, counts = np.unique(bins, axis=0, return_inverse=True, return_counts=True)
    bg = ring[inverse.ravel() == np.argmax(counts)].mean(axis=0)
    distance = np.linalg.norm(rgb.astype(float) - bg, axis=2)
    near = distance < BG_DISTANCE
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    mask = np.isin(labels, border[border > 0])
    holes, count = ndimage.label((distance < HOLE_DISTANCE) & ~mask)
    if count:
        areas = ndimage.sum(np.ones_like(holes), holes, range(1, count + 1))
        mask |= np.isin(holes, np.nonzero(areas >= HOLE_MIN_AREA)[0] + 1)
    if rim > 0:
        near_bg = ndimage.distance_transform_edt(~mask) <= rim
        mask |= near_bg & (_distance_to_segment(rgb.astype(float), bg, WHITE) < RIM_DISTANCE)
    return ndimage.binary_dilation(mask, iterations=EDGE_ERODE)


def cut(cell: Image.Image, rim: int) -> Image.Image:
    rgb = np.asarray(cell.convert("RGB"))
    alpha = ~background_mask(rgb, rim)
    parts, count = ndimage.label(alpha)
    if count:
        areas = ndimage.sum(alpha, parts, range(1, count + 1))
        keep = np.nonzero(areas >= alpha.size * MIN_PART)[0] + 1
        alpha = np.isin(parts, keep)
    rgba = np.dstack([rgb, (alpha * 255).astype(np.uint8)])
    image = Image.fromarray(rgba, "RGBA")
    box = image.getbbox()
    if box is None:
        raise ValueError("絵が見つからない")
    image = image.crop(box)
    side = int(max(image.size) * (1.0 + MARGIN * 2.0))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    return square.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")


def main() -> None:
    args = sys.argv[1:]
    rim = 0
    if args[0] == "--rim":
        rim = int(args[1])
        args = args[2:]
    sheet_path, columns, rows, out_dir, *names = args
    columns, rows = int(columns), int(rows)
    sheet = Image.open(sheet_path)
    width, height = sheet.size
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        if name == "-":
            continue
        column, row = index % columns, index // columns
        inset_x = int(width / columns * CELL_INSET)
        inset_y = int(height / rows * CELL_INSET)
        box = (
            width * column // columns + inset_x,
            height * row // rows + inset_y,
            width * (column + 1) // columns - inset_x,
            height * (row + 1) // rows - inset_y,
        )
        cut(sheet.crop(box), rim).save(out / f"{name}.png")
        print("wrote", out / f"{name}.png")


if __name__ == "__main__":
    main()
