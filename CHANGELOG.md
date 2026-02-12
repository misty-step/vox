# 1.0.0 (2026-02-12)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **rewrite:** reject hallucinated answers + eval framework ([#228](https://github.com/misty-step/vox/issues/228)) ([0cdb014](https://github.com/misty-step/vox/commit/0cdb014890ac2c42d27d024dac0b379d61589db5))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)
* **streaming:** recover transcript on finalize timeout + Opus diagnostics ([#232](https://github.com/misty-step/vox/issues/232)) ([c369708](https://github.com/misty-step/vox/commit/c36970809c180383a245f5a252c2724c142ba873)), closes [#229](https://github.com/misty-step/vox/issues/229)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **rewrite:** Gemini direct API + OpenRouter latency routing ([#231](https://github.com/misty-step/vox/issues/231)) ([59d491a](https://github.com/misty-step/vox/commit/59d491a2f7ceaa8736e350be3c353083f77c25f7)), closes [#198](https://github.com/misty-step/vox/issues/198)
* **settings:** rework settings UI and key management sheet ([#233](https://github.com/misty-step/vox/issues/233)) ([a29f0d7](https://github.com/misty-step/vox/commit/a29f0d7e4fd655f2dd0813aa02ac5e02c4f4b3e2)), closes [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-12)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **rewrite:** reject hallucinated answers + eval framework ([#228](https://github.com/misty-step/vox/issues/228)) ([0cdb014](https://github.com/misty-step/vox/commit/0cdb014890ac2c42d27d024dac0b379d61589db5))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)
* **streaming:** recover transcript on finalize timeout + Opus diagnostics ([#232](https://github.com/misty-step/vox/issues/232)) ([c369708](https://github.com/misty-step/vox/commit/c36970809c180383a245f5a252c2724c142ba873)), closes [#229](https://github.com/misty-step/vox/issues/229)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **rewrite:** Gemini direct API + OpenRouter latency routing ([#231](https://github.com/misty-step/vox/issues/231)) ([59d491a](https://github.com/misty-step/vox/commit/59d491a2f7ceaa8736e350be3c353083f77c25f7)), closes [#198](https://github.com/misty-step/vox/issues/198)
* **settings:** rework settings UI and key management sheet ([#233](https://github.com/misty-step/vox/issues/233)) ([a29f0d7](https://github.com/misty-step/vox/commit/a29f0d7e4fd655f2dd0813aa02ac5e02c4f4b3e2)), closes [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209) [#209](https://github.com/misty-step/vox/issues/209)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-12)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **rewrite:** reject hallucinated answers + eval framework ([#228](https://github.com/misty-step/vox/issues/228)) ([0cdb014](https://github.com/misty-step/vox/commit/0cdb014890ac2c42d27d024dac0b379d61589db5))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)
* **streaming:** recover transcript on finalize timeout + Opus diagnostics ([#232](https://github.com/misty-step/vox/issues/232)) ([c369708](https://github.com/misty-step/vox/commit/c36970809c180383a245f5a252c2724c142ba873)), closes [#229](https://github.com/misty-step/vox/issues/229)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **rewrite:** Gemini direct API + OpenRouter latency routing ([#231](https://github.com/misty-step/vox/issues/231)) ([59d491a](https://github.com/misty-step/vox/commit/59d491a2f7ceaa8736e350be3c353083f77c25f7)), closes [#198](https://github.com/misty-step/vox/issues/198)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-12)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **rewrite:** reject hallucinated answers + eval framework ([#228](https://github.com/misty-step/vox/issues/228)) ([0cdb014](https://github.com/misty-step/vox/commit/0cdb014890ac2c42d27d024dac0b379d61589db5))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **rewrite:** Gemini direct API + OpenRouter latency routing ([#231](https://github.com/misty-step/vox/issues/231)) ([59d491a](https://github.com/misty-step/vox/commit/59d491a2f7ceaa8736e350be3c353083f77c25f7)), closes [#198](https://github.com/misty-step/vox/issues/198)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-11)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **rewrite:** reject hallucinated answers + eval framework ([#228](https://github.com/misty-step/vox/issues/228)) ([0cdb014](https://github.com/misty-step/vox/commit/0cdb014890ac2c42d27d024dac0b379d61589db5))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-11)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **rewrite:** reject hallucinated answers + eval framework ([#228](https://github.com/misty-step/vox/issues/228)) ([0cdb014](https://github.com/misty-step/vox/commit/0cdb014890ac2c42d27d024dac0b379d61589db5))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-11)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* correct Landfall input parameter name ([#222](https://github.com/misty-step/vox/issues/222)) ([054b20b](https://github.com/misty-step/vox/commit/054b20b1e3d67d46cb6d691744a20121e75526b0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** sequential fallback replaces hedged routing as default ([#221](https://github.com/misty-step/vox/issues/221)) ([228d355](https://github.com/misty-step/vox/commit/228d355cc57b02a32c7db0b1530c24521c27b9d2)), closes [#213](https://github.com/misty-step/vox/issues/213)
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT default ([#219](https://github.com/misty-step/vox/issues/219)) ([0c8eaae](https://github.com/misty-step/vox/commit/0c8eaae9bdb73ea933cceab4421ae44b2082ae49)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** make streaming STT the default path ([#218](https://github.com/misty-step/vox/issues/218)) ([685be7e](https://github.com/misty-step/vox/commit/685be7e8f268404c5b092c970993890e8784dfe3)), closes [#212](https://github.com/misty-step/vox/issues/212)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **streaming:** start recording before WebSocket connects ([#217](https://github.com/misty-step/vox/issues/217)) ([e51fbec](https://github.com/misty-step/vox/commit/e51fbecd8913ba3ef63df7d33f87fb0b3284ca38)), closes [#205](https://github.com/misty-step/vox/issues/205)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** bump Cerberus action to v2 ([#216](https://github.com/misty-step/vox/issues/216)) ([af9f8be](https://github.com/misty-step/vox/commit/af9f8bede614e0e2b9c3ed5ed95eb95634b3f48c))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* **ci:** stop vendoring Cerberus action ([#215](https://github.com/misty-step/vox/issues/215)) ([7e0baa5](https://github.com/misty-step/vox/commit/7e0baa5ea0a2e5cca94bd6aa55680359d66cdff0))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-10)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ui:** premium polish pass for HUD/menu/settings ([#207](https://github.com/misty-step/vox/issues/207)) ([eb308b3](https://github.com/misty-step/vox/commit/eb308b3380abb5a742dd740e79681580809e7dab)), closes [#190](https://github.com/misty-step/vox/issues/190)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
* **rewrite:** bakeoff models; default flash-lite ([#214](https://github.com/misty-step/vox/issues/214)) ([870d03e](https://github.com/misty-step/vox/commit/870d03ebc1dce2d21940a0dc7f1ba4503a0e519c)), closes [#197](https://github.com/misty-step/vox/issues/197)

# 1.0.0 (2026-02-09)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **streaming:** add realtime STT path with finalize fallback ([#204](https://github.com/misty-step/vox/issues/204)) ([d8e28c3](https://github.com/misty-step/vox/commit/d8e28c3e32d752ab2806e5146d883ef58e12601a)), closes [#140](https://github.com/misty-step/vox/issues/140) [#140](https://github.com/misty-step/vox/issues/140)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))

# 1.0.0 (2026-02-09)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **perf:** Opus fast-path policy ([#189](https://github.com/misty-step/vox/issues/189)) ([#203](https://github.com/misty-step/vox/issues/203)) ([df12892](https://github.com/misty-step/vox/commit/df128925bbb2759aaa48ae0b031746d8100c73ad))
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))

# 1.0.0 (2026-02-09)


### Bug Fixes

* **audio:** prevent AirPods/Bluetooth capture truncation ([#177](https://github.com/misty-step/vox/issues/177)) ([dd03bc0](https://github.com/misty-step/vox/commit/dd03bc0b9f7b91298d5fc1a6edec301fd092d610))
* **audio:** prevent crash in opus encode path ([#162](https://github.com/misty-step/vox/issues/162)) ([db7c251](https://github.com/misty-step/vox/commit/db7c251e80f9b094845400a249b7d1b690c1f4d2))
* **audio:** reliable Opus encoding via afconvert ([#166](https://github.com/misty-step/vox/issues/166)) ([a7e1685](https://github.com/misty-step/vox/commit/a7e1685f52b30f5d4d7d4d7844a12419a078156f)), closes [#163](https://github.com/misty-step/vox/issues/163)
* **audio:** surface tap integrity failures to VoxSession ([#175](https://github.com/misty-step/vox/issues/175)) ([#192](https://github.com/misty-step/vox/issues/192)) ([1e65435](https://github.com/misty-step/vox/commit/1e654355b3a759a252aacb35196ca2b3ca0ffc6b))
* resolve compiler warnings ([#142](https://github.com/misty-step/vox/issues/142)) ([043df23](https://github.com/misty-step/vox/commit/043df23ab7dd3940578916c066d7dc3acb72a3b7))
* **security:** add keychain access controls ([#130](https://github.com/misty-step/vox/issues/130)) ([1183287](https://github.com/misty-step/vox/commit/118328715eccba993426af911c377c2095208596)), closes [#114](https://github.com/misty-step/vox/issues/114)
* **security:** gate ClipboardPaster debug logs behind #if DEBUG ([#115](https://github.com/misty-step/vox/issues/115)) ([#146](https://github.com/misty-step/vox/issues/146)) ([c02b1b1](https://github.com/misty-step/vox/commit/c02b1b157be30efe979d3b300473e15d2ea47f58))
* **security:** securely delete temporary audio files ([#147](https://github.com/misty-step/vox/issues/147)) ([118f09a](https://github.com/misty-step/vox/commit/118f09ad6d6cd90c275dcc6a38b8b6ba29bf5431)), closes [#116](https://github.com/misty-step/vox/issues/116) [#116](https://github.com/misty-step/vox/issues/116) [#148](https://github.com/misty-step/vox/issues/148)


### Features

* **appkit:** add product standards surface to settings ([#179](https://github.com/misty-step/vox/issues/179)) ([#194](https://github.com/misty-step/vox/issues/194)) ([ff7ed1d](https://github.com/misty-step/vox/commit/ff7ed1d7e4904827b7acc1644758c8dbbb5d5b67))
* **design:** unify menu icon and HUD visual identity ([#164](https://github.com/misty-step/vox/issues/164)) ([bc9a943](https://github.com/misty-step/vox/commit/bc9a9435986d9f0cfa9d603741cfe7fd624e80d2)), closes [#104](https://github.com/misty-step/vox/issues/104)
* enhance mode + monochromatic menu bar icons ([#132](https://github.com/misty-step/vox/issues/132)) ([ec89a8c](https://github.com/misty-step/vox/commit/ec89a8c37e1f24157702c398449f2eee3ca798d2))
* extract provider protocols for Vox Pro wrapper ([#122](https://github.com/misty-step/vox/issues/122)) ([e628ebd](https://github.com/misty-step/vox/commit/e628ebd1af20612d345348074702239b97d9f8c1)), closes [#117](https://github.com/misty-step/vox/issues/117)
* **hud:** animated dismiss, content transitions, and success flash ([#160](https://github.com/misty-step/vox/issues/160)) ([d5e3d33](https://github.com/misty-step/vox/commit/d5e3d33359b5988366a3bcab3f1bf66cdd582a83)), closes [#103](https://github.com/misty-step/vox/issues/103)
* integrate Landfall release pipeline ([#172](https://github.com/misty-step/vox/issues/172)) ([107a6ae](https://github.com/misty-step/vox/commit/107a6aef761b57429d18f6dee9c5b3b2c02e00d2))
* **perf:** latency budget + benchmark harness + fast git hooks ([#201](https://github.com/misty-step/vox/issues/201)) ([d43863d](https://github.com/misty-step/vox/commit/d43863d3581cf83a5a124686e496be7e65990cf4)), closes [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188) [#188](https://github.com/misty-step/vox/issues/188)
* **performance:** cache accepted rewrite results ([#165](https://github.com/misty-step/vox/issues/165)) ([83bd98d](https://github.com/misty-step/vox/commit/83bd98d0ac55a6d69e28de71244c01118be590bf))
* pipeline timeout, stability tests, and production logging ([#156](https://github.com/misty-step/vox/issues/156)) ([52a52e9](https://github.com/misty-step/vox/commit/52a52e9f4647cefacb8f4a548c9010337c962b9f))
* **quality:** add SwiftLint workflow and CI gate ([#111](https://github.com/misty-step/vox/issues/111)) ([#169](https://github.com/misty-step/vox/issues/169)) ([4fd9380](https://github.com/misty-step/vox/commit/4fd938084b72f67eed818fa880d8092ee56c8e63))
* **release:** add macOS signing and notarization pipeline ([#170](https://github.com/misty-step/vox/issues/170)) ([a300479](https://github.com/misty-step/vox/commit/a300479a0f76e93f6ebc51f412bdd7ac736b4f48)), closes [#112](https://github.com/misty-step/vox/issues/112)
* **stt:** add health-aware provider routing ([#173](https://github.com/misty-step/vox/issues/173)) ([f2a8525](https://github.com/misty-step/vox/commit/f2a85254cbae38b19c7035761b2507ec5377023d)), closes [#126](https://github.com/misty-step/vox/issues/126)
* **stt:** add proactive concurrency limiter ([#171](https://github.com/misty-step/vox/issues/171)) ([94b7a79](https://github.com/misty-step/vox/commit/94b7a79cdcedf5be68ff305667576c4429ee97f7)), closes [#125](https://github.com/misty-step/vox/issues/125)
* **stt:** add retry and fallback resilience for transcription ([#128](https://github.com/misty-step/vox/issues/128)) ([f06ce97](https://github.com/misty-step/vox/commit/f06ce97d48d851108d2ef64d3d913fc957b77e29))
* **stt:** add staggered hedged STT routing ([#138](https://github.com/misty-step/vox/issues/138)) ([#176](https://github.com/misty-step/vox/issues/176)) ([5d1331d](https://github.com/misty-step/vox/commit/5d1331d4f2393d9692bef3bbe2ecc10ad03b0467))
* **stt:** transcription resilience overhaul ([#134](https://github.com/misty-step/vox/issues/134)) ([334088a](https://github.com/misty-step/vox/commit/334088a09697d8a023273103e2579c3747d1b21f))
* **test:** add VoxCore test suite with 26 unit tests ([#131](https://github.com/misty-step/vox/issues/131)) ([5e9cd9d](https://github.com/misty-step/vox/commit/5e9cd9d227dd2dfdb0fac925934fe4024200c274)), closes [#109](https://github.com/misty-step/vox/issues/109)
* **ux:** add VoiceOver HUD semantics and announcements ([#200](https://github.com/misty-step/vox/issues/200)) ([f1f598d](https://github.com/misty-step/vox/commit/f1f598d4c563f0c35774b57d3fac79b9a5f854de)), closes [#184](https://github.com/misty-step/vox/issues/184)
* VoxLocal BYOK rewrite ([e25f118](https://github.com/misty-step/vox/commit/e25f118cf0db64f79e7a5bd5e9a9437505e02e89))


### Performance Improvements

* **audio:** Opus compression for STT uploads ([#137](https://github.com/misty-step/vox/issues/137)) ([#167](https://github.com/misty-step/vox/issues/167)) ([40fa85a](https://github.com/misty-step/vox/commit/40fa85abbca58268982f38fed6c547cb5da5ccd0))
* CAF to Opus conversion, timing instrumentation, file-based uploads ([#155](https://github.com/misty-step/vox/issues/155)) ([790efb6](https://github.com/misty-step/vox/commit/790efb64a24b53cfa5f3802d47589ad0c58b1e71))
