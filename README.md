# 《鸣人：逆转雨夜》

《火影忍者》同人 AI 短剧的剧本与制作资料。

## 第一集「这次，我来救你」

| 文件 | 内容 |
|---|---|
| [`ep01/script.md`](ep01/script.md) | 原剧本（原样保存） |
| [`ep01/storyboard.md`](ep01/storyboard.md) | 分镜制作包：角色定妆、35 个片段的中英文提示词、配音表、审读意见 |
| [`ep01/subtitles.srt`](ep01/subtitles.srt) | 字幕，可直接导入剪映 |
| [`ep01/storyboard.html`](ep01/storyboard.html) | 分镜制作包网页版（带一键复制） |
| [`ep01/animatic.mp4`](ep01/animatic.mp4) | 动态分镜预览（2:20，程序绘制的特效、字幕、AI 配音和环境音，不是 AI 成片） |
| [`ep01/voice/`](ep01/voice/) | 18 句台词的配音（开源 Kokoro 中文语音模型生成，不是原作声优） |
| [`ep01/storyboard.json`](ep01/storyboard.json) | 以上文件的数据源 |

## 修改分镜

只改 `ep01/storyboard.json`，然后重新生成：

```bash
python3 tools/build.py ep01
```

脚本会先检查每个镜头的片段时长是否相加正确、台词有没有超出片段，再写出 `storyboard.md`、`subtitles.srt` 和 `storyboard.html`。

重新渲染动态分镜预览（需要 ffmpeg、numpy、Pillow 和一款中文字体，约 1 分钟）：

```bash
python3 tools/animatic.py ep01
```

重新生成配音（先 `pip install sherpa-onnx`，再下载约 350 MB 的模型 [kokoro-multi-lang-v1_1](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2) 并解压）：

```bash
KOKORO_DIR=模型目录 python3 tools/voice.py ep01
```

角色用哪种声音、每句的语速和音量，在 `tools/voice.py` 开头的 `CAST` 和 `STYLE` 里改。

同人作品，非官方。角色与世界观版权归原作者所有。
