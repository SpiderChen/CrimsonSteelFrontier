# 实时 3D 机甲验收

2026-11-11，按用户选择的第二种方案实施。三台玩家机甲使用真实三维网格、15 根骨骼、单骨骼权重 GPU 蒙皮及实时渲染，战场、训练、机库和动作检视共用；二维地图和敌军素材仍保留。原机甲插画用于收藏卡片。当前模型为原创低多边形硬表面风格，并非原插画的高精度复刻；程序骨骼动作也不等同于动作捕捉。

## 已实现

- 双腿两段 IK，行走和跑动分别计算支撑/摆动，速度与步幅匹配地图位移。原生测试中横向、纵向和斜向支撑脚的最大世界坐标漂移约 0.0002。
- 连续三维转身、躯干独立瞄准、后撤朝向目标；悬浮收腿、推进冲刺、履带底盘及滚动履带片。
- 三台机体比例和轮廓、配装背包和武器几何有区别。枪口从实际三维挂点投影，枪管对准屏幕目标；剑、拳、锤响应实际攻击时间，剑光带取实际剑尖轨迹。
- 护盾复用装甲网格和骨骼，只显示薄边缘及来弹侧短闪。关闭预览释放模型和视口，被模态窗口遮挡的机库不继续渲染。
- 六种动作、360 度转身、五类武器、暂停/半速及演示受击可在整备的“3D 动作与特效检视”操作。

## 验证与证据

完整原生回归 **823 项通过，0 失败**：`.local/rig3d/final-regression-output.log`。随后增加枪管瞄准校准，最终原生图形专项 **59 项通过，0 失败**：`.local/rig3d/aim-native-output.log`。均无脚本错误。原生使用 AMD Radeon Pro 555X OpenGL；专项实际读回透明渲染图，并覆盖骨骼、IK、投影、GPU 蒙皮表面数量、武器挂点、护盾及资源释放。

最终浏览器流程通过，无 JS/Godot 错误，日志为 `.local/rig3d/final-browser-output.log`。画面记录保存在 `.local/rig3d/final/`，流程包括三台机体、六种动作、连续转身、五类武器、暂停受击、390×844 和 1440×900 布局、真实激光/生存训练、出击触控移动和自动战斗切换。测试使用独立浏览器存档，不修改玩家存档。已查看最终跑动、不同转身角度、激光枪管对齐、暂停护盾及实际训练和战场截图。

- [完整操作录像](../.local/rig3d/final/motion-acceptance.webm)
- [激光与枪管](../.local/rig3d/final/review-weapon-0.png)
- [跑动](../.local/rig3d/final/review-drive-2.png)
- [履带](../.local/rig3d/final/review-drive-5.png)
- [护盾受击暂停](../.local/rig3d/final/shield-hit-paused.png)
- [帧耗时采样](../.local/rig3d/final/frame-times.json)

浏览器默认使用硬件加速 Chrome，Intel UHD Graphics 630 / ANGLE Metal；最终 89 个间隔采样中位数约 16.7 ms，P95 约 16.8 ms。帧耗时为检视页短时 requestAnimationFrame 采样，不能代表手机真机或持续密集战斗性能。较早 SwiftShader 软件渲染记录与当前硬件采样使用不同后端，不能直接比较为优化倍数。

## 复现

在项目根目录运行，Godot 日志路径使用本机项目绝对路径：

```sh
./tools/Godot.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility tests/test_runner.tscn -- --test --motion-only
python3 tools/serve.py --port 8061
PLAYWRIGHT_BROWSERS_PATH="$PWD/.local/playwright" RECORD_VIDEO=1 OUTPUT_DIR=.local/rig3d/final node tests/motion_browser.cjs
```

本地标准 H5 为 `build/web/`，压缩托管包为 `publish/dist/`；最终资源一致性记录为 `.local/rig3d/build-check.json`。本轮未发布线上版本，未修改系统配置或系统文件。
