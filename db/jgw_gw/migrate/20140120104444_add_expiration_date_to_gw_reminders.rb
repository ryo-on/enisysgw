class AddExpirationDateToGwReminders < ActiveRecord::Migration
  def change
    add_column :gw_reminders, :expiration_datetime, :datetime
  end
end
