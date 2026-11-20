# frozen_string_literal: true

# mysqldump writes DEFINER=`user`@`host` on triggers. That user differs between
# laptops, CI and Cloud SQL, and loading a definer you are not needs SUPER, so
# strip it whenever Rails dumps db/structure.sql.
if Rake::Task.task_defined?("db:schema:dump")
  Rake::Task["db:schema:dump"].enhance do
    path = Rails.root.join("db/structure.sql")
    next unless File.exist?(path)

    sql = File.read(path)
    stripped = sql.gsub(/ ?DEFINER=`[^`]*`@`[^`]*`/, "")
    File.write(path, stripped) unless stripped == sql
  end
end
