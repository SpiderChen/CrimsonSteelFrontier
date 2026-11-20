# 自然持械与武器辨识

2026-11-11，针对“一直举着手”和“武器不明显”的反馈。

原先所有非剑/锤武器直接使用固定抬臂姿势，且动作检视自动反复攻击。现在左右手独立计算接敌准备，按射程和视线决定是否抬枪；实际枪口闪光和持续光束保持瞄准，结束后短暂收势再放下。没有目标时步枪斜向下携带，拳套、盾牌自然放低，导弹仍在飞行不强迫手臂举起。近战起手和收招也从当前持械姿势平滑进入/退出，不改变碰撞、伤害或攻击时序。

检视默认仅展示移动和持械；新增“攻击演示”开关，每次攻击前有准备时间，攻击间隔可观察收势。武器按类型扩大，步枪使用深色主体/浅色护壳，导弹以四联炮口和黄色标识区分，能量剑使用加宽粉色光刃。枪口和剑光始终使用缩放后的实际三维挂点。

- [自然持枪](../.local/rig3d/weapon-carry/browser/rifle-carry-idle.png)
- [抬枪射击](../.local/rig3d/weapon-carry/browser/rifle-firing.png)
- [停火放下](../.local/rig3d/weapon-carry/browser/rifle-lowered-after-fire.png)
- [操作录像](../.local/rig3d/weapon-carry/browser/motion-acceptance.webm)

原生图形动作专项 73 项通过，0 失败，无脚本错误：`.local/rig3d/weapon-carry/final-native-output.log`。新增覆盖自然持枪与拳套、逐手抬枪、逐渐起势、放大后枪管/光束对齐、收势回位、暂停不推进、飞行导弹不保持举臂、剑/锤/拳套起止连续，以及检视默认不攻击、显式开启/关闭攻击。

浏览器完整流程通过，无 JS/Godot 错误：`.local/rig3d/weapon-carry/browser-output.log`；包括三台机体、六种动作、五类武器、明确开启/关闭攻击、手机/宽屏、真实训练、触控移动与自动战斗。已实际查看持枪、射击与停火截图。随后对近战起止过渡的修正由上述原生专项验证。

本地导出日志为 `.local/rig3d/weapon-carry/final-export-output.log`。未发布线上版本，未修改系统文件。
