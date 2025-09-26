Docker Hub 认证（可选）

目的
- 避免 CI 拉取公共镜像时触发 Docker Hub 匿名速率限制（100 pulls/6h）。
- 配置后，速率限制提升到 200 pulls/6h，稳定性更好。

步骤
1) 在 Docker Hub 创建 Access Token（建议使用个人或组织账号）
   - 登录 https://hub.docker.com/settings/security
   - 点击 New Access Token，命名并生成，复制 Token（仅显示一次）。

2) 在 GitHub 仓库配置 Secrets
   - Settings → Secrets and variables → Actions → New repository secret
   - 添加：
     - DOCKERHUB_USERNAME：Docker Hub 用户名
     - DOCKERHUB_TOKEN：Docker Hub Access Token

3) CI 工作流已内置可选登录逻辑（无需改代码）
   - 文件：.github/workflows/ci.yml
   - 关键片段：
     - 环境变量
       ```yaml
       env:
         DOCKER_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
         DOCKER_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
       ```
     - 登录步骤（条件启用）
       ```yaml
       - name: Login to Docker Hub
         if: env.DOCKER_USERNAME != '' && env.DOCKER_TOKEN != ''
         uses: docker/login-action@v3
         with:
           username: ${{ env.DOCKER_USERNAME }}
           password: ${{ env.DOCKER_TOKEN }}
         continue-on-error: true
       ```

验证
- 触发任意需要 Postgres/Redis 服务的 CI 任务，确认日志中出现 docker pull 且无 `unauthorized: authentication required`。

常见问题
- 未配置 Secrets：登录步骤会跳过，不影响 CI，只是仍受匿名限流。
- Token 失效：重新生成 Token 并更新 Secret。

附注
- 报告见 DOCKER_AUTH_SOLUTION_REPORT.md。

