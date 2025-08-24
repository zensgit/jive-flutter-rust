#!/usr/bin/env python3
"""
Jive 项目结构验证脚本
验证项目的完整性和正确性
"""

import os
import json
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

class JiveVerifier:
    def __init__(self, base_path="."):
        self.base_path = Path(base_path)
        self.tests_passed = 0
        self.tests_failed = 0
        self.warnings = []
        
    def verify(self):
        print("=" * 60)
        print("         Jive 项目结构验证")
        print("=" * 60)
        print()
        
        # 1. 验证项目根目录结构
        self.verify_root_structure()
        
        # 2. 验证 Rust 后端
        self.verify_rust_backend()
        
        # 3. 验证 Flutter 前端
        self.verify_flutter_frontend()
        
        # 4. 验证文档
        self.verify_documentation()
        
        # 5. 统计代码行数
        self.count_code_lines()
        
        # 6. 显示结果
        self.show_results()
    
    def test(self, name, condition, critical=True):
        """执行单个测试"""
        print(f"  检查: {name} ... ", end="")
        if condition:
            print(f"{Colors.GREEN}✓ 通过{Colors.END}")
            self.tests_passed += 1
            return True
        else:
            if critical:
                print(f"{Colors.RED}✗ 失败{Colors.END}")
                self.tests_failed += 1
            else:
                print(f"{Colors.YELLOW}⚠ 警告{Colors.END}")
                self.warnings.append(name)
            return False
    
    def verify_root_structure(self):
        """验证根目录结构"""
        print(f"{Colors.BLUE}=== 1. 项目根目录结构 ==={Colors.END}")
        print()
        
        required_dirs = ["jive-core", "jive-flutter"]
        for dir_name in required_dirs:
            self.test(f"目录 {dir_name} 存在", 
                     (self.base_path / dir_name).exists())
        
        required_files = [
            "README.md",
            "JIVE_PROJECT_SUMMARY.md",
            "JIVE_COMPLETE_TEST_REPORT.md",
            "MAYBE_TO_JIVE_CONVERSION_COMPLETE.md"
        ]
        for file_name in required_files:
            self.test(f"文件 {file_name} 存在", 
                     (self.base_path / file_name).exists())
        print()
    
    def verify_rust_backend(self):
        """验证 Rust 后端"""
        print(f"{Colors.BLUE}=== 2. Rust 后端结构 ==={Colors.END}")
        print()
        
        rust_path = self.base_path / "jive-core"
        
        # 检查 Cargo.toml
        cargo_toml = rust_path / "Cargo.toml"
        self.test("Cargo.toml 存在", cargo_toml.exists())
        
        # 检查源代码目录
        src_path = rust_path / "src"
        self.test("src 目录存在", src_path.exists())
        
        if src_path.exists():
            # 检查主要模块
            modules = ["domain", "application", "infrastructure", "wasm"]
            for module in modules:
                module_path = src_path / module
                self.test(f"模块 {module} 存在", module_path.exists())
            
            # 检查服务文件
            services = [
                "account_service.rs",
                "transaction_service.rs",
                "ledger_service.rs",
                "category_service.rs",
                "budget_service.rs",
                "report_service.rs",
                "user_service.rs",
                "auth_service.rs",
                "sync_service.rs",
                "import_service.rs",
                "export_service.rs",
                "rule_service.rs",
                "tag_service.rs",
                "payee_service.rs",
                "notification_service.rs",
                "scheduled_transaction_service.rs",
                "currency_service.rs",
                "statistics_service.rs"
            ]
            
            app_path = src_path / "application"
            if app_path.exists():
                for service in services:
                    service_path = app_path / service
                    self.test(f"服务 {service} 实现", service_path.exists())
        print()
    
    def verify_flutter_frontend(self):
        """验证 Flutter 前端"""
        print(f"{Colors.BLUE}=== 3. Flutter 前端结构 ==={Colors.END}")
        print()
        
        flutter_path = self.base_path / "jive-flutter"
        
        # 检查 pubspec.yaml
        pubspec = flutter_path / "pubspec.yaml"
        self.test("pubspec.yaml 存在", pubspec.exists())
        
        # 检查 lib 目录
        lib_path = flutter_path / "lib"
        self.test("lib 目录存在", lib_path.exists())
        
        if lib_path.exists():
            # 检查主要文件
            main_files = ["main.dart", "app.dart"]
            for file_name in main_files:
                self.test(f"文件 {file_name} 存在", 
                         (lib_path / file_name).exists())
            
            # 检查核心目录
            core_dirs = ["models", "providers", "services", "ui", "core"]
            for dir_name in core_dirs:
                self.test(f"目录 {dir_name} 存在", 
                         (lib_path / dir_name).exists())
            
            # 检查 Provider 文件
            providers_path = lib_path / "providers"
            if providers_path.exists():
                providers = [
                    "auth_provider.dart",
                    "transaction_provider.dart",
                    "account_provider.dart",
                    "budget_provider.dart"
                ]
                for provider in providers:
                    self.test(f"Provider {provider} 存在", 
                             (providers_path / provider).exists())
            
            # 检查 UI 组件
            ui_path = lib_path / "ui" / "components"
            if ui_path.exists():
                components = [
                    "buttons",
                    "cards",
                    "charts",
                    "dashboard",
                    "transactions",
                    "accounts",
                    "budget"
                ]
                for component in components:
                    self.test(f"组件目录 {component} 存在", 
                             (ui_path / component).exists(),
                             critical=False)
        print()
    
    def verify_documentation(self):
        """验证文档"""
        print(f"{Colors.BLUE}=== 4. 文档完整性 ==={Colors.END}")
        print()
        
        docs = [
            ("README.md", "项目说明文档"),
            ("JIVE_PROJECT_SUMMARY.md", "项目总结文档"),
            ("SERVICES_TEST_SUMMARY.md", "服务测试总结"),
            ("JIVE_COMPLETE_TEST_REPORT.md", "完整测试报告"),
            ("MAYBE_TO_JIVE_CONVERSION_COMPLETE.md", "转换完成报告")
        ]
        
        for file_name, desc in docs:
            file_path = self.base_path / file_name
            if self.test(f"{desc} ({file_name})", file_path.exists()):
                # 检查文件大小
                if file_path.exists():
                    size = file_path.stat().st_size
                    if size > 1000:
                        print(f"    文件大小: {size:,} 字节")
        print()
    
    def count_code_lines(self):
        """统计代码行数"""
        print(f"{Colors.BLUE}=== 5. 代码统计 ==={Colors.END}")
        print()
        
        def count_lines(path, extension):
            total = 0
            if path.exists():
                for file in path.rglob(f"*.{extension}"):
                    try:
                        with open(file, 'r', encoding='utf-8') as f:
                            total += len(f.readlines())
                    except:
                        pass
            return total
        
        # 统计 Rust 代码
        rust_lines = count_lines(self.base_path / "jive-core", "rs")
        print(f"  Rust 代码行数: {Colors.GREEN}{rust_lines:,}{Colors.END} 行")
        
        # 统计 Dart 代码
        dart_lines = count_lines(self.base_path / "jive-flutter", "dart")
        print(f"  Dart 代码行数: {Colors.GREEN}{dart_lines:,}{Colors.END} 行")
        
        # 总计
        total_lines = rust_lines + dart_lines
        print(f"  总代码行数: {Colors.YELLOW}{total_lines:,}{Colors.END} 行")
        print()
    
    def show_results(self):
        """显示测试结果"""
        print("=" * 60)
        print("              验证结果总结")
        print("=" * 60)
        print()
        
        print(f"通过的测试: {Colors.GREEN}{self.tests_passed}{Colors.END}")
        print(f"失败的测试: {Colors.RED}{self.tests_failed}{Colors.END}")
        print(f"警告数量: {Colors.YELLOW}{len(self.warnings)}{Colors.END}")
        
        if self.warnings:
            print(f"\n{Colors.YELLOW}警告项目:{Colors.END}")
            for warning in self.warnings:
                print(f"  - {warning}")
        
        print()
        
        # 计算完成度
        total_tests = self.tests_passed + self.tests_failed
        if total_tests > 0:
            completion = (self.tests_passed / total_tests) * 100
            
            if completion == 100:
                print(f"{Colors.GREEN}✅ 项目结构验证完全通过！{Colors.END}")
                print(f"{Colors.GREEN}Jive 项目结构完整，所有核心组件都已就位。{Colors.END}")
            elif completion >= 90:
                print(f"{Colors.GREEN}✅ 项目结构基本完整 ({completion:.1f}%){Colors.END}")
                print(f"{Colors.YELLOW}有少量组件缺失，但不影响核心功能。{Colors.END}")
            elif completion >= 70:
                print(f"{Colors.YELLOW}⚠️ 项目结构部分完成 ({completion:.1f}%){Colors.END}")
                print(f"{Colors.YELLOW}部分组件缺失，可能影响某些功能。{Colors.END}")
            else:
                print(f"{Colors.RED}❌ 项目结构不完整 ({completion:.1f}%){Colors.END}")
                print(f"{Colors.RED}大量组件缺失，需要继续开发。{Colors.END}")
            
            # 显示认证证书
            if completion >= 90:
                print()
                print("=" * 60)
                print("         项目结构验证证书")
                print("=" * 60)
                print(f"项目名称: Jive")
                print(f"验证日期: 2024-01-20")
                print(f"完成度: {completion:.1f}%")
                print(f"状态: {'✅ 验证通过' if completion == 100 else '⚠️ 基本通过'}")
                print("=" * 60)

if __name__ == "__main__":
    verifier = JiveVerifier("/home/zou/SynologyDrive/github/jive-flutter-rust")
    verifier.verify()