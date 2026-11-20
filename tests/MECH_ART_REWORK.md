# 机甲造型返工

2026-11-11。用户认为首次接入的 3D 机甲外观太差，本轮保留实时骨骼和战斗接入，重做外形。参考项目现有赤鸢、夜莺、白隼立绘；未下载模型或修改系统文件。

## 改动

- 主体外壳从倒角方盒替换成独立编写轮廓的斜面装甲；细腰、较长的腿、分层胸甲、紧凑头盔和面罩。
- 增加关节轴盖、液压杆、散热格栅及分节手指；发光区域缩小，避免胸口和小腿的大块光色遮盖结构。
- 赤鸢为红白双涡轮；夜莺为细长紫甲、尖翼及琥珀色灯；白隼为白蓝重甲和分段背环。
- 枪械外壳、能量剑尖和手持盾轮廓同步调整；材质使用逐像素光照，增加自身投影，整备渲染提高至 512×512，战场保持 256×256。

## 实际画面

- [赤鸢](../.local/rig3d/redesign/chassis-0.png)
- [夜莺](../.local/rig3d/redesign/chassis-1.png)
- [白隼](../.local/rig3d/redesign/chassis-2.png)
- [游戏内录像](../.local/rig3d/redesign/browser/motion-acceptance.webm)

这些是 Godot 实际渲染，不是概念效果图。当前仍为风格化硬表面模型，与原立绘的精细建模、纹理和磨损细节有差距；测试只验证功能和运行表现，不能证明用户满意造型。

## 检查

腿部骨骼长度和装甲改动后的原生图形专项 59 项通过、0 失败：`.local/rig3d/redesign/native-output.log`。随后调整头盔面罩遮挡和装甲高光，已重新渲染查看三台机体。最终导出日志：`.local/rig3d/redesign/export-output.log`。浏览器操作记录：`.local/rig3d/redesign/browser-output.log`，性能采样：`.local/rig3d/redesign/browser/frame-times.json`。手机尺寸检查运行在桌面 Chrome，不能代表手机真机性能。

最终检视页使用 Intel UHD Graphics 630 / ANGLE Metal，89 个帧间隔样本的中位数与 P95 均约 16.7 ms。这是短时页面采样，不代表持续密集战斗的帧耗时。H5 与压缩托管包的 PCK/JS、解压后的 WASM 一致，记录为 `.local/rig3d/redesign/build-check.json`；仅更新本地，未发布线上版本。

最终浏览器完整流程通过，无 JS/Godot 错误，覆盖三台机体、六种动作、五类武器、暂停护盾受击、手机尺寸及宽屏布局、真实训练、触控移动及自动战斗切换。已查看游戏内枪管和激光对齐、贴体护盾与战场实际尺寸。
