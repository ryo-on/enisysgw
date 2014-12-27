# coding: utf-8
require "rails/generators"
require "fileutils"

# デフォルトの db:migrate タスクを削除
Rake.application.instance_variable_get(:@tasks).delete("db:migrate")

def gw_static_dbs
  [:jgw_core, :jgw_gw, :jgw_gw_pref]
end

def gw_dynamic_dbs
  [:jgw_bbs, :jgw_doc]
end

def migration_dir_path(dbname)
  Rails.root.join("db", dbname.to_s, "migrate").to_s
end

def invoke_migrate(connection_config, migration_dir, version)
  ActiveRecord::Base.establish_connection(connection_config)
  ActiveRecord::Migrator.migrate(migration_dir, version)
  invoke_schema_dump
  ActiveRecord::Base.establish_connection
end

def invoke_rollback(connection_config, migration_dir, step)
  ActiveRecord::Base.establish_connection(connection_config)
  ActiveRecord::Migrator.rollback(migration_dir, step)
  invoke_schema_dump
  ActiveRecord::Base.establish_connection
end

def invoke_schema_dump
  File.open(ENV["SCHEMA"], "w:utf-8") do |file|
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
  end
end

def apply_dynamic_dbs(use_dbname, &block)
  # MySQL compatible
  databases = ActiveRecord::Base.connection.execute("show databases").to_a.flatten

  apply_databases = databases.select { |db| db =~ /^#{use_dbname}_/ }
  raise "Error: Database #{use_dbname}_00000X doesn't exist." if apply_databases.empty?

  apply_databases.each do |db|
    msg = "Apply to #{db}."
    puts msg
    Rails.logger.info msg

    block.call(db)
  end
end

namespace :db do
  (gw_static_dbs + gw_dynamic_dbs).each do |dbname|
    namespace dbname do

      # 指定された DB の構成を更新する
      # Usage:
      #   % rake db:jgw_core:migrate
      #   % rake db:jgw_core:migrate VERSION=0             # 初期状態へ戻す
      #   % rake db:jgw_core:migrate VERSION=2013XXXXXXXX  # 特定の状態へ更新する
      desc "Migrate the #{dbname} database (options: VERSION=x)."
      task migrate: [:environment, :_setup] do
        migration_dir = migration_dir_path(dbname)

        unless File.exists?(migration_dir)
          FileUtils.mkdir_p migration_dir
        end

        version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
        config = Rails.application.config.database_configuration || {}
        use_dbname = "#{Rails.env}_#{dbname}"

        case true
        when gw_static_dbs.include?(dbname)
          invoke_migrate(config[use_dbname], migration_dir, version)
        when gw_dynamic_dbs.include?(dbname)
          apply_dynamic_dbs(use_dbname) do |db|
            invoke_migrate(config[Rails.env].merge("database" => db), migration_dir, version)
          end
        else
          raise ArgumentError, "Error: Unknown apply_to dbname #{dbname}."
        end

      end

      # 指定された DB の状態を一つ前の状態へ戻す
      # Usage:
      #   % rake db:jgw_core:rollback
      desc "Rolls the #{dbname} database schema back to the previous version (options: STEP=x)"
      task rollback: [:environment, :_setup] do
        migration_dir = migration_dir_path(dbname)

        step = ENV["STEP"] ? ENV["STEP"].to_i : 1
        config = Rails.application.config.database_configuration || {}
        use_dbname = "#{Rails.env}_#{dbname}"

        case true
        when gw_static_dbs.include?(dbname)
          invoke_rollback(config[use_dbname], migration_dir, step)
        when gw_dynamic_dbs.include?(dbname)
          apply_dynamic_dbs(use_dbname) do |db|
            invoke_rollback(config[Rails.env].merge("database" => db), migration_dir, step)
          end
        else
          raise ArgumentError, "Error: Unknown apply_to dbname #{dbname}."
        end

      end

      task :_setup do
        # To db:schema:dump
        ENV["SCHEMA"] = "#{Rails.root}/db/#{dbname}/schema.rb"
      end
    end
  end
end
