机师立绘源图：`pilots/pilots.png`（1536×1024，三栏各 512 像素）。由内置 imagegen 生成，三位角色均为成年女性：绯夜 26 岁、鸦羽 28 岁、凛 25 岁。游戏用 AtlasTexture 裁切，不依赖在线图片服务。

最终生成提示词：

> Use case: stylized-concept. Asset type: production character portrait sheet for a 2D anime mecha mobile game, three equal vertical panels side by side, 1536x1024 landscape. Primary request: three distinct beautiful clearly adult women mecha pilots age 25-30, seductive confident stylish anime character art, detailed premium gacha game illustration. Left panel: long silver-white hair, scarlet eyes, black and red fitted futuristic bodysuit with tasteful cleavage, cropped armored jacket, red mechanical accessories. Center panel: long dark violet hair, gold eyes, fitted purple futuristic bodysuit with tasteful cleavage, cybernetic headset, composed mature expression. Right panel: short pale blue hair, blue eyes, fitted white and blue futuristic bodysuit, off-shoulder armored jacket and confident smile. Each visible from head to upper thighs, large faces, frontal three-quarter poses, all body parts within own panel. Dark charcoal sci-fi hangar backgrounds with red, violet and blue rim lighting respectively. Sharp clean line art, rich painted shading, exquisite faces, detailed fabric and metal, cohesive art direction. Sexy but fully clothed, no nudity. No words, no text, no logos, no watermark. Equal 3 panels with clean straight boundaries; each character centered in own one-third panel for cropping.

字体：Noto Sans SC，SIL Open Font License 1.1，许可证见 `fonts/OFL.txt`。
机甲与母舰现使用内置 image_gen 生成的完整透明底图，分别对应赤鸢、夜莺、白隼与绯红方舟。四张 PNG 位于 `generated/vehicles/`；完整最终提示词、工具、日期、尺寸及 SHA-256 见 `generated/vehicles/generation.json`。主体图保留原始透明通道，运行时按透明边界等比例适配；武器、手盾、推进器和履带仍由程序随配装叠加。生成图属于独立来源，不标为 Kenney CC0 素材。

界面按钮、状态条、图标与17种音效使用现有 Kenney CC0 素材。场景、敌军、首领、25件装备及攻击/技能特效采用 `generated/production/` 的14张源图、98个素材单元，完整提示词与来源见其 `generation.json`。原始图不修改；游戏使用压缩导入副本、独立单元裁切及实际事件驱动的特效动画。来源及许可证见 `CREDITS.md`，覆盖映射见 `REPLACEMENT_COVERAGE.json`。
