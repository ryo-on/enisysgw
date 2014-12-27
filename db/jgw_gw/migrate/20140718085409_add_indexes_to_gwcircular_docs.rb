class AddIndexesToGwcircularDocs < ActiveRecord::Migration
  def up
    execute "CREATE INDEX `index_for_monthly_search` ON `gwcircular_docs` (`title_id`, `doc_type`, `target_user_code`, `state`(20), `created_at`, `able_date`)"
    execute "CREATE INDEX `index_for_createrdivision_search` ON `gwcircular_docs` (`title_id`, `doc_type`, `target_user_code`, `state`(20), `able_date`, `createrdivision_id`)"
  end

  def down
    execute "DROP INDEX `index_for_monthly_search` ON `gwcircular_docs`"
    execute "DROP INDEX `index_for_createrdivision_search` ON `gwcircular_docs`"
  end
end
