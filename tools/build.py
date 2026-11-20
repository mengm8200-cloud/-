#!/usr/bin/env python3
"""Generate an episode's production files from its storyboard.json.

    python3 tools/build.py ep01

Writes next to storyboard.json:
  storyboard.md    分镜制作包（Markdown，GitHub 上直接看）
  subtitles.srt    字幕
  storyboard.html  分镜制作包（网页版，发布成 Artifact 的就是它）

Before writing it checks that clip durations add up to each shot, that every
{TOKEN} in a prompt has an anchor, and that every line sits inside its clip.
"""
from __future__ import annotations

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKEN = re.compile(r"\{([A-Z0-9]+)\}")
LIP_LABEL = {"required": "对口型", "optional": "可选对口型", "none": "无需对口型"}


# ---------------------------------------------------------------- helpers

def esc(s) -> str:
    return html.escape(str(s), quote=True)


def tc(t: float, decimals: bool = False) -> str:
    """0:34 or 0:34.5"""
    m, s = divmod(t, 60)
    if decimals:
        return f"{int(m)}:{s:04.1f}"
    return f"{int(m)}:{int(round(s)):02d}"


def srt_tc(t: float) -> str:
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def sec_frames(dur: float, fps: int) -> str:
    """Storyboard timing notation: seconds + frames, e.g. 4+00."""
    whole = int(dur)
    frames = int(round((dur - whole) * fps))
    return f"{whole}+{frames:02d}"


def expand(text: str, anchors: dict, lang: str) -> str:
    """Replace {TOKEN} with the full appearance anchor (for copying)."""
    def rep(m):
        a = anchors[m.group(1)][lang]
        before = text[: m.start()].rstrip()
        if lang == "en" and (not before or before[-1] in ".!?"):
            a = a[:1].upper() + a[1:]
        return a
    return TOKEN.sub(rep, text)


def chips(text: str, anchors: dict, lang: str) -> str:
    """Escape text and render {TOKEN} as a labelled chip (for display)."""
    out, pos = [], 0
    for m in TOKEN.finditer(text):
        out.append(esc(text[pos: m.start()]))
        a = anchors[m.group(1)]
        out.append(f'<span class="tok" title="{esc(a[lang])}">{esc(a["label"])}</span>')
        pos = m.end()
    out.append(esc(text[pos:]))
    return "".join(out)


# ---------------------------------------------------------------- model

def validate(d: dict) -> None:
    errs = []
    anchors = d["anchors"]
    seen = set()
    for shot in d["shots"]:
        total = sum(c["dur"] for c in shot["clips"])
        if abs(total - shot["dur"]) > 1e-9:
            errs.append(f"镜头{shot['no']}：片段合计 {total} 秒，标注 {shot['dur']} 秒")
        for c in shot["clips"]:
            if c["id"] in seen:
                errs.append(f"{c['id']}：片段编号重复")
            seen.add(c["id"])
            for field in ("frame", "motion", "en"):
                for tok in TOKEN.findall(c[field]):
                    if tok not in anchors:
                        errs.append(f"{c['id']}.{field}：未知标签 {{{tok}}}")
            if c["lipsync"] not in LIP_LABEL:
                errs.append(f"{c['id']}：lipsync 只能是 {', '.join(LIP_LABEL)}")
            prev_end = 0.0
            for ln in c["lines"]:
                if ln["at"] < prev_end - 1e-9:
                    errs.append(f"{c['id']}：台词重叠或顺序不对（{ln['text']}）")
                if ln["at"] + ln["len"] > c["dur"] + 1e-9:
                    errs.append(f"{c['id']}：台词“{ln['text']}”超出片段时长")
                prev_end = ln["at"] + ln["len"]
    if errs:
        print("storyboard.json 有问题：", file=sys.stderr)
        for e in errs:
            print("  - " + e, file=sys.stderr)
        sys.exit(1)


def layout(d: dict) -> None:
    t = 0.0
    lines, clips = [], []
    for shot in d["shots"]:
        shot["start"] = t
        for c in shot["clips"]:
            c["start"], c["end"] = t, t + c["dur"]
            c["shot"] = shot["no"]
            for ln in c["lines"]:
                ln["start"] = t + ln["at"]
                ln["end"] = ln["start"] + ln["len"]
                ln["clip"] = c["id"]
                ln["lipsync"] = c["lipsync"]
                lines.append(ln)
            clips.append(c)
            t += c["dur"]
        shot["end"] = t
    d["main_end"] = t
    ec = d["endcard"]
    ec["start"], ec["end"] = t, t + ec["dur"]
    d["total"] = ec["end"]
    d["all_lines"], d["all_clips"] = lines, clips
    d["n_required"] = sum(c["lipsync"] == "required" for c in clips)
    d["n_optional"] = sum(c["lipsync"] == "optional" for c in clips)
    fill = {"{LIPSYNC_REQUIRED}": str(d["n_required"])}
    for group in d["notes"]:
        new_items = []
        for item in group["items"]:
            for k, v in fill.items():
                item = item.replace(k, v)
            new_items.append(item)
        group["items"] = new_items


# ---------------------------------------------------------------- SRT

def build_srt(d: dict) -> str:
    out = []
    for i, ln in enumerate(d["all_lines"], 1):
        out += [str(i), f"{srt_tc(ln['start'])} --> {srt_tc(ln['end'])}", ln["text"], ""]
    return "\n".join(out)


# ---------------------------------------------------------------- Markdown

def build_md(d: dict) -> str:
    A, m, st = d["anchors"], d["meta"], d["style"]
    L = []
    add = L.append
    add(f"# 《{m['series']}》{m['episode_label']}「{m['subtitle']}」分镜制作包")
    add("")
    add("> 由 `tools/build.py` 根据 `storyboard.json` 生成，请不要直接改这个文件："
        f"改 JSON 后运行 `python3 tools/build.py {d['_ep']}`。")
    add("")
    add(f"- 总尺：{tc(d['total'])}（正片 {tc(d['main_end'])}，片尾卡 {d['endcard']['dur']} 秒）")
    add(f"- 片段：{len(d['all_clips'])} 个；台词：{len(d['all_lines'])} 句；"
        f"需对口型：{d['n_required']} 个片段（另有 {d['n_optional']} 个可选）")
    add(f"- 画幅：{m['aspect']}（在生成工具里设置，不写进提示词）")
    add("")
    add("## 使用方法")
    add("")
    for i, step in enumerate(d["workflow"], 1):
        add(f"{i}. {step}")
    add("")
    add("## 画风锚点")
    add("")
    add("每条「画面提示词」和英文提示词的末尾都加上这一句（网页版复制时会自动附加）。")
    add("")
    add("```text\n" + st["cn"] + "\n```")
    add("```text\n" + st["en"] + "\n```")
    add("")
    add("## 负面提示词")
    add("")
    add("```text\n" + st["negative_cn"] + "\n```")
    add("```text\n" + st["negative_en"] + "\n```")
    add("")
    add("## 标签对照")
    add("")
    add("分镜提示词里的 `{标签}` 已在下文展开成完整描述；这里列出每个标签对应的外貌，方便统一修改。")
    add("")
    add("| 标签 | 中文 | English |")
    add("|---|---|---|")
    for key, a in A.items():
        add(f"| {a['label']} | {a['cn']} | {a['en']} |")
    add("")
    add("## 角色定妆")
    add("")
    for ch in d["characters"]:
        add(f"### {ch['name']}（{ch['use']}）")
        add("")
        add("```text\n" + ch["cn"] + "\n```")
        add("```text\n" + ch["en"] + "\n```")
        if ch.get("note"):
            add(f"> {ch['note']}")
        add("")
    add("## 场景参考")
    add("")
    for sc in d["scenes"]:
        add(f"### {sc['name']}（{sc['use']}）")
        add("")
        add("```text\n" + sc["cn"] + "\n```")
        add("```text\n" + sc["en"] + "\n```")
        add("")
    add("## 分镜")
    add("")
    fps = m["fps"]
    for shot in d["shots"]:
        add(f"### 镜头{shot['no']}｜{shot['title']}｜{shot['dur']}秒｜{tc(shot['start'])}–{tc(shot['end'])}")
        add("")
        add(f"音乐：{shot['music']}  ")
        add(f"色调：{shot['palette']}")
        add("")
        for c in shot["clips"]:
            add(f"#### {c['id']} · {tc(c['start'])}–{tc(c['end'])} · {sec_frames(c['dur'], fps)} · {c['size']} · {c['move']}")
            add("")
            add(f"**画面**：{c['visual']}")
            add("")
            tags = list(c.get("flags", []))
            if c["lines"] or c["lipsync"] != "none":
                tag = LIP_LABEL[c["lipsync"]]
                if c.get("lipnote"):
                    tag += f"（{c['lipnote']}）"
                tags.append(tag)
            if tags:
                add("**标记**：" + "，".join(tags))
                add("")
            add("画面提示词（首帧 / 多图参考生视频）：")
            add("```text\n" + expand(c["frame"], A, "cn") + "\n```")
            add("动态提示词（图生视频）：")
            add("```text\n" + expand(c["motion"], A, "cn") + "\n```")
            add("English：")
            add("```text\n" + expand(c["en"], A, "en") + "\n```")
            for ln in c["lines"]:
                add(f"- **{ln['who']}**：“{ln['text']}”　{ln['tone']}　`{tc(ln['start'], True)}–{tc(ln['end'], True)}`")
            if c["lines"]:
                add("")
            add(f"**音效**：{c['sfx']}")
            if c.get("tip"):
                add("")
                add(f"> 提示：{c['tip']}")
            add("")
    ec = d["endcard"]
    add(f"### 片尾卡｜{ec['dur']}秒｜{tc(ec['start'])}–{tc(ec['end'])}")
    add("")
    add(f"**画面**：{ec['visual']}  ")
    add(f"**音效**：{ec['sfx']}  ")
    add(f"**制作**：{ec['how']}")
    add("")
    add("## 配音表")
    add("")
    add("| 时间码 | 片段 | 角色 | 台词 | 语气 | 口型 |")
    add("|---|---|---|---|---|---|")
    for ln in d["all_lines"]:
        add(f"| {tc(ln['start'], True)}–{tc(ln['end'], True)} | {ln['clip']} | {ln['who']} | {ln['text']} | {ln['tone']} | {LIP_LABEL[ln['lipsync']]} |")
    add("")
    add("## 审读意见")
    add("")
    for group in d["notes"]:
        add(f"### {group['title']}")
        add("")
        for item in group["items"]:
            add(f"- {item}")
        add("")
    return "\n".join(L)


# ---------------------------------------------------------------- HTML

CSS = r"""
:root{
  /* Layout: a storyboard sheet. Cover band, sticky bar, a timeline strip, then one row per cut:
     frame box (cut no. / shot size / camera / sec+frames) | action + prompts | dialogue + sound. */
  --bg:#EDF0F3;
  --sheet:#F9FAFB;
  --well:#E9EDF1;
  --ink:#16202B;
  --ink-2:#465364;
  --ink-3:#5C6876;
  --rule:#D2D8DF;
  --gold:#B07A0C;
  --gold-ink:#8A5C00;
  --gold-wash:#F6E7C4;
  --steel:#3F5B74;
  --on-steel:#FFFFFF;
  --endcard:#2B333C;
  --rain:rgba(63,91,116,.08);
  --focus:#1F6FB2;
  --font-display:"Ma Shan Zheng","STKaiti","KaiTi","Kaiti SC",serif;
  --font-body:"PingFang SC","Hiragino Sans GB","Microsoft YaHei","Noto Sans SC","Noto Sans CJK SC",system-ui,sans-serif;
  --font-mono:"JetBrains Mono",ui-monospace,"SFMono-Regular",Menlo,Consolas,monospace;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --bg:#0D131A; --sheet:#141C25; --well:#0F161E; --ink:#E5EAF0; --ink-2:#AEB9C5; --ink-3:#8E9AA7; --rule:#25313E;
    --gold:#E9AE3C; --gold-ink:#F2C063; --gold-wash:#3A2E14; --steel:#8EA9C1; --on-steel:#0D131A; --endcard:#5D6B79;
    --rain:rgba(142,169,193,.07); --focus:#7FB8EA; color-scheme:dark;
  }
}
:root[data-theme="dark"]{
  --bg:#0D131A; --sheet:#141C25; --well:#0F161E; --ink:#E5EAF0; --ink-2:#AEB9C5; --ink-3:#8E9AA7; --rule:#25313E;
  --gold:#E9AE3C; --gold-ink:#F2C063; --gold-wash:#3A2E14; --steel:#8EA9C1; --on-steel:#0D131A; --endcard:#5D6B79;
  --rain:rgba(142,169,193,.07); --focus:#7FB8EA; color-scheme:dark;
}
html{scroll-behavior:smooth}
@media (prefers-reduced-motion: reduce){html{scroll-behavior:auto}}
body{background:var(--bg);color:var(--ink);font-family:var(--font-body);font-size:15px;line-height:1.7;-webkit-text-size-adjust:100%}
body::before{content:"";position:fixed;inset:0 0 auto;height:env(safe-area-inset-top,0px);z-index:10;background:var(--bg)}
.wrap{max-width:72rem;margin-inline:auto;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
.mono{font-family:var(--font-mono)}
a{color:inherit}
a:focus-visible,button:focus-visible,input:focus-visible,textarea:focus-visible{outline:2px solid var(--focus);outline-offset:2px;border-radius:4px}
.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}

/* cover */
.cover{margin-top:calc(-1 * env(safe-area-inset-top,0px));padding-top:calc(env(safe-area-inset-top,0px) + 2.75rem);padding-bottom:2rem;background-color:var(--bg);background-image:repeating-linear-gradient(104deg,transparent 0 26px,var(--rain) 26px 27px)}
.eyebrow{margin:0;font-size:.8rem;letter-spacing:.12em;color:var(--ink-3)}
.title{margin:.3rem 0 0;font-family:var(--font-display);font-weight:400;font-size:clamp(2.6rem,9vw,4.6rem);line-height:1.12;letter-spacing:.02em;text-wrap:balance}
.sub{margin:.4rem 0 0;font-size:1.15rem;color:var(--ink-2)}
.sub b{color:var(--gold-ink);font-weight:700;margin-right:.6em}
.fields{display:flex;flex-wrap:wrap;gap:.6rem 1.9rem;margin:1.6rem 0 0;padding:0}
.fields div{display:flex;flex-direction:column}
.fields dt{font-size:.72rem;letter-spacing:.12em;color:var(--ink-3)}
.fields dd{margin:0;font-size:1.05rem;font-weight:600}

/* sticky bar */
.bar{position:sticky;top:env(safe-area-inset-top,0px);z-index:6;background:var(--bg);border-top:1px solid var(--rule);border-bottom:1px solid var(--rule)}
.bar-in{display:flex;flex-wrap:wrap;align-items:center;gap:.45rem 1.25rem;padding-block:.5rem}
.bar-links{display:flex;gap:1.15rem;overflow-x:auto;white-space:nowrap;min-width:0;flex:1 1 22rem;scrollbar-width:none}
.bar-links::-webkit-scrollbar{display:none}
.bar-links a{color:var(--ink-2);text-decoration:none;font-size:.9rem;padding-block:.15rem}
.bar-links a:hover{color:var(--ink)}
.bar-ctl{display:flex;align-items:center;gap:1rem;flex-wrap:wrap}
.seg{display:inline-flex;border:1px solid var(--rule);border-radius:999px;padding:2px;background:var(--sheet)}
.seg button{border:0;background:transparent;color:var(--ink-2);font:inherit;font-size:.82rem;line-height:1.5;padding:.15rem .8rem;border-radius:999px;cursor:pointer}
.seg button[aria-pressed="true"]{background:var(--ink);color:var(--bg)}
.chk{display:inline-flex;align-items:center;gap:.4rem;font-size:.85rem;color:var(--ink-2);cursor:pointer}
.chk input{accent-color:var(--gold);width:1rem;height:1rem;margin:0}

/* sections */
main{padding-block:.5rem 2rem}
.sec{padding-block:2.25rem 1rem;scroll-margin-top:7rem}
.sec-h{margin:0 0 .35rem;font-size:1.4rem;font-weight:700;letter-spacing:.04em;text-wrap:balance}
.sec-lead{margin:0 0 1.25rem;color:var(--ink-2);max-width:44rem}
.sub-h{margin:1.75rem 0 .75rem;font-size:1.05rem;font-weight:700}

/* timeline */
.tl{margin-top:1.75rem;padding:1rem 1.1rem .9rem;background:var(--sheet);border:1px solid var(--rule);border-radius:10px}
.tl-cap{display:flex;flex-wrap:wrap;justify-content:space-between;gap:.25rem 1rem;margin:0 0 2.6rem;font-size:.85rem;color:var(--ink-2)}
.tl-cap b{color:var(--ink)}
.tl-row{display:flex;align-items:center;gap:.6rem}
.tl-row + .tl-row{margin-top:.55rem}
.tl-lab{flex:0 0 2.4rem;font-size:.75rem;color:var(--ink-3);letter-spacing:.06em}
.tl-track{position:relative;flex:1 1 auto;min-width:0;height:28px}
.tl-track.lines{height:12px}
.tl-blk{position:absolute;top:0;bottom:0;border-radius:4px;background:var(--steel);color:var(--on-steel);text-decoration:none;display:flex;align-items:center}
.tl-blk.end{background:var(--endcard)}
.tl-blk:hover,.tl-blk:focus-visible{filter:brightness(1.15)}
.tl-num{font-family:var(--font-mono);font-size:.75rem;font-weight:600;padding-left:6px}
.tl-line{position:absolute;top:0;bottom:0;min-width:3px;border-radius:2px;background:var(--gold)}
.tl-line::before{content:"";position:absolute;inset:-8px -5px}
.tl-line:hover,.tl-line:focus-visible{filter:brightness(1.15)}
.tip{position:absolute;bottom:calc(100% + 8px);left:0;z-index:4;width:max-content;max-width:min(17rem,72vw);padding:.4rem .6rem;border-radius:6px;background:var(--ink);color:var(--bg);font-size:.78rem;line-height:1.45;opacity:0;visibility:hidden;pointer-events:none;text-align:left;white-space:normal}
.tip b{display:block;font-size:.9rem}
.tip-r .tip{left:auto;right:0}
.tip-c .tip{left:50%;transform:translateX(-50%)}
.tl-blk:hover .tip,.tl-blk:focus-visible .tip,.tl-line:hover .tip,.tl-line:focus-visible .tip{opacity:1;visibility:visible}
@media (prefers-reduced-motion: no-preference){.tip{transition:opacity .12s,visibility .12s}}
.tl-axis{position:relative;height:1.1rem;margin:.4rem 0 0 3rem;font-family:var(--font-mono);font-size:.7rem;color:var(--ink-3)}
.tl-axis span{position:absolute;top:0;transform:translateX(-50%)}
.tl-axis span.first{transform:none}
.tl-axis span.last{transform:translateX(-100%)}
@media (max-width:560px){.tl-axis span.minor{display:none}}
.tl-legend{display:flex;flex-wrap:wrap;gap:.2rem 1rem;margin:.7rem 0 0 3rem;padding:0;list-style:none;font-size:.78rem;color:var(--ink-2)}
.tl-legend b{font-family:var(--font-mono);color:var(--ink);margin-right:.3em}

/* how-to */
.steps{margin:0;padding-left:1.5rem;display:grid;gap:.55rem;max-width:46rem}
.steps li::marker{font-family:var(--font-mono);color:var(--gold-ink);font-weight:600}
.toklist{display:grid;gap:.6rem;margin:0;padding:0;list-style:none;max-width:56rem}
.toklist li{display:grid;grid-template-columns:7.5rem minmax(0,1fr);gap:.75rem;align-items:baseline;font-size:.86rem;color:var(--ink-2)}
@media (max-width:520px){.toklist li{grid-template-columns:minmax(0,1fr);gap:.15rem}}

/* prompt blocks */
.pblock{background:var(--well);border-radius:6px;padding:.5rem .75rem .65rem;min-width:0}
.pb-h{display:flex;align-items:center;gap:.5rem;margin-bottom:.25rem}
.pb-l{font-size:.75rem;font-weight:700;letter-spacing:.06em;color:var(--ink-2)}
.pb-hint{font-size:.72rem;color:var(--ink-3)}
.copy{margin-left:auto;border:1px solid var(--rule);background:var(--sheet);color:var(--ink-2);font:inherit;font-size:.75rem;line-height:1.6;padding:.05rem .65rem;border-radius:5px;cursor:pointer;white-space:nowrap}
.copy:hover{color:var(--ink);border-color:var(--ink-3)}
.copy.ok{color:var(--gold-ink);border-color:var(--gold)}
.pb-t{margin:0;font-size:.88rem;line-height:1.8;color:var(--ink);overflow-wrap:anywhere}
.tok{display:inline-block;padding:0 .35em;margin:0 .1em;border-radius:4px;background:var(--gold-wash);color:var(--gold-ink);font-weight:600;font-size:.92em;line-height:1.6;cursor:help}
.fallback{display:block;width:100%;min-height:6rem;margin-top:.5rem;font:inherit;font-size:.82rem;color:var(--ink);background:var(--sheet);border:1px solid var(--gold);border-radius:6px;padding:.5rem;box-sizing:border-box}
.app[data-plang="cn"] .pen,.app[data-plang="en"] .pcn{display:none}

/* reference cards */
.cards{display:grid;gap:1rem;grid-template-columns:minmax(0,1fr)}
@media (min-width:760px){.cards.two{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media (min-width:960px){.cards.three{grid-template-columns:repeat(3,minmax(0,1fr))}}
.card{background:var(--sheet);border:1px solid var(--rule);border-radius:10px;padding:1rem 1.1rem;display:flex;flex-direction:column;gap:.6rem;min-width:0}
.card-h{display:flex;flex-wrap:wrap;align-items:baseline;justify-content:space-between;gap:.2rem .75rem}
.card h3{margin:0;font-size:1.05rem}
.card .use{font-size:.75rem;color:var(--ink-3);font-family:var(--font-mono)}
.card .note{margin:0;font-size:.84rem;color:var(--ink-2)}

/* shots and cuts */
.shot{margin-top:1.5rem;background:var(--sheet);border:1px solid var(--rule);border-radius:10px;scroll-margin-top:7rem}
.shot-h{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:.15rem 1rem;align-items:end;padding:1.1rem 1.25rem .9rem;border-bottom:1px solid var(--rule)}
.shot-no{grid-column:1/-1;font-family:var(--font-mono);font-size:.72rem;letter-spacing:.16em;color:var(--ink-3)}
.shot-t{margin:0;font-family:var(--font-display);font-weight:400;font-size:clamp(1.6rem,4.6vw,2.1rem);line-height:1.25}
.shot-tc{font-family:var(--font-mono);font-size:.85rem;color:var(--ink-2);white-space:nowrap}
.shot-notes{grid-column:1/-1;display:flex;flex-wrap:wrap;gap:.2rem 1.6rem;margin:.45rem 0 0;font-size:.85rem;color:var(--ink-2)}
.shot-notes div{display:flex;gap:.5rem}
.shot-notes dt{color:var(--ink-3);white-space:nowrap}
.shot-notes dd{margin:0}
.cut{display:grid;grid-template-columns:minmax(0,1fr);gap:.9rem;padding:1.1rem 1.25rem 1.2rem;border-top:1px solid var(--rule);scroll-margin-top:7rem}
.shot-h + .cut{border-top:0}
@media (min-width:720px){.cut{grid-template-columns:10.5rem minmax(0,1fr)}.cut-side{grid-column:2}}
@media (min-width:1080px){.cut{grid-template-columns:10.5rem minmax(0,1fr) 15.5rem}.cut-side{grid-column:auto}}
.cut-head{display:flex;flex-direction:column;gap:.45rem;min-width:0}
.frame{position:relative;aspect-ratio:16/9;max-width:100%;border:1.5px solid var(--ink-3);border-radius:3px;background:var(--well);display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:.4rem}
.frame .fid{position:absolute;top:.2rem;left:.4rem;font-family:var(--font-mono);font-weight:600;font-size:.8rem}
.frame .fdur{position:absolute;bottom:.15rem;right:.4rem;font-family:var(--font-mono);font-size:.72rem;color:var(--ink-3)}
.frame .fsize{font-weight:700;font-size:.9rem;line-height:1.3}
.frame .fmove{font-size:.74rem;color:var(--ink-2);line-height:1.35}
@media (max-width:719.98px){
  .frame{aspect-ratio:auto;flex-direction:row;flex-wrap:wrap;justify-content:flex-start;align-items:baseline;gap:.2rem .6rem;padding:.4rem .6rem;text-align:left}
  .frame .fid,.frame .fdur{position:static}
  .frame .fdur{margin-left:auto}
}
.cut-tc{font-family:var(--font-mono);font-size:.78rem;color:var(--ink-2)}
.chips{display:flex;flex-wrap:wrap;gap:.3rem}
.chip{font-size:.72rem;line-height:1;padding:.32rem .5rem;border-radius:999px;border:1px solid var(--rule);color:var(--ink-2);white-space:nowrap}
.chip.lip{background:var(--gold-wash);border-color:transparent;color:var(--gold-ink);font-weight:700}
.chip.lip-opt{border-color:var(--gold);color:var(--gold-ink)}
.chip.flag{border-color:var(--steel)}
.cut-body{min-width:0;display:flex;flex-direction:column;gap:.65rem}
.visual{margin:0;font-size:.98rem}
.cut-side{min-width:0;display:flex;flex-direction:column;gap:.7rem;font-size:.88rem}
.line .who{font-size:.75rem;font-weight:700;color:var(--ink-2)}
.line .txt{margin:.05rem 0;font-size:1.02rem;line-height:1.5;color:var(--ink)}
.line .meta{font-size:.78rem;color:var(--ink-3)}
.line .meta .mono{font-size:.72rem;margin-right:.5em}
.lab{font-size:.72rem;font-weight:700;letter-spacing:.08em;color:var(--ink-3);margin-right:.45rem}
.sfx{margin:0;color:var(--ink-2)}
.hint{margin:0;font-size:.84rem;background:var(--gold-wash);color:var(--ink);border-radius:6px;padding:.5rem .65rem}
.endcard{padding:1.1rem 1.25rem 1.2rem;display:grid;gap:.4rem}
.endcard p{margin:0;color:var(--ink-2)}

/* voice table */
.table-wrap{overflow-x:auto;border:1px solid var(--rule);border-radius:10px;background:var(--sheet)}
table{border-collapse:collapse;width:100%;min-width:46rem;font-size:.88rem}
th,td{text-align:left;vertical-align:top;padding:.55rem .8rem;border-bottom:1px solid var(--rule)}
th{font-size:.75rem;letter-spacing:.06em;color:var(--ink-3);font-weight:700;background:var(--well);white-space:nowrap}
tbody tr:last-child td{border-bottom:0}
td.tc{font-family:var(--font-mono);font-variant-numeric:tabular-nums;white-space:nowrap;color:var(--ink-2)}
td.txt{font-size:.95rem;color:var(--ink)}
td.who{white-space:nowrap}
td.tone{color:var(--ink-2)}

/* srt */
.srt-box{background:var(--sheet);border:1px solid var(--rule);border-radius:10px;padding:.7rem 1rem 1rem;min-width:0}
.srt-box pre{margin:.5rem 0 0;max-height:22rem;overflow:auto;font-family:var(--font-mono);font-size:.8rem;line-height:1.6;color:var(--ink-2);background:var(--well);border-radius:6px;padding:.6rem .8rem}

/* notes */
.notes{display:grid;gap:1.4rem;max-width:46rem}
.notes h3{margin:0 0 .4rem;font-size:1.02rem}
.notes ul{margin:0;padding-left:1.2rem;display:grid;gap:.45rem;color:var(--ink-2)}

footer{padding-block:1.5rem 3rem;border-top:1px solid var(--rule);font-size:.8rem;color:var(--ink-3)}
footer p{margin:.2rem 0}
"""

JS = r"""
(function(){
  var app = document.querySelector('.app');
  var STYLE = __STYLE__;
  function sget(k){ try { return localStorage.getItem(k); } catch (e) { return null; } }
  function sset(k, v){ try { localStorage.setItem(k, v); } catch (e) {} }

  var langBtns = document.querySelectorAll('[data-lang-btn]');
  function setLang(l){
    app.setAttribute('data-plang', l);
    langBtns.forEach(function(b){ b.setAttribute('aria-pressed', String(b.getAttribute('data-lang-btn') === l)); });
    sset('nrn-ep01-plang', l);
  }
  setLang(sget('nrn-ep01-plang') === 'en' ? 'en' : 'cn');
  langBtns.forEach(function(b){ b.addEventListener('click', function(){ setLang(b.getAttribute('data-lang-btn')); }); });

  var opt = document.getElementById('opt-style');
  if (sget('nrn-ep01-style') === '0') opt.checked = false;
  opt.addEventListener('change', function(){ sset('nrn-ep01-style', opt.checked ? '1' : '0'); });

  var live = document.getElementById('live');
  function flash(btn, ok){
    if (!btn.dataset.label) btn.dataset.label = btn.textContent;
    btn.textContent = ok ? '已复制' : '请手动复制';
    btn.classList.toggle('ok', ok);
    live.textContent = ok ? '已复制到剪贴板' : '没能自动复制，文字已在下方选中，请手动复制';
    clearTimeout(btn._t);
    btn._t = setTimeout(function(){ btn.textContent = btn.dataset.label; btn.classList.remove('ok'); }, 1600);
  }
  function fallback(btn, text){
    var scope = btn.closest('.pblock, .srt-box');
    if (!scope) { flash(btn, false); return; }
    var ta = scope.querySelector('textarea.fallback');
    if (!ta) {
      ta = document.createElement('textarea');
      ta.className = 'fallback';
      ta.readOnly = true;
      ta.id = (scope.id || 'copy') + '-fallback';
      ta.setAttribute('aria-label', '要复制的文字');
      scope.appendChild(ta);
    }
    ta.value = text;
    ta.focus();
    ta.select();
    flash(btn, false);
  }
  document.addEventListener('click', function(e){
    var btn = e.target.closest('button.copy');
    if (!btn) return;
    var text, from = btn.getAttribute('data-copy-from');
    if (from) {
      var el = document.querySelector(from);
      text = el ? el.textContent : '';
    } else {
      text = btn.getAttribute('data-copy') || '';
      var s = btn.getAttribute('data-style');
      if (opt.checked && (s === 'cn' || s === 'en')) text += (s === 'cn' ? '，' : ', ') + STYLE[s];
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function(){ flash(btn, true); }, function(){ fallback(btn, text); });
    } else {
      fallback(btn, text);
    }
  });
})();
"""


def copy_btn(text: str, style: str = "none") -> str:
    return f'<button type="button" class="copy" data-copy="{esc(text)}" data-style="{style}">复制</button>'


def pblock(pid: str, lang_cls: str, label: str, hint: str, display_html: str, copy_text: str, style: str) -> str:
    hint_html = f'<span class="pb-hint">{esc(hint)}</span>' if hint else ""
    return (f'<div class="pblock {lang_cls}" id="{esc(pid)}">'
            f'<div class="pb-h"><span class="pb-l">{esc(label)}</span>{hint_html}{copy_btn(copy_text, style)}</div>'
            f'<p class="pb-t">{display_html}</p></div>')


def tip_side(center_pct: float) -> str:
    if center_pct < 30:
        return "tip-l"
    if center_pct > 70:
        return "tip-r"
    return "tip-c"


def build_timeline(d: dict) -> str:
    total = d["total"]
    pct = lambda t: t / total * 100  # noqa: E731
    blocks = []
    for shot in d["shots"]:
        left, width = pct(shot["start"]), pct(shot["dur"])
        label = f"镜头{shot['no']} {shot['title']}"
        rng = f"{tc(shot['start'])}–{tc(shot['end'])}"
        blocks.append(
            f'<a class="tl-blk {tip_side(left + width / 2)}" href="#shot-{shot["no"]}" '
            f'style="left:{left:.3f}%;width:calc({width:.3f}% - 2px)" '
            f'aria-label="{esc(label)}，{shot["dur"]} 秒，{rng}">'
            f'<span class="tl-num" aria-hidden="true">{shot["no"]}</span>'
            f'<span class="tip" aria-hidden="true"><b>{shot["dur"]} 秒</b>{esc(label)} · {rng}</span></a>')
    ec = d["endcard"]
    left, width = pct(ec["start"]), pct(ec["dur"])
    rng = f"{tc(ec['start'])}–{tc(ec['end'])}"
    blocks.append(
        f'<a class="tl-blk end {tip_side(left + width / 2)}" href="#endcard" '
        f'style="left:{left:.3f}%;width:calc({width:.3f}% - 2px)" aria-label="片尾卡，{ec["dur"]} 秒，{rng}">'
        f'<span class="tip" aria-hidden="true"><b>{ec["dur"]} 秒</b>片尾卡 · {rng}</span></a>')

    ticks = []
    for ln in d["all_lines"]:
        left, width = pct(ln["start"]), pct(ln["len"])
        rng = f"{tc(ln['start'], True)}–{tc(ln['end'], True)}"
        ticks.append(
            f'<a class="tl-line {tip_side(left)}" href="#clip-{ln["clip"]}" '
            f'style="left:{left:.3f}%;width:{width:.3f}%" '
            f'aria-label="{esc(ln["who"])}：{esc(ln["text"])}，{rng}">'
            f'<span class="tip" aria-hidden="true"><b>{esc(ln["text"])}</b>{esc(ln["who"])} · {ln["clip"]} · {rng}</span></a>')

    # Minor ticks drop out on phones so the last two labels never touch.
    marks = [(0, "first"), (30, "minor"), (60, ""), (90, "minor"), (120, "minor"), (total, "last")]
    axis = [f'<span class="{cls}" style="left:{pct(t):.3f}%">{tc(t)}</span>' for t, cls in marks]

    legend = "".join(f"<li><b>{s['no']}</b>{esc(s['title'])}</li>" for s in d["shots"])
    legend += "<li><b>尾</b>片尾卡</li>"
    talk = sum(ln["len"] for ln in d["all_lines"])
    return (
        '<section class="tl" aria-label="全片时间轴">'
        f'<p class="tl-cap"><span><b>时间轴</b>　一格一个镜头，金色是台词</span>'
        f'<span>台词共 {talk:.0f} 秒，占正片 {talk / d["main_end"] * 100:.0f}%</span></p>'
        f'<div class="tl-row"><span class="tl-lab">镜头</span><div class="tl-track">{"".join(blocks)}</div></div>'
        f'<div class="tl-row"><span class="tl-lab">台词</span><div class="tl-track lines">{"".join(ticks)}</div></div>'
        f'<div class="tl-axis" aria-hidden="true">{"".join(axis)}</div>'
        f'<ul class="tl-legend">{legend}</ul>'
        '</section>')


def build_cut(c: dict, A: dict, fps: int) -> str:
    cid = c["id"]
    chip_html = []
    for f in c.get("flags", []):
        chip_html.append(f'<span class="chip flag">{esc(f)}</span>')
    if c["lipsync"] == "required":
        chip_html.append('<span class="chip lip">对口型</span>')
    elif c["lipsync"] == "optional":
        chip_html.append('<span class="chip lip-opt">可选对口型</span>')
    head = (
        '<div class="cut-head">'
        f'<div class="frame" aria-label="片段 {cid}，{esc(c["size"])}，{esc(c["move"])}，{c["dur"]} 秒">'
        f'<span class="fid">{cid}</span><span class="fsize">{esc(c["size"])}</span>'
        f'<span class="fmove">{esc(c["move"])}</span>'
        f'<span class="fdur" title="秒+帧（{fps}fps）">{sec_frames(c["dur"], fps)}</span></div>'
        f'<span class="cut-tc">{tc(c["start"])}–{tc(c["end"])}</span>'
        + (f'<div class="chips">{"".join(chip_html)}</div>' if chip_html else "")
        + '</div>')

    body = (
        '<div class="cut-body">'
        f'<p class="visual">{esc(c["visual"])}</p>'
        + pblock(f"p-{cid}-frame", "pcn", "画面提示词", "首帧 / 多图参考",
                 chips(c["frame"], A, "cn"), expand(c["frame"], A, "cn"), "cn")
        + pblock(f"p-{cid}-motion", "pcn", "动态提示词", "图生视频",
                 chips(c["motion"], A, "cn"), expand(c["motion"], A, "cn"), "none")
        + pblock(f"p-{cid}-en", "pen", "English prompt", "keyframe + motion",
                 chips(c["en"], A, "en"), expand(c["en"], A, "en"), "en")
        + '</div>')

    side = ['<aside class="cut-side">']
    for ln in c["lines"]:
        side.append(
            '<div class="line">'
            f'<div class="who">{esc(ln["who"])}</div>'
            f'<p class="txt">“{esc(ln["text"])}”</p>'
            f'<div class="meta"><span class="mono">{tc(ln["start"], True)}–{tc(ln["end"], True)}</span>{esc(ln["tone"])}</div>'
            '</div>')
    if c["lines"] and c.get("lipnote"):
        side.append(f'<p class="sfx"><span class="lab">口型</span>{esc(LIP_LABEL[c["lipsync"]])}，{esc(c["lipnote"])}</p>')
    side.append(f'<p class="sfx"><span class="lab">音效</span>{esc(c["sfx"])}</p>')
    if c.get("tip"):
        side.append(f'<p class="hint">{esc(c["tip"])}</p>')
    side.append('</aside>')
    return f'<article class="cut" id="clip-{cid}">{head}{body}{"".join(side)}</article>'


def build_html(d: dict, srt: str) -> str:
    A, m, st = d["anchors"], d["meta"], d["style"]
    fps = m["fps"]
    o = []
    add = o.append
    add(f'<title>逆转雨夜 {esc(m["episode_label"])}分镜</title>')
    add('<meta name="claude:viewport-fit-sides" content="cover">')
    add('<link rel="preconnect" href="https://fonts.googleapis.com">')
    add('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
    add('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Ma+Shan+Zheng&display=swap">')
    add(f"<style>{CSS}</style>")
    add('<div class="app" data-plang="cn">')

    # cover
    add('<header class="cover"><div class="wrap">')
    add(f'<p class="eyebrow">{esc(m["genre"])} · 分镜制作包</p>')
    add(f'<h1 class="title">{esc(m["series"])}</h1>')
    add(f'<p class="sub"><b>{esc(m["episode_label"])}</b>{esc(m["subtitle"])}</p>')
    fields = [
        ("总尺", f'<span class="mono">{tc(d["total"])}</span>'),
        ("正片", f'<span class="mono">{tc(d["main_end"])}</span>'),
        ("镜头", f'<span class="mono">{len(d["shots"])}</span>'),
        ("片段", f'<span class="mono">{len(d["all_clips"])}</span>'),
        ("台词", f'<span class="mono">{len(d["all_lines"])}</span> 句'),
        ("需对口型", f'<span class="mono">{d["n_required"]}</span> 个'),
        ("画幅", f'<span class="mono">{esc(m["aspect"])}</span>'),
    ]
    add('<dl class="fields">' + "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in fields) + "</dl>")
    add(build_timeline(d))
    add("</div></header>")

    # sticky bar
    add('<nav class="bar" aria-label="页面导航"><div class="wrap bar-in">')
    add('<div class="bar-links"><a href="#how">使用方法</a><a href="#refs">定妆</a><a href="#board">分镜</a>'
        '<a href="#voice">配音表</a><a href="#srt">字幕</a><a href="#notes">审读意见</a></div>')
    add('<div class="bar-ctl"><div class="seg" role="group" aria-label="提示词语言">'
        '<button type="button" data-lang-btn="cn" aria-pressed="true">中文</button>'
        '<button type="button" data-lang-btn="en" aria-pressed="false">English</button></div>'
        '<label class="chk" for="opt-style"><input type="checkbox" id="opt-style" checked>复制时附加画风锚点</label></div>')
    add("</div></nav>")

    add('<main class="wrap">')

    # how-to
    add('<section class="sec" id="how"><h2 class="sec-h">使用方法</h2>')
    add('<p class="sec-lead">每个片段都配好了三条提示词：中文「画面提示词」「动态提示词」和一条英文提示词。'
        '右上角切换语言；勾选「复制时附加画风锚点」后，复制画面提示词会自动在末尾加上统一的画风描述。</p>')
    add('<ol class="steps">' + "".join(f"<li>{esc(s)}</li>" for s in d["workflow"]) + "</ol>")
    add('<h3 class="sub-h">画风锚点与负面提示词</h3><div class="cards two">')
    add('<div class="card">' + pblock("p-style-cn", "pcn", "画风锚点", "自动附加", esc(st["cn"]), st["cn"], "none")
        + pblock("p-style-en", "pen", "Style anchor", "appended on copy", esc(st["en"]), st["en"], "none") + "</div>")
    add('<div class="card">' + pblock("p-neg-cn", "pcn", "负面提示词", "工具支持时填写", esc(st["negative_cn"]), st["negative_cn"], "none")
        + pblock("p-neg-en", "pen", "Negative prompt", "if supported", esc(st["negative_en"]), st["negative_en"], "none") + "</div>")
    add("</div>")
    add('<h3 class="sub-h">标签对照</h3>')
    add('<p class="sec-lead">提示词里的金色标签复制时会展开成下面的完整描述，所有片段共用同一套外貌，改这里就能统一改。</p>')
    add('<ul class="toklist">')
    for a in A.values():
        add(f'<li><span><span class="tok">{esc(a["label"])}</span></span>'
            f'<span><span class="pcn">{esc(a["cn"])}</span><span class="pen">{esc(a["en"])}</span></span></li>')
    add("</ul></section>")

    # references
    add('<section class="sec" id="refs"><h2 class="sec-h">角色定妆</h2>')
    add('<p class="sec-lead">先出这四张三视图，挑定之后全片都用它们做参考图，脸和服装才不会漂。</p>')
    add('<div class="cards two">')
    for i, ch in enumerate(d["characters"]):
        add('<div class="card">'
            f'<div class="card-h"><h3>{esc(ch["name"])}</h3><span class="use">{esc(ch["use"])}</span></div>'
            + pblock(f"p-char{i}-cn", "pcn", "定妆提示词", "", esc(ch["cn"]), ch["cn"], "none")
            + pblock(f"p-char{i}-en", "pen", "Reference prompt", "", esc(ch["en"]), ch["en"], "none")
            + (f'<p class="note">{esc(ch["note"])}</p>' if ch.get("note") else "")
            + "</div>")
    add("</div>")
    add('<h3 class="sub-h">场景参考</h3><div class="cards three">')
    for i, sc in enumerate(d["scenes"]):
        add('<div class="card">'
            f'<div class="card-h"><h3>{esc(sc["name"])}</h3><span class="use">{esc(sc["use"])}</span></div>'
            + pblock(f"p-scene{i}-cn", "pcn", "场景提示词", "", esc(sc["cn"]), sc["cn"], "none")
            + pblock(f"p-scene{i}-en", "pen", "Environment prompt", "", esc(sc["en"]), sc["en"], "none")
            + "</div>")
    add("</div></section>")

    # board
    add('<section class="sec" id="board"><h2 class="sec-h">分镜</h2>')
    add(f'<p class="sec-lead">8 个镜头拆成 {len(d["all_clips"])} 个片段，每段 2 到 5 秒。'
        '画框右下角是「秒+帧」，生成时选 5 秒档，剪辑时截到这个长度。</p>')
    for shot in d["shots"]:
        add(f'<section class="shot" id="shot-{shot["no"]}" aria-labelledby="shot-{shot["no"]}-t">')
        add('<header class="shot-h">'
            f'<span class="shot-no">镜头 {shot["no"]:02d}</span>'
            f'<h3 class="shot-t" id="shot-{shot["no"]}-t">{esc(shot["title"])}</h3>'
            f'<span class="shot-tc">{tc(shot["start"])}–{tc(shot["end"])} · {shot["dur"]} 秒</span>'
            f'<dl class="shot-notes"><div><dt>音乐</dt><dd>{esc(shot["music"])}</dd></div>'
            f'<div><dt>色调</dt><dd>{esc(shot["palette"])}</dd></div></dl>'
            '</header>')
        for c in shot["clips"]:
            add(build_cut(c, A, fps))
        add("</section>")
    ec = d["endcard"]
    add('<section class="shot" id="endcard" aria-labelledby="endcard-t">')
    add('<header class="shot-h"><span class="shot-no">片尾</span>'
        '<h3 class="shot-t" id="endcard-t">片尾卡</h3>'
        f'<span class="shot-tc">{tc(ec["start"])}–{tc(ec["end"])} · {ec["dur"]} 秒</span></header>')
    add('<div class="endcard">'
        f'<p><span class="lab">画面</span>{esc(ec["visual"])}</p>'
        f'<p><span class="lab">音效</span>{esc(ec["sfx"])}</p>'
        f'<p><span class="lab">制作</span>{esc(ec["how"])}</p></div>')
    add("</section></section>")

    # voice table
    add('<section class="sec" id="voice"><h2 class="sec-h">配音表</h2>')
    add(f'<p class="sec-lead">{len(d["all_lines"])} 句台词按时间排好，时间码就是字幕的时间。'
        '“对口型”的片段建议先录音，再用工具的对口型功能。</p>')
    add('<div class="table-wrap"><table><thead><tr><th>时间码</th><th>片段</th><th>角色</th><th>台词</th><th>语气</th><th>口型</th></tr></thead><tbody>')
    for ln in d["all_lines"]:
        add(f'<tr><td class="tc">{tc(ln["start"], True)}–{tc(ln["end"], True)}</td>'
            f'<td class="tc"><a href="#clip-{ln["clip"]}">{ln["clip"]}</a></td>'
            f'<td class="who">{esc(ln["who"])}</td><td class="txt">{esc(ln["text"])}</td>'
            f'<td class="tone">{esc(ln["tone"])}</td><td class="who">{esc(LIP_LABEL[ln["lipsync"]])}</td></tr>')
    add("</tbody></table></div></section>")

    # srt
    add('<section class="sec" id="srt"><h2 class="sec-h">字幕</h2>')
    add('<p class="sec-lead">网页里不能直接下载文件：点「复制全部」，粘贴进记事本，另存为 .srt 后导入剪映。'
        '仓库里的 ep01/subtitles.srt 是同一份。</p>')
    add('<div class="srt-box" id="srt-box"><div class="pb-h"><span class="pb-l">subtitles.srt</span>'
        f'<span class="pb-hint">{len(d["all_lines"])} 条</span>'
        '<button type="button" class="copy" data-copy-from="#srt-text">复制全部</button></div>'
        f'<pre id="srt-text">{esc(srt)}</pre></div>')
    add("</section>")

    # notes
    add('<section class="sec" id="notes"><h2 class="sec-h">审读意见</h2>')
    add('<p class="sec-lead">剧本本身完整、能直接拍。下面是拍之前值得看一眼的几处。</p>')
    add('<div class="notes">')
    for g in d["notes"]:
        add(f'<div><h3>{esc(g["title"])}</h3><ul>' + "".join(f"<li>{esc(i)}</li>" for i in g["items"]) + "</ul></div>")
    add("</div></section>")

    add("</main>")
    add('<footer class="wrap"><p>同人作品，非官方。角色与世界观版权归原作者所有。</p>'
        f'<p>本页由仓库里的 {esc(d["_ep"])}/storyboard.json 生成，改动请改数据后重新生成。</p></footer>')
    add("</div>")
    add('<div id="live" class="sr-only" aria-live="polite"></div>')
    style_js = json.dumps({"cn": st["cn"], "en": st["en"]}, ensure_ascii=False)
    add("<script>" + JS.replace("__STYLE__", style_js) + "</script>")
    return "\n".join(o) + "\n"


# ---------------------------------------------------------------- main

def main(argv: list[str]) -> None:
    if len(argv) != 2:
        print(__doc__)
        sys.exit(2)
    ep = argv[1].strip("/")
    ep_dir = ROOT / ep
    data = json.loads((ep_dir / "storyboard.json").read_text(encoding="utf-8"))
    data["_ep"] = ep
    validate(data)
    layout(data)
    srt = build_srt(data)
    (ep_dir / "subtitles.srt").write_text(srt, encoding="utf-8")
    (ep_dir / "storyboard.md").write_text(build_md(data), encoding="utf-8")
    (ep_dir / "storyboard.html").write_text(build_html(data, srt), encoding="utf-8")
    print(f"{ep}: {len(data['shots'])} 个镜头，{len(data['all_clips'])} 个片段，"
          f"{len(data['all_lines'])} 句台词，正片 {tc(data['main_end'])}，总尺 {tc(data['total'])}，"
          f"需对口型 {data['n_required']} 个（可选 {data['n_optional']} 个）")


if __name__ == "__main__":
    main(sys.argv)
