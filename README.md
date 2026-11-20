# 《鸣人：逆转雨夜》

《火影忍者》同人 AI 短剧的剧本与制作资料。

## 第一集「这次，我来救你」

| 文件 | 内容 |
|---|---|
| [`ep01/script.md`](ep01/script.md) | 原剧本（原样保存） |
| [`ep01/storyboard.md`](ep01/storyboard.md) | 分镜制作包：角色定妆、35 个片段的中英文提示词、配音表、审读意见 |
| [`ep01/subtitles.srt`](ep01/subtitles.srt) | 字幕，可直接导入剪映 |
| [`ep01/storyboard.html`](ep01/storyboard.html) | 分镜制作包网页版（带一键复制） |
| [`ep01/storyboard.json`](ep01/storyboard.json) | 以上三个文件的数据源 |

## 修改分镜

只改 `ep01/storyboard.json`，然后重新生成：

```bash
python3 tools/build.py ep01
```

脚本会先检查每个镜头的片段时长是否相加正确、台词有没有超出片段，再写出 `storyboard.md`、`subtitles.srt` 和 `storyboard.html`。

同人作品，非官方。角色与世界观版权归原作者所有。
