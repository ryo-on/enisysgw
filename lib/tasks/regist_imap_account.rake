# -*- encoding: utf-8 -*-
require 'net/ssh'
require 'net/telnet'
require 'io/console'
require 'pty'
require 'expect'

namespace :rumi do
  # IMAPメンテナンス用
  namespace :imap do
    # 定数定義
    MAIL_DOMAIN = '@city.enisys.co.jp'
    SCP_TIMEOUT = 30

    # アカウント同期用タスク
    #
    # [機能]
    # ・グループウェアのアカウントでemailを持っているユーザのうち
    #   IMAPアカウント登録されていないユーザを対象とする。
    # ・対象のユーザが存在した場合はプライマリのIMAPサーバにアカウントを生成する。
    # ・セカンダリのIMAPサーバに関しては一連の処理を完了後に
    #   /etc/passwd, /etc/shadow をコピーすることにより同期を図る。
    task sync_account: :environment do
      name1 = input_server('IMAPサーバ(プライマリ)')
      pass1 = input_password
      rumi_imap_execute(name1, pass1) do |ssh|
        name2 = input_server('IMAPサーバ(セカンダリ)')
        pass2 = input_password
        if rumi_imap_execute(name2, pass2)
          apps = app_users
          imaps = imap_users(ssh)

          # プライマリにアカウントを生成
          (apps - imaps).each do |u|
            puts
            input_yes("#{u}さんをIMAPアカウント登録します。") do
              create_account(ssh, u)
              puts "#{u}さんを登録しました。"
            end
          end
          
          puts

          # プライマリからセカンダリにアカウント同期
          file_list = ['passwd', 'shadow', 'group']
          input_yes('プライマリサーバのアカウントをセカンダリサーバに同期します。') do
            PTY.spawn("scp root@#{name1}:/etc/{#{file_list.join(',')}} root@#{name2}:/etc/") do |r, w|
              w.sync = true
              pass_expect = ->(name, pass) {
                r.expect(/#{name}.*[Pp]assword/, SCP_TIMEOUT) { w.puts pass }
              }
              file_list.each do |_|
                pass_expect.(name1, pass1)
                pass_expect.(name2, pass2)
                r.expect(/closed/, SCP_TIMEOUT)
              end
            end
            puts "同期が完了しました。"
          end
        end
      end
    end

    def create_account(ssh, user)
      msg = ssh.exec!("useradd -s /sbin/nologin #{user}")
      raise msg if msg
      pass = create_password
      msg = ssh.exec!("yes #{pass} | passwd #{user}")
      if ar = System::User.where(email: "#{user}#{MAIL_DOMAIN}").first
        ar.update_column(:imap_password, pass)
      else
        raise
      end
    end

    def input_yes(message, &block)
      puts message
      print 'よろしければ y を入力して下さい: '
      if STDIN.gets.chop == 'y'
        yield
      else
        puts 'キャンセルしました。'
      end
    end

    def input_server(server_name = 'IMAPサーバ')
      print "#{server_name}名又はIPアドレスを入力してください: "
      STDIN.gets.chop
    end

    def input_password
      print 'サーバのrootパスワードを入力してください: '
      pass = STDIN.noecho(&:gets).chop
      puts ''
      return pass
    end

    def app_users
      tbl = System::User
      atbl = tbl.arel_table
      tbl.select([:email]).where(atbl[:email].matches("%#{MAIL_DOMAIN}"))
         .inject([]) {|buf, u| buf << u.email.split('@')[0] if u.email.present? }
    end

    def imap_users(ssh)
      ssh.exec!('cat /etc/passwd').split("\n").map {|u| u.split(':')[0] }
    end

    def create_password(length = 8)
      [*'0'..'9', *'a'..'z', *'A'..'Z'].sample(length).join
    end

    def imap_server?(ssh)
      ssh.exec!('lsof -i:143 | grep dovecot') ? true : false
    end

    # 共通処理用メソッド
    def rumi_imap_execute(server = input_server,
                          pass = input_password, &block)
      Net::SSH.start(server, 'root', password: pass) do |ssh|
        raise 'no_imap' unless imap_server?(ssh)
        yield(ssh) if block_given?
      end
      return true
    rescue Net::SSH::AuthenticationFailed
      puts 'ERROR: パスワードが違います。'
      return false
    rescue SocketError => e
      case e.message
      when /Name or service not known/
        puts 'ERROR: サーバ名に誤りがあります。'
      else
        puts "ERROR: #{e.message}"
      end
      return false
    rescue RuntimeError => e
      case e.message
      when 'no_imap'
        puts 'ERROR: IMAPサーバではありません。'
      else
        raise e
        puts "ERROR: #{e.message}"
      end
      return false
    rescue => e
      raise e
      puts "ERROR: #{e.message}"
      return false
    end
  end
end
