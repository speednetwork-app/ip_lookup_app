#!/bin/bash
# 替换 YOUR_USERNAME 为你的 GitHub 用户名
# 替换 ip_lookup_app 为你创建的仓库名

cd "D:/SourceTreeRepos/ip_lookup_app"

# 添加远程仓库
git remote add origin https://github.com/YOUR_USERNAME/ip_lookup_app.git

# 重命名默认分支为 main
git branch -M main

# 推送代码到 GitHub
git push -u origin main

echo "✅ 代码已推送到 GitHub！"
echo "访问: https://github.com/YOUR_USERNAME/ip_lookup_app"
