# Jarvis macOS MVP

这一目录生成面向公司内部 macOS Apple Silicon 用户的本地安装包：

- 签名 `Jarvis.app`
- 签名 DMG
- 预构建 `jarvis-server`、`jarvis-config`、补丁版 CC Connect 和前端
- 内置 Node/npm 与 jq，终端用户不需要 Go、CGO 或前端工具链
- 原生 AppKit 安装向导
- 复用 `jarvis-install`、`bootstrap-jarvis-world-model` 和现有 launchd 安装边界

## 构建

构建机需要 Go、Node/npm、clang、hdiutil 和一个可用的 codesign identity：

```bash
GOSUMDB=sum.golang.org ./packaging/macos/build-dmg.sh
```

制品写入 `dist/`，同时生成 `.sha256` 文件。默认使用 `Jarvis Local`
签名，仅适合 MVP 本机或受控测试：

```bash
JARVIS_APP_SIGN_IDENTITY="Developer ID Application: Example Corp (TEAMID)" \
JARVIS_VERSION=0.1.0 \
GOSUMDB=sum.golang.org \
./packaging/macos/build-dmg.sh
```

如已通过 `notarytool store-credentials` 创建 keychain profile，可同时公证：

```bash
JARVIS_APP_SIGN_IDENTITY="Developer ID Application: Example Corp (TEAMID)" \
JARVIS_NOTARY_PROFILE=jarvis-notary \
./packaging/macos/build-dmg.sh
```

没有 Developer ID 和 notarization 的 DMG 不能作为面向普通用户的正式发布包。

## 安装向导

向导按顺序执行：

1. 把只读运行时复制到 `~/Library/Application Support/Jarvis/runtime`。
2. 调用官方安装器准备 lark-cli、Lark Skills 和 TRAE CLI。
3. 让用户完成 TRAE SSO，并填写明确选择的飞书 profile、open_id、Git author
   和对应 App Secret。
4. 从标准输入把 App Secret 交给 CC Connect 绑定动作；本机 identity 与审批 relay
   写入权限为 `0600` 的 `conf/config.runtime.yaml`。
5. 启动补丁版 CC Connect，下载固定版本 Qdrant，并用预构建服务注册 launchd。
6. 执行 `/healthz`、`/readyz` 和配置权限验收。
7. 打开独立的 `$bootstrap-jarvis-world-model` Agent，生成世界模型草案并等待用户确认。

向导不会猜飞书应用，不会自动覆盖其他 checkout 的 launchd 服务，也不会把背景
初始化复制成固定表单。

## 密钥边界

飞书 App Secret 只通过标准输入交给 CC Connect 绑定动作，不出现在命令行参数和
安装日志。Jarvis 审批 relay secret 由 `jarvis-config` 生成并写入本机 Git 忽略、
权限为 `0600` 的 runtime overlay。Ark 模型身份遵循仓库当前
`internal/ark/config.go` 的单一真源，不由 DMG 向导重复配置。

Jarvis 可执行文件由发布构建机签名。目标机器安装时只验证并保留该签名，不生成、
导入或使用代码签名私钥，因此普通 DMG 用户不需要批准 `codesign` 访问登录钥匙串。
`Jarvis Local` 私钥只属于源码开发者的本机重建路径。

## 升级边界

MVP 的 `prepare` 使用 `ditto` 更新应用文件。发布 payload 不包含
`conf/config.runtime.yaml`、`var/`、`data/` 或 `runs/`，所以升级不会删除用户数据。
数据库迁移仍由 jarvis-server 启动路径负责。

正式自动更新、版本回滚和数据迁移预检不属于本 MVP。
