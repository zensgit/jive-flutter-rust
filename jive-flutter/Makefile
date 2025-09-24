# Flutter 项目自动化任务
# 用于本地开发体验优化
# 创建日期: 2025-09-20

.PHONY: help flutter-fix flutter-analyze flutter-test flutter-clean flutter-all setup-artifacts

# 默认目标 - 显示帮助
help:
	@echo "Flutter 项目 Makefile 命令:"
	@echo "  make flutter-fix      - 应用自动修复 (dart fix --apply)"
	@echo "  make flutter-analyze  - 运行分析并保存报告"
	@echo "  make flutter-test     - 运行测试并保存报告"
	@echo "  make flutter-clean    - 清理并重新获取依赖"
	@echo "  make flutter-all     - 执行完整流程: 清理->修复->分析->测试"
	@echo "  make setup-artifacts  - 创建输出目录"

# 创建输出目录
setup-artifacts:
	@mkdir -p local-artifacts
	@echo "✅ 输出目录 local-artifacts/ 已创建"

# 应用自动修复
flutter-fix: setup-artifacts
	@echo "🔧 正在应用自动修复..."
	@dart fix --apply | tee local-artifacts/dart-fix-$(shell date +%Y%m%d-%H%M%S).log
	@echo "✅ 自动修复完成"

# 运行分析并保存报告
flutter-analyze: setup-artifacts
	@echo "📊 正在运行 Flutter 分析..."
	@flutter analyze | tee local-artifacts/flutter-analyze.txt
	@echo "✅ 分析完成，报告已保存到 local-artifacts/flutter-analyze.txt"
	@echo "📈 错误统计:"
	@echo "  Errors: $$(grep -c '^  error ' local-artifacts/flutter-analyze.txt || echo 0)"
	@echo "  Warnings: $$(grep -c '^warning ' local-artifacts/flutter-analyze.txt || echo 0)"
	@echo "  Info: $$(grep -c '^   info ' local-artifacts/flutter-analyze.txt || echo 0)"

# 运行测试并保存报告
flutter-test: setup-artifacts
	@echo "🧪 正在运行测试..."
	@flutter test -r expanded | tee local-artifacts/flutter-tests.txt || true
	@echo "✅ 测试完成，报告已保存到 local-artifacts/flutter-tests.txt"

# 清理并重新获取依赖
flutter-clean:
	@echo "🧹 清理项目..."
	@flutter clean
	@echo "📦 重新获取依赖..."
	@flutter pub get
	@echo "✅ 清理完成"

# 完整流程
flutter-all: flutter-clean flutter-fix flutter-analyze flutter-test
	@echo "🎉 所有任务完成!"
	@echo "📁 查看报告: ls -la local-artifacts/"

# 快速检查 - 只运行分析
quick-check: flutter-analyze
	@echo "✅ 快速检查完成"

# 生成分析 JSON 报告（用于工具集成）
analyze-json: setup-artifacts
	@echo "📊 生成 JSON 格式分析报告..."
	@dart analyze --format=json > local-artifacts/flutter-analyze.json 2>&1 || true
	@echo "✅ JSON 报告已保存到 local-artifacts/flutter-analyze.json"

# 统计问题数量
stats:
	@echo "📊 当前问题统计:"
	@flutter analyze --no-pub 2>&1 | grep -E "^Analyzing|error |warning |   info " | tail -5

# 清理生成的报告
clean-artifacts:
	@rm -rf local-artifacts/
	@echo "🧹 报告文件已清理"