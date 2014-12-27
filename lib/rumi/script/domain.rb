class Rumi::Script::Domain
  BEFORE_DOMAIN = "enisysmail.city.enisys.co.jp"
  AFTER_DOMAIN  = "enisysmail.city.enisys.co.jp"
  def self.change(before = BEFORE_DOMAIN, after = AFTER_DOMAIN)
    Gw::EditLinkPiece.where(link_url: before)
                     .each {|ar| ar.update_column(:link_url, after) }
  end
end
