# Rails loads structure.sql with `mysql --execute "SOURCE file"`. MySQL 9.x clients no longer
# accept SOURCE through --execute (they send it to the server, which answers ERROR 1064).
# Feeding the file on stdin works on every client version (8.x, 9.x, MariaDB).
require "open3"

module MysqlStructureLoadViaStdin
  def structure_load(filename, extra_flags)
    args = prepare_command_options
    args.concat([ "--database", db_config.database.to_s ])
    args.unshift(*extra_flags) if extra_flags

    script = "SET FOREIGN_KEY_CHECKS = 0;\n#{File.read(filename)}\nSET FOREIGN_KEY_CHECKS = 1;\n"
    output, status = Open3.capture2e("mysql", *args, stdin_data: script)
    return if status.success?

    raise "failed to execute:\nmysql #{args.join(' ').gsub(/--password=\S+/, '--password=[FILTERED]')}\n\n#{output}"
  end
end

ActiveSupport.on_load(:active_record) do
  require "active_record/tasks/database_tasks"
  ActiveRecord::Tasks::MySQLDatabaseTasks.prepend(MysqlStructureLoadViaStdin)
end
