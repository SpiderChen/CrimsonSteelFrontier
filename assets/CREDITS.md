# 素材来源与授权

项目保留 **72 个 Kenney CC0-1.0 原文件**，合计 **2,180,358 字节**，其中 **58 个当前使用**（22 个界面图片、36 个音效），14 个旧版场景与面板资源已停用。均来自项目缓存的官方素材包。运行时本地加载；逐文件启用状态见 `free/manifest.json` 的 `active_in_game`。

| 素材包 | 素材库内容（包含停用文件） | 原文件数 | 官方来源 |
| --- | --- | ---: | --- |
| Sci-fi Sounds | 武器与命中变体、脉冲、推进、排热、发现、维修、暴击、护盾、爆破、奖励与界面反馈 | 36 OGG | https://kenney.nl/assets/sci-fi-sounds |
| UI Pack: Sci-fi | 普通/主按钮、设施卡片、准星、铆钉装甲面板、能量灯带；面板亦组合用于建筑、首领平台和补给设施 | 9 PNG | https://kenney.nl/assets/ui-pack-sci-fi |
| Background Elements Redux / Remastered | 月亮、云雾、枯树、霜冻植被、沙海灌丛、建筑围栏 | 7 PNG | https://kenney.nl/assets/background-elements-remastered |
| Game Icons | 母舰设施、导航、资源、声音、补给/冷却/武器库/首领等图标 | 20 PNG | https://kenney.nl/assets/game-icons |

作者：Kenney（https://kenney.nl）。许可证：https://creativecommons.org/publicdomain/zero/1.0/。
素材包原版许可全文保存在 `free/licenses/`。文件级来源、原始路径、用途及 SHA-256 见 `free/manifest.json`。可通过 `python3 tools/import_free_assets.py` 从 `tools/downloads/` 中的原始包重新选入并生成清单。

## 使用与改编

- 原 PNG/OGG 文件保持原样复制。Godot 在运行时裁切图标透明边、调色、拉伸、九宫格缩放，以及组合多层面板。
- 界面按钮、设施卡片、图标和状态条优先采用现有 Kenney CC0 素材；状态条使用原包的边框及填充图。
- 场景、敌军、首领、装备与战斗特效使用下述原创图片；旧版将界面面板组合成建筑的绘制已替换。地图碰撞和伤害判定仍由玩法逻辑控制。
- 音效采用原版 OGG，按武器发射、实际命中、敌军开火、技能、奖励及探索/移动事件分别播放。武器与命中采用不连续重复的多采样和轻微音高/音量变化，独立随机源不影响玩法；脉冲与持续激光、招募与强化采用独立音色。相对机甲的位置控制左右声像与距离衰减，界面提示居中。
- 首次操作后启用，静音立即停止全部声音；采用12声道、按类限流和优先级管理，脚步不能打断开火，重要提示可替换低优先级声音。原版5秒引擎/电脑录音在运行时截取为0.65—1.4秒事件反馈并淡出；混音总线带限幅器，Web使用流式播放以支持相同的音频效果。

已有 Noto Sans SC 字体使用 SIL OFL 1.1，许可见 `fonts/OFL.txt`。机师原图由图像生成工具制作，记录见 `ART.md`，不属于 Kenney 素材包。

## 原创生成的机甲与母舰（2026-11-11）

按用户确认，使用内置 `image_gen` 生成三台完整机甲与一艘完整母舰的透明底 PNG。该组图独立于上面的 Kenney CC0 素材清单，不标注为 CC0。

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `generated/vehicles/mech-crimson.png` | 赤鸢，赤红/石墨/青色发光装甲 | 主战与机库 |
| `generated/vehicles/mech-nightingale.png` | 夜莺，紫色精密火控机体 | 主战与机库 |
| `generated/vehicles/mech-falcon.png` | 白隼，白蓝重型机体 | 主战与机库 |
| `generated/vehicles/carrier-ark.png` | 绯红方舟，带飞行甲板和炮塔的空中母舰 | 母舰首页、旧自由战区及四张探索地图 |

完整最终提示词、工具、日期、分辨率与 SHA-256 记录在 `generated/vehicles/generation.json`。项目内 PNG 保留生成的原始透明通道；运行时缓存透明边裁切区域并按原比例显示。机甲的左右武器、手盾及推进/履带表现继续依据实际配装叠加，静态主体图以整体轻微浮动表现待机与移动。

探索母舰点固定在每张地图的实际降落坐标，显示整舰、停泊圈与“绯红方舟 · 停泊”入口；点击先确认，停泊沿用真实撤离结算。地图拖动和缩放时位置跟随世界坐标，读档后恢复，雷达可显示附近母舰点。

## 场景、装备与战斗特效（2026-11-11）

`generated/production/` 保存 14 张原创源 PNG，共 98 个素材单元：4 种敌军/无人机、4 种首领、16 种地面/道路、4 种建筑、4 种植被残骸、4 种设施、25 件装备、32 帧枪口/命中/爆炸/斩击/弹丸，以及4张护盾/修复/机师技能图和1张机库背景。

完整提示词、生成工具、原文件尺寸和 SHA-256 见 `generated/production/generation.json`。原 PNG 不改写；Godot 导入副本限制至1024像素并使用压缩及 mipmaps。透明图按独立单元裁切，攻击特效绑定实际开火、命中、近战生效窗口与技能状态。生成素材不标为 CC0。总体用途映射见 `REPLACEMENT_COVERAGE.json`。

后续素材选择优先使用已有、明确允许商用的免费素材；缺少匹配资源的部分保留生成图片。

## 界面与同调演出补充

统一按钮改用现有CC0切角装甲边框 `free/ui/armor_wide.png`，由 `scripts/interface_theme.gd` 设置常态、悬停、按下、禁用与键盘焦点。模态窗口和战斗HUD共用CC0设施面板；旧 `button.png`、`button_primary.png` 已停用。招募动态演出由 `scripts/recruit_sequence.gd` 编排，使用现有CC0星形、准星、奖励音效及已有机师立绘；充能圆环、光束和透明度动画由代码实现，无新增生成图片或第三方素材。
