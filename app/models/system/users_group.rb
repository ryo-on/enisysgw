# encoding: utf-8
class System::UsersGroup < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Tree
  include System::Model::Base::Content
  self.primary_key = 'rid'

  # System::Group.affiliated_users_to_select_optionで使用するoptions
  TO_SELECT_OPTION_SETTINGS = {
    default: {
      without_level_no_2_organization: true,
      without_schedule_authority_user: false
    },
    system_role: {
      without_level_no_2_organization: false,
      without_schedule_authority_user: false
    },
    schedule: {
      without_level_no_2_organization: true,
      without_schedule_authority_user: true
    }
  }

  belongs_to   :user,  :foreign_key => :user_id,  :class_name => 'System::User'
  belongs_to   :group, :foreign_key => :group_id, :class_name => 'System::Group'

  attr_accessor :csv_import_mode

  validates_presence_of :group_id, :start_at
  validates_presence_of :user_id
  validates_uniqueness_of :group_id, :scope => :user_id,
    :message => "は既に登録されています。"

  # 状態が有効なユーザーを対象に本務が重複していないか検証する
  validate :job_order_valid, if: Proc.new{ |record|
    record.user.present? && record.user.enabled? && record.job_order == System::UsersGroup.job_order_key_role }
  # 管理グループに含まれている、かつ有効なグループか検証する
  validates :group_id, inclusion: { in: Proc.new{ |record| Site.user.editable_groups_in_system_users.without_disable.map(&:id) },
    if: Proc.new{ |record| record.group_id.present? } }
  # 本務・兼務の必須、リスト検証
  validates :job_order, inclusion: { in: Proc.new{ |record| System::UsersGroup.job_order_values },
    if: Proc.new{ |record| record.group.present? && !record.group.any_group? } }
  # ユーザーの状態が無効の場合は必須とする
  validates :end_at, presence: true, if: Proc.new{ |record| record.user && record.user.disabled? }
  # ユーザーの所属情報が存在し、かつCSV本登録ではない場合、管理グループ配下のユーザー、かつ有効なユーザーか検証する
  validate :user_id_valid, if: Proc.new{ |record| record.user && record.user.user_groups.present? && csv_import_mode.blank? }

  validates_each :end_at do |record, attr, value|
    user = System::User.find_by_id(record.user_id)
    if value.present?
      record.errors.add attr, 'は、ユーザーの状態が「有効」の場合、空欄としてください。' if user.present? && user.state == "enabled"
      record.errors.add attr, 'には、配属開始日より後の日付を入力してください。' if record.start_at.present? && Time.local(value.year, value.month, value.day, 0, 0, 0) < Time.local(record.start_at.year, record.start_at.month, record.start_at.day, 0, 0, 0)
      record.errors.add attr, 'には、本日以前の日付を入力してください。'  if Time.local(value.year, value.month, value.day, 0, 0, 0) > Time.local(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)
    end
  end

  validates_each :start_at do |record, attr, value|
    if value.present?
      record.errors.add attr, 'には、本日以前の日付を入力してください。'  if Time.local(value.year, value.month, value.day, 0, 0, 0) > Time.local(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)
    end
  end

  before_save :set_columns, :clear_cache
  before_destroy :clear_cache
  after_save :save_users_group_history
  after_destroy :close_users_group_history
  before_validation :clear_job_order

  # === デフォルトのorder。
  #  本務・兼務(0: 本務、1:兼務、2: 仮所属、3: null)
  default_scope {
    order("system_users_groups.job_order is null",
      "system_users_groups.job_order")
  }

  # === ユーザーのデフォルトスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :order_user_default_scope, lambda {
    includes(:user).order("system_users.sort_no", "system_users.code", "system_users.id")
  }

  # === 有効な所属情報のみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable, lambda {
    current_time = Time.now
    where("system_users_groups.end_at is null or system_users_groups.end_at = '0000-00-00 00:00:00' or system_users_groups.end_at > '#{current_time.strftime("%Y-%m-%d 23:59:59")}'")
  }

  # === 階層レベル2でかつ、組織グループを抽出から外すスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_level_no_2_organization, lambda {
    includes(:group).where("(system_groups.level_no = 3 and system_groups.category = 0) or (system_groups.level_no > 1 and system_groups.category = 1)")
  }

  # === 権限付与されていないユーザーを抽出から外すスコープ
  #
  # ==== 引数
  #  * target_uid: ログインユーザーが権限を持たない権限対象者
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_schedule_authority_user, lambda { |target_uid|
    cond = "system_users_groups.user_id not in ( #{target_uid})"
    where(cond)
  }

  # === スケジュール権限付与ユーザーを調べる際使用するログインユーザーの所属を抽出するスコープ
  #
  # ==== 引数
  #  * user_id: ログインユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :schedule_role_user_group, lambda { |user_id|
    select("system_users_groups.group_id")
    .where(user_id: user_id)
  }

  # === 所属選択UIにて表示するユーザーの抽出を行うメソッド
  #
  # ==== 引数
  #  * target_group_id: 抽出対象のグループID
  #  * options: Hash
  #      e.g. without_level_no_2_organization: boolean
  #      e.g. without_schedule_authority_user: boolean
  # ==== 戻り値
  #  Array.<user>
  def self.affiliated_users_to_select_option(target_group_id, options = System::UsersGroup::TO_SELECT_OPTION_SETTINGS[:default], login_user_id = nil)
    to_without_level_no_2_organization = options.key?(:without_level_no_2_organization) && options[:without_level_no_2_organization] == true
    to_without_schedule_authority_user = options.key?(:without_schedule_authority_user) && options[:without_schedule_authority_user] == true

    user_groups = System::UsersGroup.unscoped.where(group_id: target_group_id)
    user_groups = user_groups.without_level_no_2_organization if to_without_level_no_2_organization
    if to_without_schedule_authority_user
      t_uid = System::ScheduleRole.get_target_uids(login_user_id)
      t_uid.each do |t|
        user_groups = user_groups.without_schedule_authority_user(t.target_uid)
      end
    end
    user_groups = user_groups.without_disable.order_user_default_scope

    return user_groups.map { |user_group| user_group.user }
  end

  def clear_cache
    Rails.cache.clear
  end

  # === ユーザーに対して有効なユーザー・グループが1つしかない場合は削除できない
  #  override前: Rails.root/lib/system/model/base/content.rb Line:42
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def deletable?
    current_time = Time.now.strftime("%Y-%m-%d 23:59:59")
    item_state = self.end_at.present? && (self.end_at != '0000-00-00 00:00:00' && self.end_at < current_time)
    return self.user.enable_user_groups.count >= 2 || item_state
  end

  # === グループが任意の場合は本務・兼務をnilにする
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def clear_job_order
    self.job_order = nil if self.group.present? && self.group.any_group?
  end

  # === 管理グループ配下のユーザー、かつ有効なユーザーか検証する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def user_id_valid
    is_editable_user = Site.user.editable_user_in_system_users?(user_id)

    errors.add(:user_id, :inclusion) unless is_editable_user && user.enabled?
  end

  # === 状態が有効なユーザーを対象に本務が重複していないか検証する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def job_order_valid
    # 本務・兼務が本務かつ自分自身ではない有効状態のユーザー・グループ
    self_record_id = self.id
    job_order_key_role_user_group = self.user.enable_user_groups.select do |enable_user_group|
      enable_user_group.job_order == System::UsersGroup.job_order_key_role && enable_user_group.id != self_record_id
    end

    errors.add :job_order, I18n.t("rumi.system.user.job_order_0.message.unique") unless job_order_key_role_user_group.count.zero?
  end

  def set_columns
    if self.user_id.to_i==0
        self.user_code  = '未登録ユーザー'
    else
      if self.user.blank?
        self.user_code  = '未登録ユーザー'
      else
        self.user_code  = self.user.code
      end
    end
    if self.group_id.to_i==0
        self.group_code  = '未登録グループ'
    else
      if self.group.blank?
        self.group_code  = '未登録グループ'
      else
        self.group_code  = self.group.code
      end
    end
  end

  def self.job_order_show(job_order)
    return "" if job_order.blank?
    job_orders = Gw.yaml_to_array_for_select 'system_ugs_job_orders'
    job_order_str = job_orders.rassoc(job_order.to_i)
    if job_order_str.blank?
      return ""
    else
      return job_order_str[0]
    end
  end

  # === 本務・兼務で使用されている表示名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.job_order_names
    return Gw.yaml_to_array_for_select("system_ugs_job_orders").map { |factor| factor.first }
  end

  # === 本務・兼務で使用されている値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.job_order_values
    return Gw.yaml_to_array_for_select("system_ugs_job_orders").map { |factor| factor.last }
  end

  # === 本務の値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  0
  def self.job_order_key_role
    return System::UsersGroup.job_order_values.first
  end

  def self.ldap_show(ldap)
    ldaps = Gw.yaml_to_array_for_select 'system_users_ldaps'
    ldap_str = ldaps.rassoc(ldap.to_i)
    if ldap_str.blank?
      return ""
    else
      return ldap_str[0]
    end
  end

  # === LDAP同期で使用されている表示名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.ldap_names
    return Gw.yaml_to_array_for_select("system_users_ldaps").map { |factor| factor.first }
  end

  # === LDAP同期で使用されている値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.ldap_values
    return Gw.yaml_to_array_for_select("system_users_ldaps").map { |factor| factor.last }
  end

  def self.state_show(state)
    states = Gw.yaml_to_array_for_select 'system_states'
    state_str = states.rassoc(state)
    if state_str.blank?
      return ""
    else
      return state_str[0]
    end
  end

  # === 状態で使用されている表示名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.state_names
    return Gw.yaml_to_array_for_select("system_states").map { |factor| factor.first }
  end

  # === 状態で使用されている値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.state_values
    return Gw.yaml_to_array_for_select("system_states").map { |factor| factor.last }
  end

  def show_group_name(error = Gw.user_groups_error)
    group = self.group
    if group.blank?
      error
    else
      group.ou_name
    end
  end

  def self.get_gname(uid=nil)
    uid = Site.user.id if uid.nil?
    user_group1 = System::UsersGroup.find(:first, :conditions=>"user_id=#{uid}",:order=>"job_order")
    return nil if user_group1.blank?
    group       = user_group1.group unless user_group1.blank?
    name = group.ou_name unless group.blank?
    name = nil if group.blank?
    return name
  end

  def search(params)
    params.each do |n, v|
      next if v.to_s == ''

      case n
        when 's_keyword'
        search_keyword v, :job_order
        when 'job'
        search_id v, :job_order
      end
    end if params.size != 0

    return self
  end

  def self.truncate_table
    connect = self.connection()
    truncate_query = "TRUNCATE TABLE `system_users_groups` ;"
    connect.execute(truncate_query)
  end

  # === レコード情報をCSVに保存するためのメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def to_csv
    # [
    #   "状態", "種別",
    #   "","所属グループの親グループID", "所属グループID", "ID", "",
    #   "LDAP同期", "本務・兼務",
    #   "名前", "名前（英）", "パスワード", "メールアドレス", "並び順", "役職", "担当",
    #   "開始日", "終了日",
    #   "追加項目1", "追加項目2", "追加項目3", "追加 項目4", "追加項目5"
    # ]

    csv = [
      System::UsersGroup.state_show(user.state), System::UsersGroupsCsvdata.user_data_type,
      "", group.parent.code, group.code, user.code, "",
      System::UsersGroup.ldap_show(user.ldap), System::UsersGroup.job_order_show(job_order),
      user.name, user.name_en, user.password, user.email, user.sort_no, user.official_position, user.assigned_job,
      Gw.date_str(start_at), Gw.date_str(end_at)
    ]

    user_profile = user.user_profile
    if user_profile.present?
      csv << user_profile.add_column1
      csv << user_profile.add_column2
      csv << user_profile.add_column3
      csv << user_profile.add_column4
      csv << user_profile.add_column5
    end

    return csv
  end

  # === 現在のレコード状況を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  現在のレコード状況
  def inspect_associations_info
    msg = []
    msg << "[user] #{self.user.inspect}"
    msg << "[group] #{self.group.inspect}"

    return msg.join("\n")
  end

private
  
  def save_users_group_history
    if group_id_changed?
      latest_ugh = user.user_group_histories.find(:first, :conditions => {:group_id => group_id_was}, :order => 'rid DESC')
      if latest_ugh
        latest_ugh.end_at = Core.now
        latest_ugh.save(:validate => false)
      end
      ugh = System::UsersGroupHistory.new(self.attributes.delete_if{|k,v| k == 'rid'})
      ugh.start_at = Core.now
      ugh.end_at = nil
      ugh.save(:validate => false)
    else
      latest_ugh = user.user_group_histories.find(:first, :conditions => {:group_id => group_id}, :order => 'rid DESC')
      if latest_ugh
        latest_ugh.attributes = self.attributes.delete_if{|k,v| k == 'rid'}
        latest_ugh.save(:validate => false)
      end
    end
  end
  
  def close_users_group_history
    latest_ugh = user.user_group_histories.find(:first, :conditions => {:group_id => group_id}, :order => 'rid DESC')
    if latest_ugh
      latest_ugh.end_at = Core.now
      latest_ugh.save(:validate => false)
    end
  end
end
