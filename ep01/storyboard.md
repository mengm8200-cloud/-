# 《鸣人：逆转雨夜》第一集「这次，我来救你」分镜制作包

> 由 `tools/build.py` 根据 `storyboard.json` 生成，请不要直接改这个文件：改 JSON 后运行 `python3 tools/build.py ep01`。

- 总尺：2:20（正片 2:15，片尾卡 5 秒）
- 片段：35 个；台词：18 句；需对口型：7 个片段（另有 3 个可选）
- 画幅：16:9（在生成工具里设置，不写进提示词）

## 使用方法

1. 定妆：用「角色定妆」的提示词各生成一张三视图，挑最满意的固定下来，场景参考图同理。之后每个片段都把对应的定妆图作为参考图（主体参考）上传。
2. 出首帧：每个片段用「画面提示词」加定妆图生成一张首帧图。提示词里的彩色标签（如 鸣人·六道）复制时会自动展开成完整的外貌描述。
3. 图生视频：首帧图加「动态提示词」生成视频。工具支持多图参考直接生成视频时，可以跳过首帧，直接用「画面提示词」加定妆图。
4. 时长与画幅：生成时选 5 秒档（或工具的最短档），剪辑时截取每个片段标注的时长。画幅在工具里选：横屏 16:9；做竖屏就选 9:16，远景改成竖构图。
5. 声音：按「配音表」录台词或用 TTS。只有标了「对口型」的片段需要用对口型功能，其余台词都安排成了旁白、背影或画外音。
6. 剪辑：按时间码排好片段，导入「字幕」里的 SRT，最后接片尾卡。

## 画风锚点

每条「画面提示词」和英文提示词的末尾都加上这一句（网页版复制时会自动附加）。

```text
日式热血少年动画风格，2D赛璐璐上色，清晰黑色描边，高对比光影，电影感构图
```
```text
Japanese shonen anime style, 2D cel shading, clean bold line art, high-contrast lighting, cinematic composition
```

## 负面提示词

```text
写实照片，3D渲染，人物变脸，五官扭曲，多余的手指，多余的肢体，服装颜色变化，画面闪烁，文字，水印，字幕，标志，模糊
```
```text
photorealistic, 3D render, face morphing, distorted face, extra fingers, extra limbs, costume color change, flickering, text, watermark, subtitles, logo, blurry
```

## 标签对照

分镜提示词里的 `{标签}` 已在下文展开成完整描述；这里列出每个标签对应的外貌，方便统一修改。

| 标签 | 中文 | English |
|---|---|---|
| 鸣人·常态 | 少年（金色刺猬短发，蓝色眼睛，双颊各三道须痕，橙黑配色忍者服） | a teenage boy (spiky golden-blond hair, blue eyes, three whisker marks on each cheek, orange-and-black ninja outfit) |
| 鸣人·六道 | 少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉） | a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) |
| 自来也 | 白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤） | a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) |
| 佩恩·天道 | 橙发男人（橙色刺猬短发，浅紫色同心圆纹眼睛，脸上嵌着黑色金属钉饰，身穿高领黑底红云长袍） | an orange-haired man (spiky orange hair, pale purple eyes with concentric rings, black metal piercings on his face, high-collared black cloak with red clouds) |
| 佩恩剪影 | 数名黑袍人（逆光剪影，只看得清橙色发梢、长袍上的红云和发光的紫色眼睛） | several cloaked figures (backlit silhouettes, only orange hair tips, red clouds on their black cloaks and glowing purple eyes visible) |
| 老蛤蟆 | 老蛤蟆（灰绿色，小到能站在人肩上） | an old toad (gray-green, small enough to sit on a man's shoulder) |

## 角色定妆

### 鸣人 · 常态（镜头1–2）

```text
角色设定图，白色背景，正面、侧面、背面三视图加面部特写：一名16岁左右的少年忍者，金色刺猬状短发，蓝色眼睛，双颊各有三道须状纹，身穿橙黑配色的忍者外套和橙色长裤，黑色忍者凉鞋，身形精干，神情坚毅，日式热血少年动画风格，2D赛璐璐上色，清晰黑色描边，均匀光照
```
```text
Character reference sheet on a white background, front, side and back views plus a face close-up: a teenage ninja boy around 16, spiky golden-blond hair, blue eyes, three whisker marks on each cheek, orange-and-black ninja jacket and orange pants, black ninja sandals, lean build, determined expression, Japanese shonen anime style, 2D cel shading, clean bold line art, even lighting
```
> 护额戴不戴你自己定，定妆图定下来后全片保持一致。

### 鸣人 · 六道仙人模式（2C–8E）

```text
角色设定图，白色背景，正面、侧面、背面三视图加面部特写：同一名少年（金色刺猬状短发，双颊各三道须状纹）开启六道仙人模式，全身包裹一件金橙色发光的长款查克拉外衣，衣领一圈黑色勾玉纹，胸口和袖口有黑色纹路，金黄色虹膜、十字形瞳孔，身后悬浮一圈9颗光滑的黑色球体，周身散发金色光晕，日式热血少年动画风格，2D赛璐璐上色，清晰黑色描边
```
```text
Character reference sheet on a white background, front, side and back views plus a face close-up: the same teenage boy (spiky golden-blond hair, three whisker marks on each cheek) in a glowing golden-orange long chakra cloak, a ring of black magatama marks around the collar, black markings on the chest and cuffs, golden irises with cross-shaped pupils, a ring of nine smooth black orbs floating behind his back, a golden aura around his body, Japanese shonen anime style, 2D cel shading, clean bold line art
```
> 用常态定妆图做参考来生成这一张，保证是同一张脸。求道玉固定 9 颗、排成一圈，每个镜头数量一致。

### 自来也 · 负伤（镜头3–8）

```text
角色设定图，白色背景，正面、侧面、背面三视图加面部特写：一名身材高大的中年忍者，白色蓬松的刺猬状长发垂到腰间，双眼下各有一道向下延伸的红色纹路，额头戴着带角的“油”字护额，红色外褂罩在绿色短衫和绿色长裤外，内衬网格护甲，脚穿木屐；浑身带伤：衣服破损，嘴角有血，脸和手臂有擦伤，日式热血少年动画风格，2D赛璐璐上色，清晰黑色描边
```
```text
Character reference sheet on a white background, front, side and back views plus a face close-up: a tall middle-aged ninja with long spiky white hair down to his waist, a red line running down from each eye, a horned forehead protector, a red haori over a green short robe and green pants, mesh armor underneath, wooden geta sandals; battle-worn: torn clothes, blood at the corner of his mouth, scrapes on his face and arms, Japanese shonen anime style, 2D cel shading, clean bold line art
```
> AI 很难把“油”字写对，护额上的字可以后期贴图修。

### 佩恩 · 天道（镜头3–7）

```text
角色设定图，白色背景，正面、侧面、背面三视图加面部特写：一名青年男子，橙色刺猬状短发，浅紫色眼睛带多重同心圆波纹、没有瞳孔，鼻梁上横排数枚黑色金属钉，下唇下方有黑色钉，双耳布满黑色钉饰，身穿高领黑色长袍，袍上印着白边红色云纹，表情冷漠，日式热血少年动画风格，2D赛璐璐上色，清晰黑色描边
```
```text
Character reference sheet on a white background, front, side and back views plus a face close-up: a young man with spiky orange hair, pale purple pupil-less eyes with concentric ripple rings, a row of black metal studs across the bridge of his nose, black studs below his lower lip, ears lined with black piercings, a high-collared black cloak with white-outlined red cloud patterns, cold expressionless face, Japanese shonen anime style, 2D cel shading, clean bold line art
```
> 其余佩恩一律用逆光剪影处理（见 4A），不用另做定妆。

## 场景参考

### 战场废墟（镜头1–2）

```text
场景设定图，无人物：黄昏下的忍界大战废墟，大地龟裂，遍布巨大陨坑，倒插的苦无和断刀散落各处，烟尘弥漫，夕阳低垂在地平线上，低饱和的暖橙与灰色，日式动画背景美术，2D手绘质感
```
```text
Environment concept art, no characters: a vast ninja-war battlefield at dusk, cracked earth, giant craters, kunai and broken blades stuck in the ground, drifting smoke, a low sun on the horizon, desaturated warm orange and gray, Japanese anime background art, hand-painted 2D look
```

### 雨隐村地下水道（镜头3–6）

```text
场景设定图，无人物：昏暗的圆拱形地下排水隧道，墙上排列着锈蚀铁管，雨水从顶部铁格栅倾泻而下，积水没过脚踝，冷灰蓝色调，只有格栅透下的微弱天光，日式动画背景美术，2D手绘质感
```
```text
Environment concept art, no characters: a dark arched underground drainage tunnel, rusted iron pipes along the walls, rain pouring through iron ceiling grates, ankle-deep water, cold blue-gray palette, faint daylight from the grates, Japanese anime background art, hand-painted 2D look
```

### 雨隐村天际线（镜头6–8）

```text
场景设定图，无人物：终年下雨的忍者村，高耸的钢铁塔楼，外墙密布粗大的管道，密集雨幕，阴云低垂，冷灰色调，日式动画背景美术，2D手绘质感
```
```text
Environment concept art, no characters: a ninja village where it always rains, towering steel buildings with thick pipes covering their outer walls, dense curtains of rain, low heavy clouds, cold gray palette, Japanese anime background art, hand-painted 2D look
```

## 分镜

### 镜头1｜大战之后｜12秒｜0:00–0:12

音乐：尺八独奏，单线旋律，留白多  
色调：黄昏暖橙逆光，低饱和，烟尘灰

#### 1A · 0:00–0:04 · 4+00 · 大远景 · 航拍缓降推近

**画面**：黄昏下的大战废墟：龟裂的大地、巨大的陨坑、倒插的苦无与断刀，烟尘随风飘过。画面中央，鸣人小小的身影背对镜头独自站着。

画面提示词（首帧 / 多图参考生视频）：
```text
黄昏的忍界大战废墟，大地龟裂，遍布巨大陨坑，倒插的苦无与断刀散落各处，烟尘弥漫；画面中央，一个渺小的孤独身影背对镜头站立，少年（金色刺猬短发，蓝色眼睛，双颊各三道须痕，橙黑配色忍者服）；斜阳逆光，低饱和的暖橙与灰色，大远景，航拍视角
```
动态提示词（图生视频）：
```text
镜头从高空缓慢下降并推近人物，烟尘横向飘过画面，人物的头发和衣角被风吹动
```
English：
```text
Dusk over a vast ninja-war battlefield: cracked earth, giant craters, kunai and broken blades stuck in the ground, drifting smoke. A tiny lone figure stands at the center with his back to the camera, a teenage boy (spiky golden-blond hair, blue eyes, three whisker marks on each cheek, orange-and-black ninja outfit). Low warm backlight, desaturated orange and gray. Extreme wide aerial shot; the camera slowly descends and pushes in as dust blows sideways and his hair and clothes stir in the wind.
```
**音效**：风声呼啸，远处余烬噼啪

#### 1B · 0:04–0:07 · 3+00 · 特写 · 固定，浅景深

**画面**：碎石间半埋着一枚破损的木叶护额，护额牌上布满裂痕，黑色布带在风里翻飞。旁白响起。

**标记**：无需对口型（旁白）

画面提示词（首帧 / 多图参考生视频）：
```text
特写：碎石与尘土中半埋着一枚破损的忍者护额，金属牌上刻着树叶标志，布满裂痕和划痕，黑色长布带被风扬起，夕阳在金属上反光，浅景深
```
动态提示词（图生视频）：
```text
布带在风中不停翻飞，细小的尘土掠过地面，镜头固定
```
English：
```text
Close-up: a broken ninja forehead protector half-buried in rubble and dust, its metal plate engraved with a leaf symbol, cracked and scratched, the long black cloth band lifting in the wind, sunset glinting on the metal, shallow depth of field. The band flutters constantly as fine dust skims the ground; static camera.
```
- **鸣人（旁白）**：“我救下了很多人……”　低沉、克制，像自言自语；“很多人”后面留白　`0:04.5–0:07.0`

**音效**：布条猎猎作响

#### 1C · 0:07–0:12 · 5+00 · 近景→特写 · 由手部上摇到脸

**画面**：鸣人缠着绷带的双手捧着一张折痕累累的照片，照片上的自来也在大笑。拇指轻轻擦过照片边缘，镜头上摇到鸣人低垂的脸，眼神从遗憾慢慢变得坚定。

**标记**：无需对口型（旁白，嘴不动）

画面提示词（首帧 / 多图参考生视频）：
```text
近景：一双缠着绷带的手捧着一张皱巴巴的旧照片，照片上一位白色长发、眼下有红色纹路的中年忍者正在开怀大笑，背景是虚化的黄昏废墟
```
动态提示词（图生视频）：
```text
拇指轻轻摩挲照片边缘，镜头缓慢上摇到少年低垂的脸，他的眼神由悲伤慢慢变得坚定，嘴巴始终闭着
```
English：
```text
Close-up: bandaged hands holding a creased old photo of a laughing middle-aged ninja with long white hair and red marks under his eyes, blurred dusk ruins behind. The thumb gently brushes the photo's edge; the camera slowly tilts up to the lowered face of a teenage boy (spiky golden-blond hair, blue eyes, three whisker marks on each cheek, orange-and-black ninja outfit), his eyes shifting from grief to resolve, mouth closed.
```
- **鸣人（旁白）**：“却始终没能救下你。”　更轻，“你”字放轻，带一点鼻音　`0:07.6–0:10.8`

**音效**：风声渐弱

### 镜头2｜时间裂隙｜12秒｜0:12–0:24

音乐：低音弦乐渐强；跃入裂隙时打击乐重击一下  
色调：金色查克拉 × 裂隙后的冷灰蓝雨幕

#### 2A · 0:12–0:16 · 4+00 · 特写 · 缓慢环绕

**画面**：鸣人掌心托着照片，六道查克拉在掌心亮起金光；照片上浮起几缕淡蓝色的残留查克拉，与金光缠绕、共鸣。

画面提示词（首帧 / 多图参考生视频）：
```text
特写：少年的掌心托着一张旧照片，掌心亮起明亮的金色查克拉光芒，照片表面升起几缕淡蓝色的烟状光丝，与金光交缠，黄昏背景虚化
```
动态提示词（图生视频）：
```text
金光由弱变强并有节奏地脉动，淡蓝色光丝螺旋上升与金光交织，细小光粒向上飘散，镜头缓慢环绕手掌
```
English：
```text
Close-up: a palm holding an old photo; bright golden chakra ignites in the palm while wisps of pale blue light rise from the photo and twine with the gold, blurred dusk background. The gold pulses brighter in rhythm, the blue wisps spiral up into it, tiny light motes drift upward; the camera slowly orbits the hand.
```
**音效**：低频共鸣嗡鸣，逐渐增强

#### 2B · 0:16–0:20 · 4+00 · 中景（侧面） · 缓推

**画面**：鸣人面前的空气像水面一样荡开波纹，一道竖直的裂隙被撕开；裂隙那头是冷灰色雨幕和高耸的管道，风雨从裂口吹到鸣人脸上。他侧脸对着裂隙轻声说话。

**标记**：可选对口型（侧脸，可选）

画面提示词（首帧 / 多图参考生视频）：
```text
中景侧面：少年（金色刺猬短发，蓝色眼睛，双颊各三道须痕，橙黑配色忍者服）站在黄昏废墟中，面前的空气像水面一样荡开一圈圈涟漪，中央撕开一道竖直的发光裂隙，裂隙里是冷灰蓝色的密集雨幕和高耸的工业管道，裂隙边缘闪着金光
```
动态提示词（图生视频）：
```text
涟漪向外扩散，裂隙缓缓张开，风和雨丝从裂口吹出，打湿少年的头发和脸颊，镜头缓慢推近他的侧脸
```
English：
```text
Medium side shot: a teenage boy (spiky golden-blond hair, blue eyes, three whisker marks on each cheek, orange-and-black ninja outfit) stands in the dusk ruins; the air before him ripples like a water surface and a vertical glowing rift tears open, showing dense cold blue-gray rain and towering industrial pipes on the other side, gold flickering along its edges. The ripples spread, wind and rain blow out of the rift onto his hair and face; the camera slowly pushes in on his profile.
```
- **鸣人**：“好色仙人，等着我。”　轻声；“好色仙人”带一点怀念的笑意，“等着我”压低、有力　`0:16.8–0:19.4`

**音效**：空间撕裂声（水面加玻璃的质感），裂隙那头传来密集雨声

#### 2C · 0:20–0:24 · 4+00 · 全景（背面） · 跟拍后定住

**画面**：鸣人纵身跃向裂隙。半空中，金色六道查克拉外衣燃起，身后浮现求道玉；他冲进裂隙的一瞬，裂隙在闪光中合拢。

**标记**：首尾帧

画面提示词（首帧 / 多图参考生视频）：
```text
全景背面：少年纵身跃向半空中发光的竖直裂隙，全身燃起金橙色查克拉火焰，正凝成一件发光外衣，身后浮现一圈黑色球体，裂隙里是冷灰色雨幕
```
动态提示词（图生视频）：
```text
少年跃起冲进裂隙，金色查克拉外衣在半空瞬间成形，黑色球体在他身后排成一圈；他没入裂隙后，裂口在强烈金光中迅速合拢，画面短暂泛白
```
English：
```text
Wide shot from behind: the boy leaps toward a glowing vertical rift in mid-air; golden-orange chakra flares over his whole body and condenses into a glowing cloak, a ring of black orbs appearing behind him, cold gray rain inside the rift. He dives in as the cloak fully forms mid-leap; the rift snaps shut in an intense golden flash and the frame briefly whites out.
```
**音效**：起跳风声，查克拉爆燃，裂隙合拢的一声低鸣，加打击乐重击

> 提示：用首尾帧生成：首帧是常态的鸣人起跳，尾帧是六道形态的鸣人冲进裂隙。

### 镜头3｜雨隐村地下水道｜15秒｜0:24–0:39

音乐：先静默，只有滴水和喘息；求道玉挡下黑棒的瞬间进主题动机  
色调：冷灰蓝、昏暗；鸣人登场后金光是唯一的暖光源

#### 3A · 0:24–0:28 · 4+00 · 中景 · 缓慢横移

**画面**：昏暗的圆拱形地下水道，雨水从顶部格栅灌下。负伤的自来也单膝跪在积水里，靠着锈蚀的管道喘息，抬起手指，准备把情报写在身旁老蛤蟆的背上。

画面提示词（首帧 / 多图参考生视频）：
```text
昏暗的圆拱形地下排水隧道，锈蚀铁管沿墙排列，雨水从顶部格栅倾泻而下，积水没过脚踝；白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）单膝跪在积水里，背靠管道，抬起一根手指伸向身旁老蛤蟆（灰绿色，小到能站在人肩上）的后背；冷灰蓝色调，只有格栅透下的微弱天光
```
动态提示词（图生视频）：
```text
雨水不断从格栅落下溅起水花，男人胸口剧烈起伏，颤抖的手指慢慢伸向蛤蟆的背，镜头缓慢横移
```
English：
```text
A dark arched underground drainage tunnel, rusted pipes along the walls, rain pouring through ceiling grates, ankle-deep water. A white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) kneels on one knee in the water against a pipe, raising one finger toward the back of an old toad (gray-green, small enough to sit on a man's shoulder) beside him. Cold blue-gray tones, faint light from the grates. Rain keeps splashing down, his chest heaves, his trembling finger reaches for the toad's back; slow lateral camera move.
```
**音效**：滴水回声，雨水灌入，粗重的喘息

#### 3B · 0:28–0:31 · 3+00 · 中景→特写 · 急推

**画面**：自来也身后的黑暗里亮起一双紫色轮回眼，一根黑棒破空刺向他的后背（慢动作）。

画面提示词（首帧 / 多图参考生视频）：
```text
前景是跪着的白发男人的后背，隧道深处一片漆黑，黑暗中亮起一双发光的紫色同心圆纹眼睛，一根末端尖锐的黑色金属长棒从黑暗中刺出，直指男人的后背
```
动态提示词（图生视频）：
```text
黑棒以慢动作破空刺来，带起一圈水雾，紫色眼睛在暗处一闪，镜头急推向棒尖
```
English：
```text
In the foreground, the back of the kneeling white-haired man; deep in the pitch-black tunnel a pair of glowing purple eyes with concentric rings appear, and a sharp black metal rod thrusts out of the darkness straight at his back. Slow motion: the rod cuts the air trailing a ring of mist, the eyes flash, fast push-in on the rod's tip.
```
**音效**：尖啸般的破风声

#### 3C · 0:31–0:34 · 3+00 · 特写 · 固定，冲击震动

**画面**：金光骤然照亮整条水道。一颗黑色求道玉飞入画面，在棒尖离自来也后背只差一寸时挡住黑棒，黑棒从尖端开始寸寸碎成灰。

画面提示词（首帧 / 多图参考生视频）：
```text
特写：黑色金属长棒的尖端离男人的后背只差一寸，被一颗悬浮的光滑黑色球体正面挡住，接触点迸出金色光芒，整条隧道被金光照亮
```
动态提示词（图生视频）：
```text
黑色球体飞入挡住棒尖，黑棒从尖端开始崩裂成黑色碎屑和灰烬向后飘散，金色冲击波推开四周的雨水，画面轻微震动
```
English：
```text
Close-up: the tip of the black rod stops an inch from the man's back, blocked head-on by a smooth floating black orb; golden light bursts from the point of contact and floods the whole tunnel. The rod crumbles from the tip into black flakes and ash, a golden shockwave pushes the rain outward, slight camera shake.
```
**音效**：沉闷的撞击，金属碎裂，金光嗡鸣

#### 3D · 0:34–0:36 · 2+00 · 近景 · 固定

**画面**：自来也猛地回头，满脸难以置信，被金光照亮。

**标记**：对口型（只有两个字，嘴唇微张也能过）

画面提示词（首帧 / 多图参考生视频）：
```text
近景：白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）猛然回头，满脸惊愕与难以置信，脸上有血迹和雨水，被前方强烈的金光照亮
```
动态提示词（图生视频）：
```text
男人猛地回头，瞳孔收缩，嘴唇微张，金光在他脸上闪动
```
English：
```text
Close shot: a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) whips his head around, stunned and disbelieving, blood and rain on his face, lit by intense golden light ahead. His pupils shrink, lips parting slightly, gold flickering across his face.
```
- **自来也（惊愕）**：“鸣人？”　气声，虚弱，难以置信　`0:34.5–0:35.6`

**音效**：金光嗡鸣延续

#### 3E · 0:36–0:39 · 3+00 · 中景（过肩） · 固定

**画面**：从自来也身后看去：鸣人站在他身前，背对着他，面向黑暗里的敌人。雨落在金色外衣上化成白雾，求道玉在身后缓缓环绕。他没有回头。

**标记**：无需对口型（背影）

画面提示词（首帧 / 多图参考生视频）：
```text
过肩镜头：前景是跪在积水中的白发男人的背影，画面中央，背对镜头的少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）面向隧道深处的黑暗站立；雨水落在他的金色外衣上化作白色蒸汽，金光映在周围的水面上
```
动态提示词（图生视频）：
```text
少年纹丝不动地站着，外衣下摆和发丝在气流中飘动，身后的黑色球体缓缓环绕，落在他身上的雨蒸发成白雾
```
English：
```text
Over-the-shoulder shot: in the foreground the back of the white-haired man kneeling in the water; at the center, a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) stands with his back to the camera, facing the darkness deep in the tunnel. Rain turns to white steam on his golden cloak, gold shimmering on the water. He stands perfectly still, cloak hem and hair moving in the draft, the black orbs slowly orbiting.
```
- **鸣人（不回头）**：“这次，我赶上了。”　平静、笃定，尾音微微发颤，压着情绪　`0:36.4–0:38.6`

**音效**：雨落在查克拉外衣上的嘶嘶声

> 提示：可选（原作考据）：在动态提示词末尾加上“金光顺着水面蔓延到男人身上，为他披上一层薄薄的金色光晕”，交代自来也为什么还能站起来、还能说话。

### 镜头4｜鸣人对佩恩｜20秒｜0:39–0:59

音乐：太鼓加快速弦乐  
色调：冷灰，金色手臂的强光，轮回眼紫光

#### 4A · 0:39–0:42 · 3+00 · 全景（低角度） · 快速推进

**画面**：数名佩恩从隧道深处、两侧墙壁和头顶同时扑来，逆光剪影里只看得见橙色发梢、红云晓袍和发光的轮回眼。

画面提示词（首帧 / 多图参考生视频）：
```text
低角度全景：昏暗的地下隧道里，数名黑袍人（逆光剪影，只看得清橙色发梢、长袍上的红云和发光的紫色眼睛）从正前方、两侧墙壁和头顶的管道上同时扑来，脚下溅起水花，冷色逆光
```
动态提示词（图生视频）：
```text
数个剪影高速冲向镜头，踏起大片水花，紫色眼睛的光拖出残影，镜头快速推进
```
English：
```text
Low-angle wide shot in the dark tunnel: several cloaked figures (backlit silhouettes, only orange hair tips, red clouds on their black cloaks and glowing purple eyes visible) lunge at once from straight ahead, from both walls and from the ceiling pipes, water splashing under their feet, cold backlight. They rush the camera at high speed, glowing purple eyes leaving light trails; fast push-in.
```
**音效**：多人踏水奔袭，衣袍破风

> 提示：其余佩恩一律用逆光剪影加发光轮回眼，不用给每个人做定妆。

#### 4B · 0:42–0:46 · 4+00 · 中景 · 固定

**画面**：自来也脚下一软，鸣人头也不回地伸手扶住他；另一只手轻轻抬起，掌心向前。

画面提示词（首帧 / 多图参考生视频）：
```text
中景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）一只手臂稳稳扶住身旁摇摇欲坠的白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤），另一只手抬到胸前、掌心向前，神情平静；黑色球体环绕，金光照亮隧道
```
动态提示词（图生视频）：
```text
白发男人身子一晃，少年看也不看就伸手扶住他，随即另一只手轻轻抬起，金色外衣表面开始翻涌
```
English：
```text
Medium shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) steadies the swaying a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) with one arm, then raises his other hand to chest height, palm forward, face calm; black orbs orbit behind him and golden light fills the tunnel. The man staggers, the boy catches him without even looking, lifts his free hand, and the surface of his cloak begins to surge.
```
**音效**：查克拉涌动的低鸣

#### 4C · 0:46–0:50 · 4+00 · 大全景 · 固定，剧烈震动

**画面**：金色查克拉化作数条巨大的手臂从外衣里迸出，同时击中所有来袭者，把他们轰进墙壁。墙面龟裂，整条水道都在震动，雨水从裂缝倒灌进来。

画面提示词（首帧 / 多图参考生视频）：
```text
大全景：数条巨大的半透明金色查克拉手臂从少年的外衣中迸射而出，呈放射状同时击中四面八方的黑袍身影，把他们轰进隧道墙壁，墙面龟裂，碎石飞溅
```
动态提示词（图生视频）：
```text
金色手臂瞬间伸出击退所有敌人，墙壁炸出蛛网状裂缝，雨水从裂缝里喷涌倒灌，整个画面剧烈震动
```
English：
```text
Extra-wide shot: several huge translucent golden chakra arms burst from the boy's cloak and strike cloaked attackers in every direction at once, slamming them into the tunnel walls; the walls crack, debris flies. The arms shoot out in an instant, spiderweb cracks spread, rainwater gushes in through them, heavy camera shake.
```
**音效**：查克拉手臂破空，接连撞墙的巨响，墙体龟裂，水流倒灌的轰鸣

#### 4D · 0:50–0:54 · 4+00 · 近景 · 缓推

**画面**：佩恩·天道落在一根管道上，向后滑出一段才稳住，抬起头，轮回眼死死盯着鸣人。

**标记**：对口型（可用侧脸降低难度）

画面提示词（首帧 / 多图参考生视频）：
```text
近景：橙发男人（橙色刺猬短发，浅紫色同心圆纹眼睛，脸上嵌着黑色金属钉饰，身穿高领黑底红云长袍）单膝落在一根粗大的管道上，长袍湿透，抬头直视前方，表情冰冷，紫色眼睛里映着金光
```
动态提示词（图生视频）：
```text
他在管道上向后滑出一段后稳住身形，缓缓抬头冷冷凝视，雨水从发梢滴落，镜头缓慢推近面部
```
English：
```text
Close shot: an orange-haired man (spiky orange hair, pale purple eyes with concentric rings, black metal piercings on his face, high-collared black cloak with red clouds) lands on one knee on a thick pipe, cloak soaked, looking straight ahead with a cold face, gold reflected in his purple eyes. He slides back before steadying, slowly lifts his head and stares, rain dripping from his hair; slow push-in on his face.
```
- **佩恩·天道**：“这种力量……你究竟是谁？”　冰冷、平直，几乎没有起伏，带一丝警惕；可加轻微混响　`0:50.6–0:53.6`

**音效**：落地滑行的摩擦声，滴水

#### 4E · 0:54–0:59 · 5+00 · 近景（仰拍） · 几乎不动

**画面**：仰拍鸣人近景，十字形瞳孔在金光里闪烁，他平静而坚定地报上名字。

**标记**：对口型（全片核心台词，值得用对口型功能精修）

画面提示词（首帧 / 多图参考生视频）：
```text
低角度近景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）正面直视镜头，神情平静而坚定，身后的黑色球体与金光在昏暗的隧道里格外耀眼，雨水在他周围蒸发成雾
```
动态提示词（图生视频）：
```text
少年直视前方开口说话，发丝和外衣领口在气流中轻轻飘动，身后黑色球体缓缓转动，镜头几乎不动
```
English：
```text
Low-angle close shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) looks straight into the camera, calm and resolute, the black orbs and golden glow blazing in the dark tunnel, rain steaming into mist around him. He speaks, hair and collar stirring, the orbs slowly turning; the camera barely moves.
```
- **鸣人**：“漩涡鸣人。”　干脆　`0:54.3–0:55.4`
- **鸣人**：“是被这个人教着长大的忍者。”　放慢，“这个人”加重，带着骄傲　`0:55.8–0:58.8`

**音效**：求道玉转动的低鸣

### 镜头5｜师徒重逢｜18秒｜0:59–1:17

音乐：钢琴加弦乐的温情主题，全片情绪最高点  
色调：金光变柔，暖色落在两人脸上

#### 5A · 0:59–1:04 · 5+00 · 中景→近景 · 缓推

**画面**：敌人被击退，水道暂时安静，雨丝从裂缝里落下。鸣人转身看向自来也，刚才从容迎敌的表情一点点松动，眼眶红了。

画面提示词（首帧 / 多图参考生视频）：
```text
中景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）站在雨丝飘落的隧道里，转身面向画外的人，金光变得柔和，表情从冷静一点点松动，眼眶泛红、含着泪光
```
动态提示词（图生视频）：
```text
少年缓缓转身，表情由平静转为动容，嘴唇抿紧，眼中泪光闪动，镜头缓慢推近
```
English：
```text
Medium shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) stands in the tunnel as thin rain falls through the cracks and turns toward someone off-screen; the golden glow softens and his composure slowly breaks, eyes reddening and glistening. He turns slowly, lips pressed tight, tears shimmering; slow push-in.
```
**音效**：雨声变小，零星水滴

#### 5B · 1:04–1:08 · 4+00 · 近景 · 固定，浅景深

**画面**：自来也看着鸣人的六道形态，目光从金色外衣移到身后的求道玉，再回到鸣人脸上，露出熟悉的笑容。

画面提示词（首帧 / 多图参考生视频）：
```text
近景：白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）靠在管道上仰视前方，脸上带伤，眼中映着金光，嘴角慢慢扬起一个熟悉的豪爽笑容
```
动态提示词（图生视频）：
```text
男人的目光缓缓上下打量，最后停在少年脸上，嘴角慢慢上扬，金光在他脸上轻轻摇曳
```
English：
```text
Close shot: a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) leans against a pipe, looking up, wounded, gold reflected in his eyes, a familiar broad grin slowly forming. His gaze travels over the boy and settles on his face as the grin spreads, golden light flickering softly on his face.
```
**音效**：雨声

#### 5C · 1:08–1:13 · 5+00 · 近景 · 缓慢环绕

**画面**：自来也笑着开口，声音沙哑，满是欣慰。

**标记**：对口型

画面提示词（首帧 / 多图参考生视频）：
```text
近景：白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）笑着看向前方的少年，神情欣慰又骄傲，眼角微湿，背景是被金光照亮的雨丝
```
动态提示词（图生视频）：
```text
男人开口说话，笑容温和，微微点头，镜头缓慢环绕
```
English：
```text
Close shot: a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) smiles at the boy in front of him, proud and relieved, eyes slightly wet, rain lit gold behind him. He speaks with a warm smile and a small nod; the camera slowly arcs around him.
```
- **自来也**：“看来，你已经走得比我想象中远了。”　欣慰、带笑，嗓音略沙哑，“远了”微微拖长　`1:08.6–1:12.4`

**音效**：雨声，钢琴主题进入

#### 5D · 1:13–1:17 · 4+00 · 中景 · 固定

**画面**：鸣人含着泪咧嘴一笑，把自来也的胳膊架到自己肩上，扶着他站起来。

**标记**：对口型（也可以先拍架肩动作，台词给侧脸）

画面提示词（首帧 / 多图参考生视频）：
```text
中景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）眼含泪光却咧嘴笑着，把白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）的一条胳膊架到自己肩上，撑着他站起身，两人并肩，金光包裹着他们
```
动态提示词（图生视频）：
```text
少年把男人的胳膊绕过自己的肩膀，咧嘴大笑，两人一起站直，雨丝落在他们身上
```
English：
```text
Medium shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him), tears in his eyes, breaks into a wide grin as he hooks the arm of a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) over his shoulder and hauls him to his feet; the two stand side by side wrapped in golden light, rain falling on them.
```
- **鸣人**：“所以这一次，换我带你回家。”　先哽咽后笑，“换我”加重　`1:13.4–1:16.6`

**音效**：雨声

> 提示：架肩是分镜里加的动作，用来把“换我带你回家”演出来，也跟镜头7“正要带自来也离开”接上。

### 镜头6｜压倒性的力量｜18秒｜1:17–1:35

音乐：合唱加铜管推到高潮；神罗天征前留 0.5 秒全静音  
色调：冲击波撕开水道，露出雨隐村灰色的天际线和高塔

#### 6A · 1:17–1:20 · 3+00 · 全景 · 固定

**画面**：水道尽头，佩恩·天道缓缓抬起手，掌心对着两人。

**标记**：无需对口型（远景）

画面提示词（首帧 / 多图参考生视频）：
```text
全景：隧道尽头，橙发男人（橙色刺猬短发，浅紫色同心圆纹眼睛，脸上嵌着黑色金属钉饰，身穿高领黑底红云长袍）独自站在积水里，缓缓抬起一只手，掌心朝向镜头，周围的雨滴开始向外偏斜
```
动态提示词（图生视频）：
```text
男人缓缓抬手，周围的雨滴与水面向外偏斜颤动，空气出现透明的扭曲
```
English：
```text
Wide shot: at the far end of the tunnel an orange-haired man (spiky orange hair, pale purple eyes with concentric rings, black metal piercings on his face, high-collared black cloak with red clouds) stands alone in the water and slowly raises one hand, palm toward the camera, raindrops around him starting to bend outward. The water surface trembles and the air warps transparently.
```
- **佩恩·天道（可选）**：“神罗天征。”　低声、冰冷　`1:18.2–1:19.4`

**音效**：念完后留 0.5 秒真空般的静默，再接爆音

#### 6B · 1:20–1:24 · 4+00 · 大全景 · 固定，剧烈震动

**画面**：神罗天征：透明的球形冲击波炸开，掀飞水面，撕开墙壁和顶棚，碎石和积水呈放射状飞出，冲向鸣人与自来也。水道被撕开，露出外面雨隐村的高塔。

画面提示词（首帧 / 多图参考生视频）：
```text
大全景：一道透明的球形冲击波从隧道深处爆发，积水被掀成巨浪，墙壁和拱顶被撕裂掀飞，碎石呈放射状飞散，从破口能看到外面阴雨中高耸的钢铁塔楼
```
动态提示词（图生视频）：
```text
球形冲击波高速扩张，水面炸起巨浪，墙体与顶棚整片剥离飞出，碎石冲向镜头，画面剧烈震动
```
English：
```text
Extra-wide shot: a transparent spherical shockwave erupts from deep in the tunnel, hurling the water into huge waves and tearing away the walls and arched ceiling, debris flying radially; through the breach, towering steel buildings stand in the rain. The sphere expands at high speed, whole sections of wall peel away, debris rushes the camera, violent shake.
```
**音效**：巨大的斥力爆音，水浪炸起，石块飞散

#### 6C · 1:24–1:27 · 3+00 · 中景 · 固定

**画面**：冲击波在鸣人面前骤然停住：一颗求道玉化作黑色圆盾挡在前方，冲击波像撞上了墙，碎石和水浪悬在半空，随后坠落。

画面提示词（首帧 / 多图参考生视频）：
```text
中景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）扶着身旁的白发男人站立，面前一颗黑色球体展开成一面巨大的黑色圆盾，透明冲击波撞在盾上被完全挡住，碎石和水浪悬停在盾前
```
动态提示词（图生视频）：
```text
冲击波撞上黑色圆盾瞬间停住，悬停的碎石和水浪失去力道哗啦坠落，少年纹丝不动，衣角翻飞
```
English：
```text
Medium shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) stands holding up the white-haired man; in front of them one black orb unfolds into a huge black round shield, and the transparent shockwave slams into it and stops dead, debris and waves hanging in mid-air, then losing force and crashing down. The boy doesn't move an inch, his cloak whipping.
```
**音效**：冲击声戛然而止，接碎石落水声

> 提示：原作里求道玉能让忍术失效，用“化盾”来演神罗天征被挡住，原作粉丝会认。

#### 6D · 1:27–1:31 · 4+00 · 全景→远景 · 顺光柱快速拉远

**画面**：鸣人一步踏出，脚下水面荡开金色涟漪；他挥拳，一道金色查克拉光柱贯穿雨幕，把天道轰出水道，撞进远处高塔的外墙，砸出巨大的凹坑。

画面提示词（首帧 / 多图参考生视频）：
```text
全景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）向前踏出一步挥出一拳，脚下水面荡开金色涟漪，一道巨大的金色查克拉光柱从拳前贯穿雨幕，远处一个黑袍身影被光柱击飞，撞向阴雨中高耸的塔楼外墙
```
动态提示词（图生视频）：
```text
少年踏步挥拳，金色光柱瞬间贯穿雨幕，沿途雨滴被蒸发，远处的身影被轰进塔楼外墙砸出巨大凹坑，碎石崩落，镜头顺着光柱快速拉远
```
English：
```text
Wide shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) steps forward and throws a punch, golden ripples spreading across the water under his foot; a massive beam of golden chakra pierces the curtain of rain, vaporizing raindrops along its path, and blasts a distant cloaked figure into the outer wall of a tall building, cratering it as debris falls; the camera pulls back fast along the beam.
```
**音效**：踏水回响，金光轰鸣，远处撞墙的闷响

#### 6E · 1:31–1:35 · 4+00 · 近景（侧脸） · 固定

**画面**：自来也被雨打湿的侧脸，望着远处低声感叹，嘴角带着一丝骄傲的笑。

**标记**：可选对口型（侧脸，可选）

画面提示词（首帧 / 多图参考生视频）：
```text
近景：白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）被雨淋湿的侧脸，望向远方，眼中映着远处的金光和烟尘，神情震撼，又带着一丝骄傲的笑
```
动态提示词（图生视频）：
```text
男人低声自语，雨水顺着脸颊流下，嘴角慢慢扬起，远处的烟尘缓缓升起
```
English：
```text
Close shot: the rain-soaked profile of a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) gazing into the distance, the far-off golden light and dust reflected in his eyes, awed and faintly, proudly smiling. He murmurs to himself, rain running down his cheek, the corner of his mouth rising, dust slowly climbing far behind.
```
- **自来也（低声）**：“这小子……已经强到这种地步了吗？”　喃喃自语，惊叹里带着骄傲，“这小子”后停顿　`1:31.3–1:34.8`

**音效**：雨声，远处碎石落地

### 镜头7｜不对劲的雨｜20秒｜1:35–1:55

音乐：音乐和雨声一起骤停，只剩低频嗡鸣和心跳  
色调：整个世界去饱和；只有金光和黑色裂纹有颜色

#### 7A · 1:35–1:39 · 4+00 · 中景 · 固定，渐入慢动作

**画面**：鸣人扶着自来也正要离开，刚迈出一步，周围的雨滴突然减速，悬停在半空，世界的颜色褪去。

**标记**：首尾帧

画面提示词（首帧 / 多图参考生视频）：
```text
中景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）扶着白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）在雨中迈步离开，背后是被撕开的隧道和雨隐村的塔楼，密集的雨丝落下
```
动态提示词（图生视频）：
```text
两人迈步的同时，雨滴从正常速度逐渐减慢，最终全部悬停在半空，画面颜色逐渐褪成冷灰，只剩少年身上的金光
```
English：
```text
Medium shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) helps a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) walk away through the rain, the torn tunnel and the towers behind them. As they step, the falling rain gradually slows until every drop hangs motionless in mid-air, and the world's color drains to cold gray except the boy's golden glow.
```
**音效**：雨声骤停（全片最关键的一次声音切换），只剩低频嗡鸣

> 提示：用首尾帧生成：首帧正常下雨，尾帧雨滴悬停、画面去色。

#### 7B · 1:39–1:43 · 4+00 · 大远景 · 缓慢航拍横移

**画面**：整个雨隐村：亿万雨滴悬停在空中，远处被击飞的天道定格在塔楼外墙前。天空裂开一道黑色裂纹，像玻璃一样缓缓向下蔓延，是这个世界里唯一还在动的东西。

画面提示词（首帧 / 多图参考生视频）：
```text
大远景：灰暗的雨隐村全景，高耸的钢铁塔楼和管道，亿万颗雨滴悬停在空中，像静止的水晶，远处一座塔楼的外墙前，一个黑袍身影定格在半空；阴云密布的天空裂开一道漆黑的裂纹，边缘泛着微弱的白光
```
动态提示词（图生视频）：
```text
所有雨滴和人物完全静止，只有天空中的黑色裂纹像碎玻璃一样缓慢向下蔓延、分叉，镜头缓慢横移
```
English：
```text
Extreme wide shot: the gloomy rain village of towering steel buildings and pipes, billions of raindrops frozen in mid-air like still crystals, a cloaked figure frozen in mid-air before a distant tower wall; in the overcast sky a pitch-black crack splits open, its edges glowing faintly white. Everything is frozen except the crack, which slowly spreads and branches downward like breaking glass; slow aerial truck.
```
**音效**：细碎、持续的玻璃碎裂声

#### 7C · 1:43–1:47 · 4+00 · 中景（过肩） · 固定

**画面**：鸣人伸手碰了碰面前一颗悬停的雨滴，雨滴纹丝不动。自来也在他身后低声发问，鸣人望着天空回答。

**标记**：可选对口型（自来也是背影；鸣人台词很短，侧脸即可）

画面提示词（首帧 / 多图参考生视频）：
```text
过肩镜头：前景是白发男人的背影，画面里少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）站在悬停的雨滴之间，伸出手指轻触面前一颗静止的雨滴，抬头望向天空，神情凝重
```
动态提示词（图生视频）：
```text
少年的指尖碰到雨滴，雨滴像玻璃珠一样纹丝不动，他慢慢抬头望向天空，神情凝重，周围的雨滴完全静止
```
English：
```text
Over-the-shoulder shot from behind the white-haired man: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) stands among frozen raindrops and touches one with a fingertip; it stays put like a glass bead. He slowly looks up at the sky, grave, every drop around him perfectly still.
```
- **自来也**：“这是你的术？”　警觉，压低声音　`1:43.6–1:45.0`
- **鸣人**：“不是。”　短促、凝重　`1:45.6–1:46.6`

**音效**：低频嗡鸣，心跳

#### 7D · 1:47–1:51 · 4+00 · 仰视远景 · 缓推

**画面**：镜头推向天空中的黑色裂纹，裂纹内部像一面黑色的镜子，开始映出另一幅画面。

画面提示词（首帧 / 多图参考生视频）：
```text
仰视：阴暗的天空中一道巨大的漆黑裂纹，边缘像碎玻璃一样泛着白光，裂纹内部像一面黑色的镜子，隐约映出另一处地方的轮廓
```
动态提示词（图生视频）：
```text
镜头缓慢推向裂纹，裂纹表面像水银一样波动，里面的倒影逐渐清晰
```
English：
```text
Looking up: a huge pitch-black crack in the dark sky, its edges shattered like glass and glowing white; inside it is like a black mirror faintly reflecting the outline of another place. The camera slowly pushes toward it as its surface ripples like mercury and the reflection sharpens.
```
**音效**：低沉的嗡鸣渐强

#### 7E · 1:51–1:55 · 4+00 · 全景（裂纹中的画面） · 固定

**画面**：裂纹里映出未来的木叶：阳光下的村子和火影岩，正从边缘开始一点点化作光尘消失。

画面提示词（首帧 / 多图参考生视频）：
```text
黑色裂纹中映出一幅画面：阳光下的忍者村全景，远处是刻着人像的巨大岩壁，村子的边缘正碎裂成白色光尘向上飘散
```
动态提示词（图生视频）：
```text
村子从边缘开始一块块崩解成光尘向上飘散，消失的地方只留下一片空白，并向画面中央的岩壁蔓延
```
English：
```text
Inside the black crack an image appears: a sunlit hidden ninja village with a giant cliff carved with faces in the distance; the village is crumbling from its edges into white motes of light drifting upward, the vanished parts leaving blank emptiness that spreads toward the carved cliff at the center.
```
**音效**：几乎无声，只有极轻的碎裂声，制造不安

### 镜头8｜结尾悬念｜20秒｜1:55–2:15

音乐：低频压迫长音；冲向裂纹时全编制爆发；骤黑后静音  
色调：金光点亮悬停的雨滴（全片最亮的画面），黑暗从裂纹渗出

#### 8A · 1:55–1:58 · 3+00 · 全景 · 缓慢环绕

**画面**：鸣人松开自来也，一步挡在他和裂纹之间。身后的求道玉缓缓转动，六道查克拉照亮四周悬停的雨滴，像一片金色的星海。

画面提示词（首帧 / 多图参考生视频）：
```text
全景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）张开一只手臂挡在白发男人身前，仰望天空中的黑色裂纹，他的金光照亮了周围亿万颗悬停的雨滴，宛如一片闪烁的金色星海，世界其余部分是冷灰色
```
动态提示词（图生视频）：
```text
身后的黑色球体环缓慢转动，悬停的雨滴被金光一颗颗点亮，镜头缓慢环绕少年
```
English：
```text
Wide shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) stretches one arm out in front of the white-haired man, looking up at the black crack in the sky; his golden light illuminates billions of frozen raindrops like a glittering golden sea of stars, the rest of the world cold gray. The ring of orbs slowly turns, the drops light up one by one; the camera slowly orbits him.
```
**音效**：求道玉转动的低沉嗡鸣

#### 8B · 1:58–2:03 · 5+00 · 仰视远景 · 极慢推进

**画面**：裂纹像呼吸一样脉动，黑雾从裂口渗出，一个分不清男女的陌生声音从裂纹中传来。

**标记**：无需对口型（画外音）

画面提示词（首帧 / 多图参考生视频）：
```text
仰视远景：天空中的黑色裂纹像在呼吸一样脉动，裂口渗出缕缕黑雾缓缓向下流淌，黑雾附近悬停的雨滴微微颤动
```
动态提示词（图生视频）：
```text
裂纹有节奏地张合脉动，黑雾从裂口缓缓溢出下沉，镜头极慢地推进
```
English：
```text
Low-angle long shot: the black crack in the sky pulses as if breathing, wisps of black mist seeping out and slowly flowing downward, frozen raindrops near the mist trembling faintly. The crack opens and closes in rhythm; extremely slow push-in.
```
- **陌生声音（画外）**：“救下自来也，就要用你原本的未来交换。”　分不清男女，多层叠音加低频混响，语速慢，每个字一样重　`1:58.4–2:02.8`

**音效**：低频轰鸣

#### 8C · 2:03–2:06 · 3+00 · 近景（过肩） · 固定

**画面**：自来也看着鸣人的背影，神情平静而温柔。

**标记**：对口型（台词短，也可以只拍到嘴部以下）

画面提示词（首帧 / 多图参考生视频）：
```text
过肩镜头：前景是背对镜头的少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉），画面里白发男人（高大的中年忍者，白色蓬松长发，眼下红色纹路，额戴带角的“油”字护额，红色外褂配绿色衣裤，浑身带伤）望着少年的背影，神情平静、温柔，带着释然
```
动态提示词（图生视频）：
```text
男人轻声开口，目光温柔，两人之间悬停的雨滴闪着金光
```
English：
```text
Over-the-shoulder shot: in the foreground, a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) seen from behind; beyond him, a white-haired man (tall middle-aged ninja, long spiky white hair, red lines under his eyes, horned forehead protector, red haori over green clothes, wounded) looks at the boy's back, calm, gentle and at peace, and speaks softly, frozen raindrops glinting gold between them.
```
- **自来也**：“鸣人，放下我。”　平静、温柔，像师父最后的嘱咐　`2:03.6–2:05.6`

**音效**：低频嗡鸣

#### 8D · 2:06–2:11 · 5+00 · 特写→近景 · 拳头上摇到脸

**画面**：鸣人的拳头慢慢握紧，金色查克拉在指缝间爆亮。镜头上摇到他仰望裂纹的脸，十字瞳孔燃起怒火。

**标记**：对口型

画面提示词（首帧 / 多图参考生视频）：
```text
特写：少年包裹在金色查克拉中的拳头缓缓握紧，指缝间迸出耀眼金光，背景是悬停的雨滴
```
动态提示词（图生视频）：
```text
拳头缓缓攥紧，金光从指缝爆射，镜头上摇到少年仰望天空的脸，金色十字瞳孔燃起怒意，他咬牙开口
```
English：
```text
Close-up: the boy's fist, wrapped in golden chakra, slowly clenches, blinding gold light bursting between his fingers, frozen raindrops behind. The camera tilts up to the face of a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) as he glares at the sky, golden cross-shaped pupils blazing with anger, and speaks through gritted teeth.
```
- **鸣人**：“我连命运都能打赢。”　压低，咬字重　`2:07.0–2:09.0`
- **鸣人**：“你算什么？”　爆发　`2:09.3–2:10.7`

**音效**：查克拉在拳中压缩的高频嗡鸣

#### 8E · 2:11–2:15 · 4+00 · 仰视全景 · 跟拍，闪白后硬切黑

**画面**：鸣人冲天而起，撞向天空中的裂纹。金光与黑暗正面相撞，强光吞没画面，然后骤黑。

画面提示词（首帧 / 多图参考生视频）：
```text
仰视全景：少年（金色刺猬短发，双颊各三道须痕，金色十字形瞳孔，身披金橙色发光查克拉外衣，衣领一圈黑色勾玉纹，身后悬浮一圈9颗黑色求道玉）化作一道金色流光冲天而起，直扑天空中的巨大黑色裂纹，裂纹中涌出的黑暗迎面扑来，金与黑即将相撞
```
动态提示词（图生视频）：
```text
少年拖着金色光尾高速冲向裂纹，黑暗从裂口中涌出迎击，金光与黑暗正面相撞，爆出刺眼白光吞没整个画面
```
English：
```text
Low-angle wide shot: a teenage boy (spiky golden-blond hair, three whisker marks on each cheek, golden cross-shaped pupils, glowing golden-orange chakra cloak with a ring of black magatama marks on the collar, a ring of nine black orbs floating behind him) rockets into the sky as a streak of golden light straight at the huge black crack while darkness pours out of it to meet him; gold and black collide head-on and a blinding white flash swallows the entire frame.
```
**音效**：起跳爆音，相撞巨响，然后瞬间全静音

> 提示：剪辑：白光最亮的那一帧直接硬切纯黑，静音 1 秒再出片尾卡。

### 片尾卡｜5秒｜2:15–2:20

**画面**：纯黑底，白字“第一集完”；停顿后出现“下集预告：《消失的未来》”。  
**音效**：一声定音鼓或钟声  
**制作**：在剪辑软件里用文字做，不需要 AI 生成。

## 配音表

| 时间码 | 片段 | 角色 | 台词 | 语气 | 口型 |
|---|---|---|---|---|---|
| 0:04.5–0:07.0 | 1B | 鸣人（旁白） | 我救下了很多人…… | 低沉、克制，像自言自语；“很多人”后面留白 | 无需对口型 |
| 0:07.6–0:10.8 | 1C | 鸣人（旁白） | 却始终没能救下你。 | 更轻，“你”字放轻，带一点鼻音 | 无需对口型 |
| 0:16.8–0:19.4 | 2B | 鸣人 | 好色仙人，等着我。 | 轻声；“好色仙人”带一点怀念的笑意，“等着我”压低、有力 | 可选对口型 |
| 0:34.5–0:35.6 | 3D | 自来也（惊愕） | 鸣人？ | 气声，虚弱，难以置信 | 对口型 |
| 0:36.4–0:38.6 | 3E | 鸣人（不回头） | 这次，我赶上了。 | 平静、笃定，尾音微微发颤，压着情绪 | 无需对口型 |
| 0:50.6–0:53.6 | 4D | 佩恩·天道 | 这种力量……你究竟是谁？ | 冰冷、平直，几乎没有起伏，带一丝警惕；可加轻微混响 | 对口型 |
| 0:54.3–0:55.4 | 4E | 鸣人 | 漩涡鸣人。 | 干脆 | 对口型 |
| 0:55.8–0:58.8 | 4E | 鸣人 | 是被这个人教着长大的忍者。 | 放慢，“这个人”加重，带着骄傲 | 对口型 |
| 1:08.6–1:12.4 | 5C | 自来也 | 看来，你已经走得比我想象中远了。 | 欣慰、带笑，嗓音略沙哑，“远了”微微拖长 | 对口型 |
| 1:13.4–1:16.6 | 5D | 鸣人 | 所以这一次，换我带你回家。 | 先哽咽后笑，“换我”加重 | 对口型 |
| 1:18.2–1:19.4 | 6A | 佩恩·天道（可选） | 神罗天征。 | 低声、冰冷 | 无需对口型 |
| 1:31.3–1:34.8 | 6E | 自来也（低声） | 这小子……已经强到这种地步了吗？ | 喃喃自语，惊叹里带着骄傲，“这小子”后停顿 | 可选对口型 |
| 1:43.6–1:45.0 | 7C | 自来也 | 这是你的术？ | 警觉，压低声音 | 可选对口型 |
| 1:45.6–1:46.6 | 7C | 鸣人 | 不是。 | 短促、凝重 | 可选对口型 |
| 1:58.4–2:02.8 | 8B | 陌生声音（画外） | 救下自来也，就要用你原本的未来交换。 | 分不清男女，多层叠音加低频混响，语速慢，每个字一样重 | 无需对口型 |
| 2:03.6–2:05.6 | 8C | 自来也 | 鸣人，放下我。 | 平静、温柔，像师父最后的嘱咐 | 对口型 |
| 2:07.0–2:09.0 | 8D | 鸣人 | 我连命运都能打赢。 | 压低，咬字重 | 对口型 |
| 2:09.3–2:10.7 | 8D | 鸣人 | 你算什么？ | 爆发 | 对口型 |

## 审读意见

### 时长：8 个镜头合计 2分15秒，不是 3 分钟

- 加上 5 秒片尾卡约 2分20秒。这个长度在短视频平台上反而合适，建议把简介里的“约3分钟”改成“约2分20秒”。
- 如果一定要到 3 分钟：镜头1 加两三个自来也的回忆闪回（约 10 秒），镜头5 师徒重逢再拉长约 10 秒，片尾加约 15 秒的下集预告画面，再加一张片名卡。

### 原作考据（不改也能播，改了评论区少挑刺）

- 自来也：原作里他这时喉咙已经被毁、说不出话（所以才把暗号写在深作仙人背上），左臂也已经断了。镜头3 他开口喊“鸣人？”会被较真的观众指出来。最省事的补法写在 3E 的提示里：鸣人的金色查克拉顺着水面蔓延到自来也身上，给他披一层金光，跟大战时鸣人给联军分查克拉外衣是同一个做法。这样交代了他为什么还能站、还能说话，一句台词都不用加。
- 左臂：AI 很难稳定生成断臂，建议保留双臂，或者用外褂和构图挡住左侧。
- 镜头1 写的是“大战之后”：原作里终结之谷一战后鸣人失去了右前臂，可后面他一手扶自来也、一手抬起。把时间点定在击败辉夜之后、和佐助决战之前，画面和台词都不用改。
- 镜头6 神罗天征被挡住：原作中求道玉能让忍术失效，分镜里用“求道玉化盾”来演，懂的观众会认。

### 前 3 秒的钩子

- 短视频的留存看前 3 秒，而镜头1 是慢节奏独白。可以把 3B–3C（黑棒刺来、求道玉挡下）剪 2 秒放在最前面做冷开场，再切回镜头1。
- 片名卡建议放在 2C 鸣人跃入裂隙、画面泛白之后，3 秒，再进镜头3。

### 分镜里已经做好的取巧

- 其余佩恩全部用逆光剪影加发光轮回眼，避开 6 个角色的一致性问题。
- 需要对口型的只有 7 个片段，其余台词都安排成了旁白、背影或画外音。
- 变身（2C）和雨停（7A）用首尾帧生成，比纯文字描述稳定。
- 5D“把自来也的胳膊架到肩上”是分镜里加的动作，用来把“换我带你回家”演出来，也跟镜头7“正要带自来也离开”接上。
- 6A 天道念“神罗天征”是加的可选台词，不需要就删掉。

### 发布前

- 按平台要求标注“AI生成”，标题或简介里注明“同人/二创”。
- 原作配乐容易被版权识别，导致限流或静音。用剪映曲库或 AI 音乐工具做同风格的配乐（关键词：尺八、太鼓、弦乐、和风热血）。
- 配音用自己有授权的音色，不要克隆原作声优的声音。
