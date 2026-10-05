#!/usr/bin/env python3
"""校验「项目路牌」文档里的 `文件:行号 符号名()` 锚点是否仍然有效。

纯标准库实现，Python 3.8+。用法见 references/verify-anchors.md。

判定：
  OK     文件存在、行号在范围内、符号在锚点行 ±TOL 行内（或落在锚点区间内）
  DRIFT  符号存在，但行号偏差 4~40 行
  WRONG  文件不存在 / 行号越界 / 符号找不到 / 偏差 >40 行
退出码：0 = 全部通过；1 = 存在 DRIFT 或 WRONG；2 = 参数或文件错误。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:  # Windows 控制台默认不是 UTF-8，避免中文输出崩掉
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:  # pragma: no cover
    pass

TOL = 3
DRIFT_MAX = 40

EXT = (
    "gd|py|ts|tsx|js|mjs|cjs|jsx|cs|cpp|cc|c|h|hpp|rs|go|java|kt|kts|rb|php|swift|lua|"
    "sh|bash|zsh|ps1|cmd|bat|sql|html|css|scss|vue|svelte|"
    "md|markdown|json|json5|ya?ml|toml|ini|cfg|godot|tres|res|tscn|gdshader|scene|txt"
)

ANCHOR_RE = re.compile(
    r"(?P<path>[A-Za-z0-9_][A-Za-z0-9_./\\-]*\.(?:" + EXT + r"))"
    r":(?P<start>\d{1,6})(?:\s*-\s*(?P<end>\d{1,6}))?"
)

# 锚点后面紧跟的符号名：允许反引号、括号、空格、冒号等分隔符
SYMBOL_RE = re.compile(r"^[\s`（(\[【:：,，、|]*?(?P<sym>[A-Za-z_][A-Za-z0-9_]{2,})")

DEF_TEMPLATES = (
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+|public\s+|private\s+|protected\s+|export\s+|async\s+)*"
    r"(?:func|def|class|struct|enum|const|let|var|function|interface|type|signal|trait|impl)\s+{sym}\b",
    r"^\s*{sym}\s*(?::[^=]+)?:?=",          # NAME := ... / NAME = ...
    r"^\s*(?:export\s+)?(?:const|let|var)\s+{sym}\s*=",
)

DEFAULT_SEARCH_DIRS = ("scripts", "tests", "tools", "server", "resources", "scenes", "src", "app", "lib", ".")


class Anchor:
    __slots__ = ("path", "start", "end", "symbol", "symbols", "strict_count", "line_no", "raw")

    def __init__(self, path, start, end, symbol, symbols, strict_count, line_no, raw):
        self.path, self.start, self.end = path, start, end
        self.symbol, self.symbols = symbol, symbols
        self.strict_count, self.line_no, self.raw = strict_count, line_no, raw


def parse_symbol(tail: str):
    """从锚点尾部文本里提取符号名；提取不到就返回 None。"""
    m = SYMBOL_RE.match(tail or "")
    if not m:
        return None
    sym = m.group("sym")
    if sym.lower() in {"md", "py", "gd", "js", "ts", "json", "yaml", "yml", "txt", "line", "func", "const"}:
        return None
    return sym


def is_code_like(sym: str) -> bool:
    """判断一个词像代码标识符（而不是正文里的英文单词）。"""
    if len(sym) < 3:
        return False
    return "_" in sym or sym.isupper() or sym.islower()


PATHY_RE = re.compile(r"^[A-Za-z0-9_./\\-]*\.(?:" + EXT + r")\s*:")


SEP = " \t`（(【[、，,；;：:）)】]》"


def looks_like_path(text: str) -> bool:
    """该位置起是不是另一个锚点的路径（如 `boss_hud.gd:70`），而不是符号名。"""
    return bool(PATHY_RE.match((text or "").lstrip(SEP)))


STOPWORDS = {
    "gd", "py", "js", "ts", "md", "json", "yaml", "yml", "txt", "src", "lib",
    "func", "const", "var", "class", "def", "line", "anchor", "range",
}


def candidates_for(line: str, match, anchor_path: str = ""):
    """返回 (strict, hints)：
    strict —— 紧跟锚点之后的词，视为"必须命中"的符号名；
    hints  —— 锚点之前最近的 1~2 个词，只作加分项（找不到不算错，避免把正文单词当符号）。
    """
    tail = line[match.end() : match.end() + 60]
    strict = []
    if not looks_like_path(tail):
        sm = SYMBOL_RE.match(tail)
        if sm:
            sym = sm.group("sym")
            after = tail[sm.end() : sm.end() + 1]
            rest = tail[sm.end() :]
            same_anchor = False
            for m3 in ANCHOR_RE.finditer(rest[:40]):
                if Path(m3.group("path")).name == Path(anchor_path).name:
                    same_anchor = True  # 同一个单元格里还有本文件的另一个锚点，这个词属于它
                    break
            # 路径片段（xxx.gd / dir/yyy）与本文件下一个锚点的符号都不算
            if (
                sym.lower() not in STOPWORDS
                and is_code_like(sym)
                and after not in ("/", ".", "\\")
                and not same_anchor
                and not looks_like_path(rest)
            ):
                strict.append(sym)
    hints = []
    head = line[: match.start()][-70:]
    for m2 in list(re.finditer(r"[A-Za-z_][A-Za-z0-9_]{2,}", head))[-4:]:
        w = m2.group(0)
        if w.lower() in STOPWORDS or not is_code_like(w):
            continue
        # 路径片段（scripts/xxx.gd 里的 scripts、xxx）不是符号名
        if head[m2.end() : m2.end() + 1] == "/" or head[m2.start() - 1 : m2.start()] == "/":
            continue
        if w not in strict and w not in hints:
            hints.append(w)
    return strict, hints


def collect_anchors(guide_text: str):
    anchors = []
    for i, line in enumerate(guide_text.split("\n"), start=1):
        for m in ANCHOR_RE.finditer(line):
            path = m.group("path").replace("\\", "/").lstrip("/")
            if re.match(r"^[A-Za-z]:", path):  # 绝对路径锚点跳过
                continue
            # 符号名从锚点前后的文本里取，且必须是非消费式提取，否则会吃掉下一个锚点的开头
            syms, hints = candidates_for(line, m, path)
            anchors.append(
                Anchor(
                    path=path,
                    start=int(m.group("start")),
                    end=int(m.group("end")) if m.group("end") else None,
                    symbol=(syms or hints or [None])[0],
                    symbols=syms + hints,
                    strict_count=len(syms),
                    line_no=i,
                    raw=m.group(0).strip(),
                )
            )
    return anchors


class Repo:
    def __init__(self, root: Path, search_dirs):
        self.root = root
        self.search_dirs = list(search_dirs)
        self._lines = {}
        self._resolved = {}

    def resolve(self, path: str):
        if path in self._resolved:
            return self._resolved[path]
        found = None
        direct = self.root / path
        if direct.is_file():
            found = direct
        else:
            for d in self.search_dirs:
                cand = (self.root / d / path) if d != "." else (self.root / path)
                if cand.is_file():
                    found = cand
                    break
        self._resolved[path] = found
        return found

    def lines(self, file: Path):
        key = str(file)
        if key not in self._lines:
            try:
                # 必须只按 \n 切分：str.splitlines() 会把 \x0b/\x0c/\x85/\u2028 等
                # 也当换行，导致行号普遍偏大（编辑器/GDScript 不这么算）。
                text = file.read_text(encoding="utf-8", errors="replace")
                self._lines[key] = [l.rstrip("\r") for l in text.split("\n")]
            except OSError:
                self._lines[key] = []
        return self._lines[key]

    def locate_symbol(self, file: Path, symbol: str):
        """返回 (行号, 是否唯一命中)；找不到返回 (None, False)。"""
        lines = self.lines(file)
        for tmpl in DEF_TEMPLATES:
            rx = re.compile(tmpl.format(sym=re.escape(symbol)))
            hits = [i for i, l in enumerate(lines, start=1) if rx.search(l)]
            if len(hits) == 1:
                return hits[0], True
            if len(hits) > 1:
                return hits, False
        rx = re.compile(r"\b" + re.escape(symbol) + r"\b")
        hits = [i for i, l in enumerate(lines, start=1) if rx.search(l)]
        if not hits:
            return None, False
        return (hits[0] if len(hits) == 1 else hits), len(hits) == 1


def distance(anchor: Anchor, found) -> int:
    if isinstance(found, list):
        found = min(found, key=lambda h: distance(anchor, h))
    if anchor.end is not None and anchor.start <= found <= anchor.end:
        return 0
    return min(abs(found - anchor.start), abs(found - (anchor.end or anchor.start)))


def judge(repo: Repo, anchor: Anchor):
    file = repo.resolve(anchor.path)
    if file is None:
        return "WRONG", None, None, "文件不存在", None, False
    total = len(repo.lines(file))
    if anchor.start > total or (anchor.end and anchor.end > total):
        return "WRONG", None, None, f"行号越界（文件共 {total} 行）", None, False
    best = None  # (距离, 符号, 实测行, 是否唯一, 是否 strict)
    for idx, sym in enumerate(anchor.symbols):
        found, unique = repo.locate_symbol(file, sym)
        if found is None:
            continue
        d = distance(anchor, found)
        if best is None or d < best[0]:
            best = (d, sym, found, unique, idx < anchor.strict_count)
    if best is None:
        if anchor.strict_count == 0:
            return "OK", None, None, "仅区间校验", None, False
        return "WRONG", None, None, "找不到符号 " + "/".join(anchor.symbols[: anchor.strict_count]), None, bool(anchor.strict_count)
    d, sym, found, unique, strict = best
    shown = found[0] if isinstance(found, list) else found
    note = f"实测 {shown} [{sym}]" + ("" if unique else "（多处命中）")
    if d <= TOL:
        return "OK", shown, sym, note, d, strict
    if not strict:
        # 锚点后面没有写符号名，只是附近正文里出现了这个标识符：只作提示，不算错
        return "HINT", shown, sym, note + "（仅提示，锚点未写符号名）", d, False
    if d <= DRIFT_MAX:
        return "DRIFT", shown, sym, note, d, strict
    return "WRONG", shown, sym, note, d, strict


def read_text(path: Path):
    """按 UTF-8 读取，并记住原文件是否带 BOM（重写时必须原样保留）。"""
    raw = path.read_bytes()
    has_bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig" if has_bom else "utf-8", errors="replace")
    return text, has_bom


def write_text(path: Path, text: str, has_bom: bool):
    data = text.encode("utf-8")
    if has_bom:
        data = b"\xef\xbb\xbf" + data
    path.write_bytes(data)


def apply_fixes(guide_path: Path, text: str, fixes, has_bom: bool):
    """把单行锚点的行号改成实测行号；fixes: [(旧片段, 新片段)]。"""
    backup = guide_path.with_suffix(guide_path.suffix + ".bak")
    write_text(backup, text, has_bom)
    out = text
    for old, new in fixes:
        out = out.replace(old, new, 1)
    write_text(guide_path, out, has_bom)
    return backup


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="校验项目路牌里的 文件:行号 锚点")
    ap.add_argument("--guide", default="PROJECT-GUIDE.md", help="路牌文档路径（默认 PROJECT-GUIDE.md）")
    ap.add_argument("--root", default=".", help="代码根目录（默认当前目录）")
    ap.add_argument("--search-dirs", default=",".join(DEFAULT_SEARCH_DIRS), help="无名路径锚点的搜索目录")
    ap.add_argument("--summary", action="store_true", help="只输出汇总")
    ap.add_argument("--verbose", action="store_true", help="同时列出每个文件的通过情况")
    ap.add_argument("--json", action="store_true", help="以 JSON 输出")
    ap.add_argument("--fix", action="store_true", help="自动修正唯一命中符号的行号（写 .bak 备份）")
    ap.add_argument("--fix-max", type=int, default=DRIFT_MAX, help=f"自动修正允许的最大偏差（默认 {DRIFT_MAX}；大提交后重锚可设 100000）")
    ap.add_argument("--limit", type=int, default=200, help="最多打印多少行问题（默认 200）")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    guide = Path(args.guide)
    if not guide.is_absolute():
        guide = (root / guide) if (root / guide).is_file() else Path(args.guide)
    if not guide.is_file():
        print(f"[error] 找不到路牌文件：{guide}", file=sys.stderr)
        return 2

    text, has_bom = read_text(guide)
    repo = Repo(root, [d for d in args.search_dirs.split(",") if d])
    rows, stats = [], {"OK": 0, "HINT": 0, "DRIFT": 0, "WRONG": 0}

    for a in collect_anchors(text):
        verdict, found, symbol, note, dist, strict = judge(repo, a)
        stats[verdict] += 1
        rows.append(
            {
                "guide_line": a.line_no,
                "anchor": f"{a.path}:{a.start}" + (f"-{a.end}" if a.end else ""),
                "symbol": symbol,
                "verdict": verdict,
                "found_line": found,
                "distance": dist,
                "strict": strict,
                "note": note,
            }
        )

    problems = [r for r in rows if r["verdict"] in ("DRIFT", "WRONG")]
    hints = [r for r in rows if r["verdict"] == "HINT"]
    if args.fix:
        fixes = []
        for r in problems:
            if not (isinstance(r["found_line"], int) and r["strict"] and r["distance"] is not None):
                continue
            if r["distance"] > args.fix_max:
                continue
            if not r["symbol"]:
                continue
            old = f"{r['anchor']} {r['symbol']}"
            new = f"{r['anchor'].split(':')[0]}:{r['found_line']} {r['symbol']}"
            if text.count(old) == 1:
                fixes.append((old, new))
        if fixes:
            backup = apply_fixes(guide, text, fixes, has_bom)
            print(f"[fix] 已修正 {len(fixes)} 处行号，原文件备份到 {backup.name}")

    if args.json:
        print(json.dumps({"summary": stats, "problems": problems}, ensure_ascii=False, indent=2))
        return 0 if stats["WRONG"] == 0 and stats["DRIFT"] == 0 else 1

    if args.verbose:
        by_file = {}
        for r in rows:
            by_file.setdefault(r["anchor"].split(":")[0], []).append(r)
        for name, items in sorted(by_file.items()):
            bad = [i for i in items if i["verdict"] != "OK"]
            print(f"  {name:<44} {len(items):>3} 锚点  " + ("全部通过" if not bad else f"问题 {len(bad)}"))
        print()

    if not args.summary and problems:
        print(f"{'路牌行':<7} {'锚点':<42} {'判定':<6} {'符号':<22} 说明")
        for r in problems[: args.limit]:
            print(
                f"{r['guide_line']:<7} {r['anchor']:<42} {r['verdict']:<6} "
                f"{str(r['symbol'] or '-'):<22} {r['note']}"
            )
        if len(problems) > args.limit:
            print(f"... 其余 {len(problems) - args.limit} 条从略（用 --json 取全量）")
        print()

    total = sum(stats.values())
    print(
        f"汇总：{total} 个锚点 → OK {stats['OK']} / DRIFT {stats['DRIFT']} / WRONG {stats['WRONG']}"
        + (f" / HINT {stats['HINT']}" if stats["HINT"] else "")
        + ("　✅ 全部通过" if not problems else "　❌ 需要修正")
    )
    return 0 if not problems else 1


if __name__ == "__main__":
    raise SystemExit(main())
