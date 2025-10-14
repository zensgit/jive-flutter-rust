# jive-manager.sh 帮助文档修复报告

**日期:** 2025-10-12

## 1. 问题描述

在对 `jive-manager.sh` 脚本进行代码审查时，发现其 `show_usage` 函数（用于显示帮助信息）中存在一处文本错误。
具体表现为，关于 `test` 命令的说明文本被意外地复制粘贴了一次，导致 `./jive-manager.sh help` 的输出内容存在冗余。

## 2. 修复方案

通过编辑 `jive-manager.sh` 文件，删除了 `show_usage` 函数中重复的 `echo` 语句块。

### 变更前 (Before):

```bash
# ...
    echo "  test api        - 运行 API 相关测试（含集成测试，需本地DB）"
    echo "  test api-manual - 运行手动汇率(单对)集成测试"
    echo "  test api-manual-batch - 运行手动汇率(批量)集成测试"
    echo "  test api        - 运行 API 相关测试（含集成测试，需本地DB）"
    echo "  test api-manual - 运行手动汇率(单对)集成测试"
    echo "  test api-manual-batch - 运行手动汇率(批量)集成测试"
# ...
```

### 变更后 (After):

```bash
# ...
    echo "  test api        - 运行 API 相关测试（含集成测试，需本地DB）"
    echo "  test api-manual - 运行手动汇率(单对)集成测试"
    echo "  test api-manual-batch - 运行手动汇率(批量)集成测试"
# ...
```

## 3. 影响评估

此修复仅更正帮助命令 (`help`) 的显示文本，对脚本的任何核心功能（如服务的启停、构建、测试执行等）均无任何影响。修复后，帮助信息更加清晰、准确。
