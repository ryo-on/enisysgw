class Rumi::Script::Imap
  IMAP_CSV="tmp/rumi_imap.csv"

  def self.get_password
    CSV.open(IMAP_CSV, 'wb') do |csv|
      System::User.select([:code, :imap_password]).each do |u|
        csv << [u.code, u.imap_password]
      end
    end
  end

  def self.sync
    CSV.foreach(IMAP_CSV) do |row|
      if row[1]
        u = System::User.where(code: row[0]).first
        u.imap_password = row[1]
        u.save!(validate: false)
      end
    end
  end
end
