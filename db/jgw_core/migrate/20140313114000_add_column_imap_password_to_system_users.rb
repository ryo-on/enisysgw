class AddColumnImapPasswordToSystemUsers < ActiveRecord::Migration
  def change
    add_column :system_users, :imap_password, :string
  end
end
