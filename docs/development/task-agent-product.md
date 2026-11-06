# Task Agent 部署与迁移

## 构建与升级

1. 使用仓库根目录的 `.gitattributes` 保持脚本为 LF；Windows Git 建议仅对当前仓库执行：

   ```powershell
   git config --local core.autocrlf false
   git config --local core.eol lf
   git add --renormalize .
   ```

2. 停止写入并备份 PostgreSQL、附件目录或对象存储，以及 `SECRET_KEY_BASE` 和数据库加密密钥。
3. 构建当前分支镜像并运行数据库迁移：

   ```bash
   docker compose build
   docker compose run --rm backend bundle exec rails db:migrate
   ```

4. 启动 Web、Worker、Frontend、PostgreSQL 和缓存服务：

   ```bash
   docker compose up -d
   ```

5. 验证 `/health_checks/default`、Home、Projects、Task 创建、Activity、附件、Agent 和后台 Job。

## 从原 OpenProject 导入

源环境与目标环境必须使用兼容的 OpenProject 版本和数据库 schema。

1. 在源环境停止写入后创建自包含数据库备份：

   ```bash
   pg_dump --format=custom --no-owner --file=openproject.dump OPENPROJECT_DATABASE
   ```

2. 同步附件或对象存储，并安全转移数据库加密密钥。
3. 在目标环境恢复数据库，然后运行当前分支迁移：

   ```bash
   pg_restore --clean --if-exists --no-owner --dbname=OPENPROJECT_DATABASE openproject.dump
   bundle exec rails db:migrate
   ```

4. 运行产品校验：

   ```bash
   bundle exec rake resolution_agent:product:validate
   bundle exec rake resolution_agent:product:diagnose_workflow
   ```

5. 对比 Project、Task、Journal、附件和 Agent 数据数量，并抽样检查历史 Task。

历史 Parent、Relation、Version、工时、成本和已删除模块数据不会在首期迁移中删除，但产品不再公开对应 UI、路由或写入接口。不要使用 CSV 作为正式迁移方式；CSV 无法完整保留 Journal、附件元数据和 Agent 数据。

## Agent 与 Gitea

1. 在 `Administration → Artificial Intelligence (AI) → Agent` 配置服务账号、工作流状态、模型和额外通知接收人。
2. 配置 Gitea Base URL、Token、TLS CA 和 Webhook Secret，保存后执行连接测试。
3. 为每个 Project 映射允许访问的仓库和默认分支。
4. Gitea Webhook 使用 `/resolution_agent/gitea/webhook`，启用 Pull Request 事件并配置相同 Secret。
5. 服务账号必须能查看和更新 Task、添加评论并执行配置的工作流跳转。

Token、API Key、Webhook Secret、数据库加密密钥和源码内容不得写入日志、通知摘要或备份说明文件。
