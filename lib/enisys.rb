# encoding: utf-8
module Enisys
  def self.version
    "2.1.1"
  end

  def self.default_config
    { "application" => {
        "sys.login_footer"                       => "",
        "sys.mobile_footer"                      => "",
        "sys.session_expiration"                 => 24,
        "sys.session_expiration_for_mobile"      => 1,
        "sys.force_site"                         => "",
        "sys.ldap_server_type"                   => "OpenLDAP",
        "webmail.root_url" => nil
    }}
  end

  def self.config
    $enisys_config ||= {}
    Enisys::Config
  end

  def self.server_name
    unless class_variable_defined?(:@@server_name)
      file = File.join(Rails.root, 'config', 'servers.yml')
      begin
        raise unless File.exist?(file)
        servers = YAML.load_file(file)
        ip = Socket.getifaddrs.select {|ifaddr|
          ifaddr.name == servers[:device] && ifaddr.addr.ipv4?
        }.first.addr.ip_address
        @@server_name = servers[:servers][ip]
      rescue
        @@server_name = nil
      end
    end
    @@server_name
  end

  class Enisys::Config
    def self.application
      config = Enisys.default_config["application"]
      file   = "#{Rails.root}/config/application.yml"
      if ::File.exist?(file)
        yml = YAML.load_file(file)
        yml.each do |mod, values|
          values.each do |key, value|
            unless value.nil?
              if mod == "webmail" && key == "root_url"
                begin
                  URI.parse(value)
                rescue
                  # 何もしない
                else
                  config["webmail.root_url"] = value
                end
              else
                config["#{mod}.#{key}"] = value
              end
            end
          end if values
        end if yml
      end
      $enisys_config[:application] = config
    end

    def self.imap_settings
      $enisys_config[:imap_settings]
    end

    def self.imap_settings=(config)
      $enisys_config[:imap_settings] = config
    end

    def self.sso_settings
      $enisys_config[:sso_settings]
    end

    def self.sso_settings=(config)
      $enisys_config[:sso_settings] = config
    end
  end
end
