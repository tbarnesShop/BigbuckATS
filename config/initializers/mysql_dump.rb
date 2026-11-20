# Cloud/local app users need no global PROCESS grant just to dump the schema.
ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = [ "--no-tablespaces" ]
