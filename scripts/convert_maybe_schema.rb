#!/usr/bin/env ruby
# 将Maybe的Rails schema.rb转换为标准SQL文件
# 用于Jive Money的数据库初始化

require 'pathname'

# 读取Maybe的schema.rb文件
schema_file = ARGV[0] || '/home/zou/SynologyDrive/github/maybe-main/db/schema.rb'
output_file = ARGV[1] || '/home/zou/SynologyDrive/github/jive-flutter-rust/database/maybe_schema.sql'

unless File.exist?(schema_file)
  puts "Error: Schema file not found: #{schema_file}"
  exit 1
end

# 创建输出目录
output_dir = File.dirname(output_file)
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

puts "Converting Maybe schema to SQL..."
puts "Input: #{schema_file}"
puts "Output: #{output_file}"

# 读取schema内容
schema_content = File.read(schema_file)

# SQL输出
sql_output = []

# 添加头部注释
sql_output << "-- Jive Money Database Schema"
sql_output << "-- Converted from Maybe Rails schema.rb"
sql_output << "-- Generated at: #{Time.now}"
sql_output << ""
sql_output << "-- Enable PostgreSQL extensions"
sql_output << "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";"
sql_output << "CREATE EXTENSION IF NOT EXISTS \"plpgsql\";"
sql_output << ""

# 解析自定义枚举类型
if schema_content =~ /create_enum\s+"(\w+)",\s*\[(.*?)\]/m
  enum_name = $1
  enum_values = $2.gsub(/["']/, '').split(',').map(&:strip)
  sql_output << "-- Create enum types"
  sql_output << "CREATE TYPE #{enum_name} AS ENUM (#{enum_values.map { |v| "'#{v}'" }.join(', ')});"
  sql_output << ""
end

# 转换表定义
tables = []
current_table = nil
current_columns = []
current_indexes = []

# 辅助函数：提取decimal精度
def extract_decimal_precision(options)
  if options =~ /precision:\s*(\d+),\s*scale:\s*(\d+)/
    "DECIMAL(#{$1}, #{$2})"
  else
    nil
  end
end

schema_content.each_line do |line|
  # 匹配表开始
  if line =~ /create_table\s+"(\w+)".*do\s*\|t\|/
    # 保存上一个表
    if current_table
      tables << {
        name: current_table,
        columns: current_columns.dup,
        indexes: current_indexes.dup
      }
    end
    
    current_table = $1
    current_columns = []
    current_indexes = []
    
    # 处理ID列
    if line.include?('id: :uuid')
      current_columns << "    id UUID PRIMARY KEY DEFAULT gen_random_uuid()"
    elsif !line.include?('id: false')
      current_columns << "    id BIGSERIAL PRIMARY KEY"
    end
  
  # 匹配列定义
  elsif current_table && line =~ /^\s*t\.(\w+)\s+"(\w+)"(.*)$/
    type = $1
    column = $2
    options = $3
    
    # 类型映射
    sql_type = case type
    when 'string' then 'VARCHAR(255)'
    when 'text' then 'TEXT'
    when 'integer' then 'INTEGER'
    when 'bigint' then 'BIGINT'
    when 'decimal' then extract_decimal_precision(options) || 'DECIMAL'
    when 'float' then 'FLOAT'
    when 'boolean' then 'BOOLEAN'
    when 'date' then 'DATE'
    when 'datetime' then 'TIMESTAMP WITH TIME ZONE'
    when 'uuid' then 'UUID'
    when 'jsonb' then 'JSONB'
    when 'json' then 'JSON'
    when 'inet' then 'INET'
    when 'virtual' then next  # Skip virtual columns for now
    else type.upcase
    end
    
    # 构建列定义
    column_def = "    #{column} #{sql_type}"
    
    # 添加约束
    column_def += " NOT NULL" if options.include?('null: false')
    
    # 默认值
    if options =~ /default:\s*"([^"]+)"/
      column_def += " DEFAULT '#{$1}'"
    elsif options =~ /default:\s*'([^']+)'/
      column_def += " DEFAULT '#{$1}'"
    elsif options =~ /default:\s*(true|false)/
      column_def += " DEFAULT #{$1.upcase}"
    elsif options =~ /default:\s*(\d+)/
      column_def += " DEFAULT #{$1}"
    elsif options =~ /default:\s*\{\}/
      column_def += " DEFAULT '{}'"
    elsif options =~ /default:\s*->\s*\{\s*"([^"]+)"\s*\}/
      column_def += " DEFAULT #{$1}"
    end
    
    current_columns << column_def
  
  # 匹配索引定义
  elsif current_table && line =~ /^\s*t\.index\s+\[(.*?)\]/
    index_columns = $1.gsub(/["']/, '').split(',').map(&:strip)
    index_name = nil
    unique = false
    
    if line =~ /name:\s*"(\w+)"/
      index_name = $1
    end
    
    if line.include?('unique: true')
      unique = true
    end
    
    current_indexes << {
      columns: index_columns,
      name: index_name,
      unique: unique
    }
  end
end

# 保存最后一个表
if current_table
  tables << {
    name: current_table,
    columns: current_columns,
    indexes: current_indexes
  }
end

# 生成SQL
sql_output << "-- Tables"
tables.each do |table|
  sql_output << "CREATE TABLE #{table[:name]} ("
  sql_output << table[:columns].join(",\n")
  sql_output << ");"
  sql_output << ""
  
  # 生成索引
  if table[:indexes].any?
    sql_output << "-- Indexes for #{table[:name]}"
    table[:indexes].each do |index|
      index_name = index[:name] || "idx_#{table[:name]}_#{index[:columns].join('_')}"
      unique_clause = index[:unique] ? "UNIQUE " : ""
      sql_output << "CREATE #{unique_clause}INDEX #{index_name} ON #{table[:name]} (#{index[:columns].join(', ')});"
    end
    sql_output << ""
  end
end

# 添加外键约束（简化版本，需要手动调整）
sql_output << "-- Foreign Key Constraints"
sql_output << "-- Note: These are inferred and may need manual adjustment"
sql_output << ""

tables.each do |table|
  table[:columns].each do |column|
    if column =~ /(\w+)_id\s+UUID/
      ref_table = $1
      # 尝试推断外键
      if ref_table != 'import' && ref_table != 'plaid' && tables.any? { |t| t[:name] == "#{ref_table}s" }
        sql_output << "ALTER TABLE #{table[:name]} ADD CONSTRAINT fk_#{table[:name]}_#{ref_table}"
        sql_output << "    FOREIGN KEY (#{ref_table}_id) REFERENCES #{ref_table}s(id);"
      end
    end
  end
end

# 写入文件
File.write(output_file, sql_output.join("\n"))

puts "✅ Schema conversion completed!"
puts "📁 Output saved to: #{output_file}"
puts ""
puts "Next steps:"
puts "1. Review the generated SQL file"
puts "2. Adjust foreign key constraints as needed"
puts "3. Run: psql jive_money < #{output_file}"