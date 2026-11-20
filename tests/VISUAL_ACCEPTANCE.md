# 动作与特效实画面验收 · 2026-11-11

本轮直接启动原生 OpenGL 和 Chrome WebGL 游戏检查，使用隔离浏览器存档，不改玩家档案或系统配置。没有把无窗口测试通过当作画面验收。

实际画面暴露并修正的问题：

- 脚底圆圈像额外的竖直护罩：改为贴地椭圆阴影与选中标记，悬浮时留在地面。
- 透明杂点撑大装备裁切框，使剑、枪缩成小图标：以主要不透明连通区域裁边，按三台机体分别校准手掌位置；枪、剑、锤、拳套分别按手柄位置挂载。
- 转身瞬间翻面、身体移动而手臂固定：改为 0.24 秒连续转身，扩大交替迈步与抬脚，手臂、握持点和随体护盾共用变形。
- 后撤时背向敌人、武器穿过身体：交战时保持朝向目标并倒步，探索时朝向移动方向。
- 护盾轮廓跨过腿间空隙：改用真实透明边界的闭合轮廓，保留凹部；常态低透明度，受击仅来弹侧短暂变亮。
- 光束从身体中间出现、剑弧与手中剑角度不同：光束和枪口火花使用武器枪口，剑弧共用实际挥剑曲线，朝左挥击也同步。

保留的九类局部反馈为落脚、刹停、推进起步、命中、击破、发现、回收、维修、排热；受实际事件驱动，有数量和寿命上限。

可复查证据：

- [完整实画面录像](../.local/acceptance/motion-acceptance.webm)
- [修改前检视画面](../.local/acceptance/review-before.png)
- [受击护盾暂停帧](../.local/acceptance/shield-hit-paused.png)
- [激光与枪口](../.local/acceptance/review-weapon-0.png)
- [手机训练实弹](../.local/acceptance/training-laser-mobile.png)
- [实际触控移动](../.local/acceptance/field-moving-mobile.png)
- [宽屏实战](../.local/acceptance/field-desktop.png)

本轮原生完整回归 805 项通过；其后朝向与弧光校准通过最终动作专项 39 项。日志分别为 `.local/acceptance/regression-output.log`、`.local/acceptance/release-motion-output.log`。两份通过日志均单独检查无 `SCRIPT ERROR`，没有采用中途编译失败的结果。

浏览器验收脚本为 `tests/motion_browser.cjs`：三个机体、五种推进、五类武器、暂停受击、半速、390×844 手机与 1440×900 桌面、激光与生存训练，以及跳过出击剧情后真实触控移动和自动战斗切换。出击剧情暂停期间的输入不算移动验收。最终完整流程通过，无 JS/Godot 错误，见 `.local/acceptance/browser-verified-output.log`；实际触控位移超过 10 世界单位，手动接管关闭自动，点击自动战斗恢复自动状态。

本地 H5 与 `publish/dist` 已同步，PCK SHA-256 为 `2a32a1a68558a464a4e2494404c311952769308d8706ac28b2df50ecc7217ecb`，PCK/JS 一致，压缩 WASM 解压后匹配原始导出；见 `.local/acceptance/build-check.json`。线上地址没有重新发布。

画面仍是现有 2D 原画驱动的程序动作，不能称为完整三维骨骼或逐帧动画；本轮验收针对上述错位、遮挡、衔接与特效同步问题。
