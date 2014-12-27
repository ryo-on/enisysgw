# encoding: utf-8
class Sys::Lib::Ldap
  attr_accessor :connection
  attr_accessor :host
  attr_accessor :port
  attr_accessor :base
  attr_accessor :rootdn, :rootpw

  ## Initializer.
  def initialize(params = nil)
    unless params
      conf = Util::Config.load(:ldap)
      params = {
        :host => conf['host'],
        :port => conf['port'],
        :base => conf['base'],
        :rootdn => conf['rootdn'],
        :rootpw => conf['rootpw']
      }
    end
    self.host = params[:host]
    self.port = params[:port]
    self.base = params[:base]
    self.rootdn = params[:rootdn]
    self.rootpw = params[:rootpw]

    return nil if host.blank? || port.blank? || base.blank?

    self.connection = self.class.connect(params)
  end

  ## Connect.
  def self.connect(params)
    begin
      require 'ldap'
      timeout(2) do
        conn = LDAP::Conn.new(params[:host], params[:port])
        conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
        return conn
      end
    rescue Timeout::Error => e
      raise "LDAP: 接続に失敗 (#{e})"
    rescue Exception => e
      raise "LDAP: エラー (#{e})"
    end
  end

  ## Bind.
  def bind(dn, pass)
    if(RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/)
      require 'nkf'
      dn = NKF.nkf('-s -W', dn)
    end

    # ActiveDirectory
    if Enisys::Config.application['sys.ldap_server_type'] == 'ActiveDirectory'
      return nil if pass.blank?
      dn = "#{dn.match(/^uid=(.*?),/)[1]}@#{self.base}"
    end

    return connection.bind(dn, pass)
  rescue LDAP::ResultError
    return nil
  end

  # === 管理者権限でLDAPに接続するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  LDAP::Conn / nil
  def root_bind
    if self.rootdn.present? && self.rootpw.present?
      return self.bind(self.rootdn, self.rootpw)
    else
      return nil
    end
  end

  ## Group.
  def group
    Sys::Lib::Ldap::Group.new(self)
  end

  ## User
  def user
    Sys::Lib::Ldap::User.new(self)
  end

  ## Search.
  def search(filter, options = {})
    filter = "(#{filter.join(')(')})" if filter.class == Array
    filter = "(&#{filter})"

    cname = options[:class] || Sys::Lib::Ldap::Entry
    scope = options[:scope] || LDAP::LDAP_SCOPE_SUBTREE || LDAP::LDAP_SCOPE_ONELEVEL
    base  = options[:base]  || self.base
    entries = []
    connection.search2(base, scope, filter) do |entry|
      entries << cname.new(self, entry)
    end

    return entries
  rescue
    return []
  end
end
