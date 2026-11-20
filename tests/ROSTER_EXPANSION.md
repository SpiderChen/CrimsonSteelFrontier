# 六机体 / 六机师扩展

## 内容与入口

- 机库第二页：苍狼 CV-12（210移速/游击）、曜隼 AR-11（远程火控）、玄甲 GD-06（重装防御）。
- 机师档案第二排：雷娜（格斗）、星澜（导弹）、伊芙（能源支援），每人300游戏内星晶定向邀请，或从六人等概率常驻池招募。
- 每台机体独立装备、成长、词条和战术预设；每位机师独立技能、被动、探索奖励、三项个人任务与三段信赖交流。
- 旧三人存档和三机体存档追加新槽位；保留旧等级、解锁、配装、预设、信赖与挂机认证。云端同时接受旧三人和新六人格式。

## 主体重做证据

`scripts/rig/chassis_forms.gd` 为新增三机独立构建头部、胸腹、肩臂、腿足；真实骨长和IK随型号变化。苍狼窄体长腿、曜隼独眼火控头和稳定支架、玄甲低头宽胸重腿。

- `.local/chassis-forms/grey-review.png`：统一灰材质、统一视角、未装武器，排除配色与装备的影响。
- `.local/chassis-forms/color-review.png`：同一实际模型的彩色前侧对比。
- `.local/roster-acceptance/`：实际Chrome/WebGL手机尺寸操作截图与存档验收。

## 验证

使用项目Godot执行 `tests/test_runner.tscn -- --test`；专项参数有 `--pilots-only`、`--mechs-only`、`--motion-only`、`--interface-only`、`--story-only`、`--salvage-only`。

云端：`python3 -m unittest server.test_server -q`。

浏览器：`node tests/roster_browser.cjs`。使用全新临时浏览器上下文，执行实际300星晶邀请、换乘、技能查看、训练、手动出击/自动战斗和读档，并读取该上下文的IndexedDB确认结果。

立绘原图与完整生成提示词见 `assets/pilots/EXPANSION_ART.md`。

## 本轮结果

- 整合玩法/存档检查：1026通过、0失败，日志 `.local/roster-expansion/full-final-console.log`，无脚本错误。
- 重做主体后的原生3D动作：92通过、0失败，日志 `.local/chassis-forms/native-final-output.log`。
- 云端：19项通过，日志 `.local/roster-expansion/server-tests.log`。
- H5已重新导出；`build/web` 与 `publish/dist` 的PCK、JS及解压后WASM校验一致，见 `.local/roster-expansion/build-check.json`。

- 实际Chrome/WebGL验收通过：三次300星晶招募、三台新机换乘、技能页面、玄甲搭配伊芙的合法单光束训练（截图记录3074伤害/135命中/1次技能）、手动移动、自动战斗及刷新续档。无浏览器或Godot错误。日志 `.local/roster-expansion/browser-final.log`；持久化结果 `.local/roster-acceptance/roster-acceptance.json`。
