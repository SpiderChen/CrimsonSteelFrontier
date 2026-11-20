# 日系机甲造型

2026-11-11，用户要求“像高达那样”，据此调整现有真实 3D 模型。

白色分层四肢装甲与彩色胸甲分区；小头、前额金色 V 形天线、独立双眼、白色面罩和下巴色块；宽肩窄腰、裙甲、长腿和装甲分缝。赤鸢保留红色突击定位，使用双推进背包和背部剑柄；夜莺保留紫色高速定位及尖翼；白隼使用白蓝重装和大型推进舱。骨骼、IK、真实攻击时序、武器挂点、护盾及存档行为不变。

## 实际渲染

- [赤鸢](../.local/rig3d/mobile-suit/chassis-0.png)
- [夜莺](../.local/rig3d/mobile-suit/chassis-1.png)
- [白隼](../.local/rig3d/mobile-suit/chassis-2.png)
- [游戏内动态录像](../.local/rig3d/mobile-suit/browser/motion-acceptance.webm)

均为项目实际 Godot 渲染，不是独立生成的概念图。模型仍为风格化硬表面几何；本轮调整造型语言，没有引入高精度贴图资产。

## 验证

原生图形动作专项 59 项通过，0 失败，无脚本错误，日志为 `.local/rig3d/mobile-suit/native-output.log`。实际查看三台渲染，确认天线、双眼、面罩、装甲分区和背部轮廓。

最终 Web 导出日志为 `.local/rig3d/mobile-suit/export-output.log`；浏览器过程日志为 `.local/rig3d/mobile-suit/browser-output.log`；截图、录像与帧间隔采样位于 `.local/rig3d/mobile-suit/browser/`。测试使用隔离存档，手机尺寸检查来自桌面 Chrome，不代表手机真机性能。

最终浏览器完整流程通过，无 JS/Godot 错误，覆盖三台机体、六种动作、连续转身、五类武器、暂停受击、手机/宽屏布局、真实训练及出击后的手动移动/自动战斗。已查看新造型在游戏内的枪械射击画面。检视页 89 个帧间隔样本中位数约 16.7 ms、P95 约 33.4 ms，渲染器为 Intel UHD Graphics 630 / ANGLE Metal；这是短时桌面页面采样。

本地 H5 和压缩托管包更新后以 `.local/rig3d/mobile-suit/build-check.json` 核对资源一致性。未发布线上版本，未修改系统文件。
