# coding: utf-8

class System::AccessLog < ActiveRecord::Base
  attr_accessible :user_id, :user_code, :user_name, :ipaddress,
    :controller_name, :action_name, :parameters, :feature_id, :feature_name

  default_scope order(:created_at)

  scope :extract_start_date, lambda {|start_date|
    where('created_at >= ?', start_date)
  }

  scope :extract_end_date, lambda {|end_date|
    where('created_at <= ?', end_date)
    .order('created_at desc')
  }

  scope :extract_date, lambda {|start_date, end_date|
    where('created_at >= ? and created_at <= ?', start_date, end_date)
    .order('created_at')
  }

  scope :extract_csv_date, lambda {|start_date, end_date,data_cnt|
    where('created_at >= ? and created_at <= ?', start_date, end_date)
    .order('created_at')
    .limit(data_cnt)
  }

  before_create :before_create_record

  FEATURE_NAMES = {
    account: {
      login: 'ログイン',
      logout: 'ログアウト'
    }
  }

  def logging?
    to_feature_id.present?
  end

  def to_feature_id
    f_id = nil
    log_url = []

    params_controller = parameters[:controller]
    params_url = parameters[:url]
    params_action = parameters[:action]

    #リンクピースから固定ヘッダー部のurl及び機能名を取得
    header_urls = Gw::EditLinkPiece.find(
                    :all, :select => "link_url,name",
                    :conditions => ["state = ? and level_no = ? and parent_id = ? and name != ?", "enabled","3","61","メール"],
                    :order => "sort_no")

    header_urls.each do |h_url|
      #アクセスログ用の機能名に対するID及び機能名の保存
      #id = h_url.link_url.split('/')
      id = h_url.link_url.split('?')
      FEATURE_NAMES[id[0].to_sym] = h_url.name
    end

    #ログインもしくはログアウト
    if params_controller.include?('account')
      login_key = 'login'
      logout_key = 'logout'

      f_id = login_key if params_action.include?(login_key) &&
                          (parameters[:account].present?)
      f_id = logout_key if params_action.include?(logout_key)

    #その他
    else
      params_url = '/' if params_url == '/gw/portal' #ログアウトしログインし直した場合のURL変化対応
      FEATURE_NAMES.keys.each do |key|
        f_id = key if params_url == key.to_s
        if params_url == '/gw/piece/schedules' #トップページのスケジュール表示対応
          f_id = key if key.to_s.include?('schedules')
        end
      end

      f_id = nil unless params_action == 'index' || params_action == 'show_week'
      #トップページのスケジュール表示非表示対応
      if parameters[:url] == '/gw/piece/schedules'
        schedule_settings = Gw::Model::Schedule.get_settings 'schedules', {}
        f_id = nil if nz(schedule_settings[:view_portal_schedule_display], 1).to_i == 0
      end
    end

    #タブで切り替える部分のパラメータ判断によるログ取得却下
    f_id = nil if parameters[:cond].present?  #parameters[:cond]は回覧板のタブ切り替えで使用
    f_id = nil if parameters[:cgid].present?  #parameters[:cgid]はスケジュールのグループ週表示で使用
    f_id = nil if parameters[:c1].present?  #parameters[:c1]は設定の管理者設定のタブ切り替えで使用
    return f_id.to_s
  end

  def to_feature_name
    return FEATURE_NAMES[:account][:login] if feature_id == 'login'
    return FEATURE_NAMES[:account][:logout] if feature_id == 'logout'
    return FEATURE_NAMES[feature_id.to_sym]
  end

  def before_create_record
    set_feature_info
    set_login_user_info
    set_str_parameters
  end

  def set_feature_info
    self.feature_id = to_feature_id
    self.feature_name = to_feature_name
  end

  def set_login_user_info

    if feature_id == 'login'
      user_code = parameters[:account]
      @user = System::User.find_by_code(user_code) if user_code.present?
      user = System::User.authenticate(parameters[:account], parameters[:password])

      self.user_code = user_code
      self.user_id = @user.try(:id)

      self.user_name = @user.try(:name) if user
      self.user_name = '' unless user
    end
  end

  def set_str_parameters
    self.parameters = parameters.inspect
  end

end
