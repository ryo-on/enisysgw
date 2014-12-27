class Gw::Script::Reminder
  class << self
    def clear
      log_write("Reminder.clear start")
      reminders = Gw::Reminder.unscoped.where(
                     Gw::Reminder.arel_table[:seen_at].not_eq(nil))
      delcnt = reminders.destroy_all.size
      log_write("#{delcnt} reminders deleted.")
      log_write("Reminder.clear end")
    end

  private
    def log_write(str)
      puts(str)
      dump(str)
    end
  end
end
