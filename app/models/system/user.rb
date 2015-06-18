# encoding: utf-8
require 'digest/sha1'
class System::User < ActiveRecord::Base
  include Cms::Model::Base::Content
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Base::Content

  belongs_to :status,     :foreign_key => :state,   :class_name => 'System::Base::Status'

  has_many   :group_rels, :foreign_key => :user_id,
    :class_name => 'System::UsersGroup'  , :primary_key => :id
  has_many :user_groups, :foreign_key => :user_id,
    :class_name => 'System::UsersGroup'
  has_many :groups, :through => :user_groups,
    :source => :group, :order => 'system_users_groups.job_order, system_groups.sort_no'
  has_many :user_group_histories, :foreign_key => :user_id,
    :class_name => 'System::UsersGroupHistory'

  has_many :logins, :foreign_key => :user_id, :class_name => 'System::LoginLog',
    :order => 'id desc', :dependent => :delete_all

  has_one :user_profile, :foreign_key => :user_id, :class_name => 'System::UsersProfile'
  has_one :user_profile_image, :foreign_key => :user_id, :class_name => 'System::UsersProfileImage'

  accepts_nested_attributes_for :user_groups, :allow_destroy => true,
    :reject_if => proc{|attrs| attrs['group_id'].blank?}

  # in_group_id is deprecated
  attr_accessor :in_password, :in_group_id, :encrypted_password,
    :old_password, :new_password, :new_password_confirmation

  validates_presence_of     :code, :name, :state, :ldap
  validates_uniqueness_of   :code

  validates :state, inclusion: { in: Proc.new{ |record| System::UsersGroup.state_values } }
  validates :ldap, inclusion: { in: Proc.new{ |record| System::UsersGroup.ldap_values } }
  # LDAPが非同期の場合はパスワードが必須となる
  validates :password, presence: true, if: Proc.new { |record| record.ldap == System::UsersGroup.ldap_values.first }

  # ログインパスワード設定画面専用
  #
  # 変更前のパスワードが正しいこと(変更前パスワードが入力されていることが前提)
  validate :old_password_valid, on: :update_user_password,
    if: Proc.new { |record| record.old_password.present? }
  # 変更後、確認用パスワードは同一であること(変更後、確認用パスワードが入力されていることが前提)
  validates :new_password, confirmation: { message: I18n.t("rumi.config_settings.user_passwords.action.edit.message.errors.confirmation") }, on: :update_user_password,
    if: Proc.new { |record| record.new_password.present? && record.new_password_confirmation.present? }
  # 変更後パスワードは半角英数字のみでかつ、数字と英字が混在していること(変更後パスワードが入力されていることが前提)
  validate :new_password_valid, on: :update_user_password,
    if: Proc.new { |record| record.new_password.present? }
  # 変更後パスワードは8文字以上であること(変更後パスワードが入力されていることが前提)
  validates :new_password, length: { minimum: 8 }, on: :update_user_password,
    if: Proc.new { |record| record.new_password.present? }
  # 変更前、変更後、確認用パスワードは入力必須であること
  validates :old_password, :new_password, :new_password_confirmation, presence: true, on: :update_user_password

  # メールアドレスが入力されていた場合は、フォーマットのチェックを行う
  validate :email_valid, if: Proc.new { |record| record.email.present? }
  # codeが入力されていた場合は、フォーマットのチェックを行う
  validate :code_valid, if: Proc.new { |record| record.code.present? }
  # 9桁まで整数のみ許可する
  validates :sort_no, numericality: { only_integer: true,
    greater_than_or_equal_to: -999999999,  less_than_or_equal_to: 999999999 }
  # 状態を無効にした場合は、有効状態のユーザー・グループが全て管理グループであること
  validate :state_valid, if: Proc.new { |record| record.disabled? }

  before_save :encrypt_password
  after_save :save_users_group, :disable_user_groups

  # === デフォルトのorder。
  #  ユーザーの表示順 > ユーザーコードの昇順
  #
  default_scope { order("system_users.sort_no", "system_users.code", "system_users.id") }

  # === 有効なユーザーのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable, where(state: "enabled")

  # === 無効なユーザーのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_enable, where(state: "disabled")

  # === 管理グループに設定された所属に属するユーザーのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * user_id: システムユーザー、もしくは運用管理者権限を持つユーザーID
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_editable_user_in_system_users, lambda { |user_id|
    # システムユーザー、もしくは運用管理者権限を持つユーザー
    operation_user = System::User.find(user_id)
    # 管理グループに設定された所属
    editable_group_ids = operation_user.editable_groups_in_system_users.map(&:id)
    # 管理グループに設定された所属に属するユーザーのみ抽出する
    includes(:user_groups).where("system_users_groups.group_id in (?) or system_users_groups.group_id is null", editable_group_ids)
  }

  # === 状態が有効の所属のみを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  def enable_user_groups
    return self.user_groups.without_disable
  end

  # === システム管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def system_admin?
    return System::Role.has_auth?(self.id, "_admin", "admin")
  end

  # === ユーザー・グループの運用管理者か評価する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def system_users_editor?
    return System::Role.has_auth?(self.id, "system_users", "editor")
  end

  # === ユーザーが対象に含まれている優先順位が一番高い運用管理者権限を返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  System::Role
  def system_users_editor_role
    return role("system_users", "editor")
  end

  # === ユーザーが対象に含まれている優先順位が一番高いSystem::Roleを返す
  #
  # ==== 引数
  #  * table_name: 機能コード
  #  * priv_name: 権限コード
  # ==== 戻り値
  #  System::Role
  def role(table_name, priv_name)
    group_ids = enable_user_groups.map(&:group_id)
    # 優先順位が同じ場合は先に作成された権限を優先する
    roles = System::Role.where(table_name: table_name, priv_name: priv_name).order(:idx, :id)
    roles.each do |role|
      # uidはstring型なのでto_iが必要である
      user_or_group_id = role.uid.to_i
      # 種別によって権限対象を分岐する
      case role.class_id
      # すべて
      when 0
        return role
      # ユーザー
      when 1
        # 対象のユーザーなら権限を返却する
        return role if user_or_group_id == id
      # グループ
      when 2
        # 対象のグループに所属しているなら権限を返却する
        return role if group_ids.include?(user_or_group_id)
      end
    end

    return nil
  end

  # === システム管理者の権限を持つユーザーを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Array.<System::User>
  def self.system_admin_users
    enable_users = System::User.without_disable.to_a

    return enable_users.select { |enable_user| enable_user.system_admin? }
  end

  # === ユーザーが対象に含まれている権限からeditable_groupsを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ActiveRecord::Relation
  def editable_groups_in_system_users
    # システムユーザーであれば全てのグループが編集可能
    return System::Group.unscoped.order_sort_no_and_code if system_admin?

    # 運用管理者であれば管理グループで設定されたグループが編集可能
    if system_users_editor?
      return System::Group.where("id in (?)", system_users_editor_role.editable_groups.map(&:group_id))
    else
      # 権限がなければ、空のActiveRecord::Relation
      return System::Group.none
    end
  end

  # === 渡されたtarget_groupsからeditable_groupsではないgroup_idを返却する
  #
  # ==== 引数
  #  * target_groups: ActiveRecord::Relation(System::Group)
  # ==== 戻り値
  #  Array
  def uneditable_group_ids_in_system_users(target_groups)
    return target_groups.map(&:id) - editable_groups_in_system_users.map(&:id)
  end

  # === 管理グループに設定された所属に属するユーザーか評価するメソッド
  #
  # ==== 引数
  #  * target_user_id: 管理グループに属するか評価させたいユーザーID
  # ==== 戻り値
  #  boolean
  def editable_user_in_system_users?(target_user_id)
    target_user = System::User.where(id: target_user_id).first
    return false if target_user.blank?

    # 管理グループに設定された所属に属するユーザーのみ表示する
    editable_group_ids = editable_groups_in_system_users.map(&:id)
    uneditable_group_ids = editable_group_ids - target_user.user_groups.map(&:group_id)
    # ユーザーが属する所属の内1つでも管理グループに含まれていれば編集可能と判断する
    return editable_group_ids != uneditable_group_ids || target_user.user_groups.count == 0
  end

  # === 管理グループに設定された所属に含まれるグループか評価するメソッド
  #
  # ==== 引数
  #  * target_group_id: 管理グループに属するか評価させたいグループID
  # ==== 戻り値
  #  boolean
  def editable_group_in_system_users?(target_group_id)
    target_group_id = target_group_id.to_i
    # 管理グループに設定された所属に属するユーザーのみ表示する
    return editable_groups_in_system_users.map(&:id).include?(target_group_id)
  end

  # === 該当グループ配下にグループが作成可能か評価するメソッド
  #  管理グループに設定された所属、かつ階層レベルが2以上のグループか判断する
  # ==== 引数
  #  * target_group_id: 管理グループに属するか評価させたいグループID
  # ==== 戻り値
  #  boolean
  def creatable_child_group_in_system_users?(target_group_id)
    target_group = System::Group.find(target_group_id)
    return target_group.level_no < 3 && editable_group_in_system_users?(target_group_id)
  end

  # === 該当グループが管理グループに設定された所属 + それらの親グループか評価するメソッド
  #
  # ==== 引数
  #  * target_group_id: 管理グループに設定された所属 + それらの親グループか評価させたいグループID
  # ==== 戻り値
  #  boolean
  def readable_group_in_system_users?(target_group_id)
    target_group = System::Group.find(target_group_id)
    return System::Group.extract_readable_group_in_system_users.map(&:id).include?(target_group_id)
  end

  # === ファイル管理の管理者権限（Doclibrary::Adm）取得メソッド
  #  ユーザーが対象に含まれるファイル管理の管理者権限を返すメソッドである。
  # ==== 引数
  #  * title_id: タイトルID（ファイル管理ID）
  # ==== 戻り値
  #  ファイル管理の管理者権限（Doclibrary::Adm）
  def doclibrary_admin_role(title_id)
    group_ids = groups.map(&:id)
    roles = Doclibrary::Adm.where(title_id: title_id)
    roles.each do |role|
      if role.group_id.present?
        # 対象のグループに所属している場合、管理者権限を返す
        return role if group_ids.include?(role.group_id)
      elsif role.user_id.present?
        # 対象のユーザーの場合、管理者権限を返す
        return role if role.user_id == self.id
      end
    end
    return nil
  end

  # === ファイル管理の権限（Doclibrary::Role）取得メソッド
  #  ユーザーが対象に含まれるファイル管理の権限を返すメソッドである。
  # ==== 引数
  #  * title_id: タイトルID（ファイル管理ID）
  #  * role_code: 権限コード（'w':編集権限 / 'r':閲覧権限）
  # ==== 戻り値
  #  ファイル管理の権限（Doclibrary::Role）
  def doclibrary_role(title_id, role_code)
    # 編集権限はDoclibrary::Roleで管理しなくなったため、nilを返す
    return nil if role_code == 'w'

    group_ids = groups.map(&:id)
    cond = ["user_id = ?", Site.user.id]
    user_groups = System::UsersGroup.without_disable.where(cond)
    parent_ids = Array.new
    user_groups.each do |ug|
      group = System::Group.without_disable.where(code: ug.group_code).first
      if group.parent_id != 1 && ug.id != 1
        parent = System::Group.without_disable.where(id: group.parent_id).first
        parent_ids << parent.id
      end
    end

    roles = Doclibrary::Role.where(title_id: title_id, role_code: role_code)
    roles.each do |role|
      if role.group_id.present?
        # グループIDが「0:制限なし」の場合、権限を返す
        return role if (role_code == 'r') && (role.group_id == 0)

        # 対象の子グループに所属している場合、権限を返す
        return role if parent_ids.include?(role.group_id)
        # 対象のグループに所属している場合、権限を返す
        return role if group_ids.include?(role.group_id)

      elsif role.user_id.present?
        # 対象のユーザーの場合、権限を返す
        return role if role.user_id == self.id
      end
    end
    return nil
  end

  # === ファイル管理の管理権限判定メソッド
  #  ファイル管理に対して管理権限のあるユーザーか判定するメソッドである。
  # ==== 引数
  #  * target_title_id: タイトルID（ファイル管理ID）
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def admin_in_doclibrarys?(target_title_id)
    # システム管理者か？
    return true if system_admin?

    # ファイル管理の管理者か？
    return true if System::Role.has_auth?(self.id, 'doclibrary', 'admin')
    return Doclibrary::Adm.has_auth?(target_title_id, self.id)
  end

  # === ファイル管理フォルダーの閲覧権限判定メソッド
  #  指定フォルダーに対して閲覧権限のあるユーザーか判定するメソッドである。
  # ==== 引数
  #  * target_folder_id: フォルダーID
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def readable_folder_in_doclibrarys?(target_folder_id)
    target_folder = Doclibrary::Folder.find(target_folder_id)
    return false if target_folder.blank?

    # フォルダーに対して閲覧権限のあるユーザーか？
    return target_folder.readable_user?(self.id)
  end

  # === LDAPで使用する識別名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  識別名
  def ldap_distinguished_name
    # LDAPの識別子は所属の状態を考慮せず、
    # 本務、兼務、仮所属で並び替えた最初のグループを識別子に使用する
    ou1 = self.user_groups.first.group
    ous = ([ou1, ou1.parent]).compact

    return ["uid=#{self.code}", (ous.map { |ou| "ou=#{ou.ou_name}" }).join(","), "#{Core.ldap.base}"].join(",")
  end

  # === 変更前のパスワードの検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def old_password_valid
    # LDAP非同期の場合
    if self.ldap == System::UsersGroup.ldap_values.first
      errors.add :old_password, :invalid unless self.password == self.old_password
    # LDAP同期の場合
    else
      # LDAPに接続出来ない場合もエラーとする
      dn = self.ldap_distinguished_name
      # LDAPを一旦切断する
      if Core.ldap.connection.bound?
        Core.ldap.connection.unbind
        Core.ldap = nil
      end

      errors.add :old_password, :invalid unless Core.ldap.bind(dn, self.old_password)
    end
  end

  # === 変更後のパスワードの検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def new_password_valid
    errors.add :new_password, :invalid unless has_alphanumeric?(self.new_password)
  end

  # === 半角英数字が混合しているか評価するメソッド
  #
  # ==== 引数
  #  * str: 評価する文字列
  # ==== 戻り値
  #  boolean
  def has_alphanumeric?(str)
    str = str.to_s
    return str =~ /[0-9]+/ && str =~ /[A-Za-z]+/ && str =~ /^[0-9A-Za-z]+$/
  end

  # === 変更後のパスワードを保存するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Error
  def update_new_user_password!
    # LDAP非同期の場合
    if self.ldap == System::UsersGroup.ldap_values.first
      # LDAP非同期ならpassword項目を更新する
      self.update_attributes!(password: self.new_password)
    # LDAP同期の場合
    else
      if Core.ldap.connection.bound?
        Core.ldap.connection.unbind
        Core.ldap = nil
      end

      # LDAP管理ユーザーで接続して、更新する
      if Core.ldap.root_bind
        Core.ldap.connection.modify(self.ldap_distinguished_name,
          [LDAP.mod(LDAP::LDAP_MOD_REPLACE, "userPassword", [self.new_password])])
      else
        errors.add :password, :ldap_invalid
        raise "LDAP::ResultError"
      end
    end
  rescue => e
    Rails.logger.error "[ERROR] update_new_user_password! Invalid Error"
    Rails.logger.error e.inspect
    Rails.logger.error self.inspect
    Rails.logger.error self.ldap_distinguished_name
    Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

    raise "Unexpected Error"
  ensure
    # LDAP同期の場合
    if self.ldap == System::UsersGroup.ldap_values.last
      if Core.ldap.connection && Core.ldap.connection.bound?
        Core.ldap.connection.unbind
        Core.ldap = nil
      end
    end
  end

  # === emailのフォーマット検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def email_valid
    errors.add :email unless Gw.is_simplicity_valid_email_address?(email)
  end

  # === codeのフォーマット検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def code_valid
    errors.add :code, I18n.t("rumi.system.user.code.message.invalid") unless System::User.valid_user_code_characters?(code)
  end

  # === 有効状態のユーザー・グループが全て管理グループか検証する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def state_valid
    errors.add :state, I18n.t("rumi.system.user.state.message.invalid") if has_uneditable_users_group?
  end

  # === 状態が有効なユーザー・グループが管理グループ以外のグループを含むか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def has_uneditable_users_group?
    uneditable_groups = Site.user.uneditable_group_ids_in_system_users(self.groups)
    return uneditable_groups.present?
  end

  def group_name
    user_groups.get_gname(id)
  end

  def show_group_name(error = Gw.user_groups_error)
    group = self.groups.collect{|x| ("#{x.code}") + %Q(#{x.name})}.join(' ')
    if group.blank?
      return error
    else
      return group
    end
  end

  def name_and_code
    name + '(' + code + ')'
  end

  def mobile_pass_check
    valid = true
    if self.mobile_password.size < 4
        self.errors.add :mobile_password, 'は４文字以上で入力してください。'
        valid = false
    end
    return valid
  end

  def self.m_access_select
    return [['不許可（標準）',0],['許可',1]]
  end

  def self.m_access_show(access)
    m_acc = [[0,'不許可（標準）'],[1,'許可']]
    show_str = m_acc.assoc(access.to_i)
    if show_str.blank?
      return nil
    else
      return show_str[1]
    end
  end

  def self.mobile_access_show(mobile)
    # CSV出力・登録用
    mobile_access = Gw.yaml_to_array_for_select 't1f0_kyoka_fuka'
    show = mobile_access.rassoc( nz(mobile, 0) )
    if show.blank?
      return ""
    else
      return show[0]
    end
  end

  def name_with_id
    "#{name}（#{id}）"
  end

  def name_with_account
    "#{name}（#{code}）"
  end

  def self.is_dev?(uid = Site.user.id)
    Gw.is_other_developer?('_admin')
  end

  def self.is_admin?(uid = Site.user.id)
    Gw.is_admin_admin?
  end

  def self.is_editor?(uid = Site.user.id)
    Gw.is_other_editor?('system_users')
  end

  def self.get_user_select(g_id=nil,all=nil, options = {})
    selects = []
    selects << ['すべて',0] if all=='all'
    if g_id.blank?
      u = Site.user
      g = u.groups[0]
      gid = g.id
    else
      gid = g_id
    end

    f_ldap = ''
    f_ldap = '1' if options[:ldap] == 1
    f_ldap = '' if Site.user.code.length <= 3
    f_ldap = '' if Site.user.code == 'gwbbs'
    conditions="state='enabled' and system_users_groups.group_id = #{gid}" if f_ldap.blank?
    conditions="state='enabled' and system_users_groups.group_id = #{gid} and system_users.ldap = 1" unless f_ldap.blank?
    order = "code"
    users_select = System::User.find(:all,:conditions=>conditions,:select=>"id,code,name",:order=>order,:joins=>'left join system_users_groups on system_users.id = system_users_groups.user_id')
    selects += users_select.map{|user| [ Gw.trim(user.display_name),user.id]}
    return selects
  end

  def self.get(uid=nil)
    uid = Site.user.id if uid.nil?
    self.find(:first, :conditions=>"id=#{uid}")
  end

  def display_name
    return "#{name} (#{code})"
  end

  def display_name_only
    return "#{name}"
  end

  # === ユーザー選択UIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [value, display_name]
  def to_select_option(value_method = :id)
    return [Gw.trim(self.name), self.send(value_method)]
  end

  # === 選択済みユーザーUIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [code, value, display_name]
  def to_json_option(value_method = :id)
    return [self.code, self.send(value_method), Gw.trim(self.name)]
  end

  def label(name)
    case name; when nil; end
  end


  def delete_group_relations
    System::UsersGroup.delete_all(:user_id => id)
    return true
  end

  def search(params)
    params.each do |n, v|
      next if v.to_s == ''

      case n
      when 's_keyword'
        search_keyword v, :code , :name , :name_en , :email
      end
    end if params.size != 0

    return self
  end

  def has_auth?(name)
    auth = {
      :none     => 0,
      :reader   => 1,
      :creator  => 2,
      :editor   => 3,
      :designer => 4,
      :manager  => 5,
      }

    return 5
  end

  def has_priv?(action, options = {})
    return true
    return true if has_auth?(:manager)
    return nil unless options[:item]

    item = options[:item]
    if item.kind_of?(ActiveRecord::Base)
      item = item.unid
    end

    cond  = "user_id = :user_id"
    cond += " AND role_id IN (" +
      " SELECT role_id FROM system_object_privileges" +
      " WHERE action = :action AND item_unid = :item_unid )"
    params = {
      :user_id   => id,
      :action    => action.to_s,
      :item_unid => item,
    }
    System::UsersRole.find(:first, :conditions => [cond, params])
  end

  def self.logger
    @@logger ||= RAILS_DEFAULT_LOGGER
  end

  ## Authenticates a user by their account name and unencrypted password.  Returns the user or nil.
  def self.authenticate(in_account, in_password, encrypted = false)
    in_password = Util::String::Crypt.decrypt(in_password) if encrypted

    user = nil
    self.new.enabled.find(:all, :conditions => {:code => in_account, :state => 'enabled'}).each do |u|
      if u.ldap == 1
        ## LDAP Auth
        if Core.ldap.connection.bound?
          Core.ldap.connection.unbind
          Core.ldap = nil
        end
        next unless Core.ldap.bind(u.ldap_distinguished_name, in_password)
        u.password = in_password
      else
        ## DB Auth
        next if in_password != u.password || u.password.to_s == ''
      end
      user = u
      break
    end
    return user
  end

  def self.encrypt(in_password, salt)
    in_password
  end

  def encrypt(in_password)
    in_password
  end

  def encrypt_password
    return if password.blank?
    Util::String::Crypt.encrypt(password)
  end

  def authenticated?(in_password)
    password == encrypt(in_password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  def remember_me
    self.remember_token_expires_at = 2.weeks.from_now.utc
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(:validate => false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    #save(:validate => false)
    update_attributes :remember_token_expires_at => nil, :remember_token => nil
  end

  def previous_login_date
    return @previous_login_date if @previous_login_date
    if (list = logins.find(:all, :limit => 2)).size != 2
      return nil
    end
    @previous_login_date = list[1].login_at
  end

  def self.truncate_table
    connect = self.connection()
    truncate_query = "TRUNCATE TABLE `system_users` ;"
    connect.execute(truncate_query)
  end


  #ユーザID（user code)で有効な文字か？
  def self.valid_user_code_characters?(string)
    return self.half_width_characters?(string)
  end

  def self.half_width_characters?(string)
    # 半角英数字、および半角アンダーバーのチェック
    if string =~  /^[0-9A-Za-z\_]+$/
      return true
    else
      false
    end
  end

  # === 現在のレコード状況を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  現在のレコード状況
  def inspect_associations_info
    msg = []
    msg << "[user_groups] #{self.user_groups.inspect}"
    msg << "[user_profile] #{self.user_profile.inspect}"

    return msg.join("\n")
  end

  # === ユーザーの所属グループID取得メソッド
  #  本メソッドは、ユーザーの所属グループIDを取得するメソッドである（親グループを含む）。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  ユーザーの所属グループID配列
  def user_group_parent_ids
    group_ids = []
    self.enable_user_groups.each do |user_group|
      group_ids += user_group.group.parent_tree.map(&:id)
    end
    return group_ids.uniq
  end

  # === スケジュール権限判定メソッド
  # スケジュール権限がログインユーザにあるか判定するメソッド
  def schedule_auth?
    unless defined?(@schedule_auth)
      if Core.user.id == self.id ||
          (role = System::ScheduleRole.where(target_uid: self.id)).blank?
        @schedule_auth = true
      else
          gids = Core.user.enable_user_groups.map(&:group_id)
          q1 = role.where(user_id: Core.user.id).where_values.reduce(:and)
          q2 = role.where(group_id: gids).where_values.reduce(:and)
          @schedule_auth = role.where(q1.or(q2)).present?
      end
    end
    @schedule_auth
  end

protected
  def password_required?
    password.blank? || !in_password.blank?
  end

  # deprecated
  def save_users_group
    return if in_group_id.blank?

    if ug = user_groups.find{|item| item.job_order == 0}
      if in_group_id != ug.group_id
        ug.group_id = in_group_id
        ug.start_at = Core.now
        ug.end_at = nil
        ug.save(:validate => false)
      end
    else
      System::UsersGroup.create(
        :user_id   => id,
        :group_id  => in_group_id,
        :start_at  => Core.now,
        :job_order => 0
      )
    end
  end

  # === ユーザーが無効状態になった時に、紐づく全ての所属情報に配属終了日を設定する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def disable_user_groups
    if self.disabled?
      if enable_user_groups.present?
        # 現在の日付を配属終了日として保存する
        disabled_at = Time.now
        enable_user_groups.each do |enable_user_group|
          enable_user_group.update_attribute(:end_at, disabled_at)
        end
      end
    end
  end
end
