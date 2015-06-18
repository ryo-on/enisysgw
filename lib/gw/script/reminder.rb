class Gw::Script::Reminder
  class << self
    def clear(opt = {seen: true, old: nil})
      log_write("Reminder.clear start")
      if opt[:seen]
        reminders = Gw::Reminder.unscoped.where(
                       Gw::Reminder.arel_table[:seen_at].not_eq(nil))
        delcnt = reminders.destroy_all.size
        log_write("#{delcnt} seen reminders deleted.")
      end
      if opt[:old]
        reminders =
          Gw::Reminder.unscoped.where(
            Gw::Reminder.arel_table[:updated_at].lt(eval(opt[:old]).ago))
        delcnt = reminders.destroy_all.size
        log_write("#{delcnt} old reminders deleted.")
      end
      log_write("Reminder.clear end")
    end

  private
    def log_write(str)
      puts(str)
      dump(str)
    end
  end
end
