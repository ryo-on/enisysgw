# encoding: utf-8
require 'date'
class System::Group < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Tree
  include System::Model::Base::Content

  LEVEL_NO_VALUES = [1, 2, 3]

  # System::Group.child_groups_to_select_optionで使用するoptions
  TO_SELECT_OPTION_SETTINGS = {
    default: {
      without_disable: true,
      unshift_parent_group: true
    }
  }

  belongs_to :status,     :foreign_key => :state,     :class_name => 'System::Base::Status'
  belongs_to :parent,     :foreign_key => :parent_id, :class_name => 'System::Group'
  has_many :children ,  :foreign_key => :parent_id, :class_name => 'System::Group'
  has_many :enabled_children  , :foreign_key => :parent_id, :class_name => 'System::Group',
    :conditions => {:state => 'enabled'}, :order => :sort_no
  has_many :user_group, :foreign_key => :group_id,  :class_name => 'System::UsersGroup'
  has_and_belongs_to_many :users, :class_name => 'System::User',
    :join_table => 'system_users_groups'

  validates_presence_of :state, :code, :name, :start_at, :category
  validates_uniqueness_of :code, :scope => [:parent_id]

  validates :state, inclusion: { in: Proc.new{ |record| System::UsersGroup.state_values } }
  validates :ldap, inclusion: { in: Proc.new{ |record| System::UsersGroup.ldap_values } }
  validates :category, inclusion: { in: Proc.new{ |record| System::Group.category_values } }
  validates :level_no, inclusion: { in: System::Group::LEVEL_NO_VALUES }
  # 状態が無効の場合は必須とする
  validates :end_at, presence: true, if: Proc.new{ |record| record.disabled? }
  # メールアドレスが入力されていた場合は、フォーマットのチェックを行う
  validate :email_valid, if: Proc.new { |record| record.email.present? }
  # codeが入力されていた場合は、フォーマットのチェックを行う
  validate :code_valid, if: Proc.new { |record| record.code.present? }
  # 9桁まで整数のみ許可する
  validates :sort_no, numericality: { only_integer: true,
    greater_than_or_equal_to: -999999999,  less_than_or_equal_to: 999999999 }
  # 親グループは管理グループに設定された所属または管理グループの親グループ、かつ階層レベルが1、2のグループのみ許可する
  validate :parent_id_valid, if: Proc.new { |record| record.parent_id.present? }
  # 状態が無効の場合は、子グループが無効かつ、自身に対するユーザー・グループが存在しない時のみ許可する
  validate :state_valid, if: Proc.new { |record| record.disabled? }

  validates_each :state do |record, attr, value|
    if value.present?
      record.errors.add attr, 'は、上位所属が「無効」のため、「有効」にできません。' if !record.parent.blank? && record.parent.state == "disabled" && record.state == "enabled"
    end
  end

  validates_each :end_at do |record, attr, value|
    if value.present?
      record.errors.add attr, 'は、状態が「有効」の場合、空欄としてください。' if record.state == "enabled"
      record.errors.add attr, 'には、適用開始日より後の日付を入力してください。' if Time.local(value.year, value.month, value.day, 0, 0, 0) < Time.local(record.start_at.year, record.start_at.month, record.start_at.day, 0, 0, 0)
      record.errors.add attr, 'には、本日以前の日付を入力してください。'  if Time.local(value.year, value.month, value.day, 0, 0, 0) > Time.local(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)
    end
  end

  validates_each :start_at do |record, attr, value|
    if value.present?
      record.errors.add attr, 'には、本日以前の日付を入力してください。'  if Time.local(value.year, value.month, value.day, 0, 0, 0) > Time.local(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)
    end
  end

  after_save :save_group_history, :clear_cache
  before_destroy :clear_cache

  # === デフォルトのorder。
  #  グループの表示順 > グループコード昇順
  default_scope { order_sort_no_and_code }

  # === 並び替えのスコープ
  #  グループの表示順 > グループコード昇順
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :order_sort_no_and_code, order("system_groups.sort_no", "system_groups.code", "system_groups.id")

  # === 空のActiveRecord::Relationを返すスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ActiveRecord::Relation
  scope :none, limit(0)

  # === 有効なグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable, lambda {
    current_time = Time.now
    where(state: "enabled").where("start_at <= '#{current_time.strftime("%Y-%m-%d 00:00:00")}'").where(
      "end_at is null or end_at = '0000-00-00 00:00:00' or end_at > '#{current_time.strftime("%Y-%m-%d 23:59:59")}'")
  }

  # === 無効なユーザーのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_enable, where(state: "disabled")

  # === 階層レベル2, 3のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_root, where("level_no > 1")

  # === 階層レベル1, 2のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_level_no_3, where("level_no < 3")

  # === 階層レベル1のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_root, where(level_no: 1)

  # === 階層レベル2のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_level_no_2, where(level_no: 2)


  # === 階層レベル3のグループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_level_no_3, where(level_no: 3)

  # === 管理グループに設定された所属のみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_editable_group_in_system_users, lambda {
    where("id in (?)", Site.user.editable_groups_in_system_users.map(&:id))
  }

  # === 管理グループに設定された所属 + その親グループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_readable_group_in_system_users, lambda {
    editable_groups = Site.user.editable_groups_in_system_users
    readable_group_ids = editable_groups.map { |group| group.parent_id }
    readable_group_ids.concat(editable_groups.map(&:id))
    readable_group_ids.compact.uniq!

    where("id in (?)", readable_group_ids)
  }

  # === 組織グループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_organization_group, where(category: 0)

  # === 任意グループのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_any_group, where(category: 1)

  # === 組織・任意が任意か評価するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def any_group?
    return self.category == 1
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

  # === 指定された親グループ配下にグループを作成、編集可能か検証する
  #  管理グループに設定された所属、かつ階層レベルが1、2のグループ、または管理グループの親グループか判断する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def parent_id_valid
    is_readable_group = Site.user.readable_group_in_system_users?(parent_id)
    is_level_no_1_or_2 = System::Group.without_level_no_3.where(id: parent_id).first.present?

    errors.add(:parent_id, :invalid) unless is_readable_group && is_level_no_1_or_2
  end

  # === 状態が無効の場合は、子グループが無効かつ、自身に対するユーザー・グループが存在しないか検証する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def state_valid
    errors.add :state, I18n.t("rumi.system.group.state.message.has_enable_child_or_users_group") if has_enable_child_or_users_group?
  end

  # === 状態が有効な子グループ、または自身に対するユーザー・グループが存在(有効、無効関係なく)するか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def has_enable_child_or_users_group?
    child_count = self.children.without_disable.count
    user_count = System::UsersGroup.where(group_id: self.id).count

    return !child_count.zero? || !user_count.zero?
  end

  # === 階層レベル1のグループのレコードIDを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  レコードID
  def self.root_id
    return System::Group.extract_root.first.id
  end

  # === 階層レベル1のグループのIDか評価するメソッド
  #
  # ==== 引数
  #  * target_group_id: ID
  # ==== 戻り値
  #  boolean
  def self.root_id?(target_group_id)
    return System::Group.root_id.to_s == target_group_id.to_s
  end

  def clear_cache
    Rails.cache.clear
  end

  def save_group_history
    group_history = System::GroupHistory.find_by_id(self.id)
    if group_history.blank?
      group_history = System::GroupHistory.new
      group_history.id = self.id
    end
    group_history.attributes = self.attributes.delete_if{|k,v| k == 'id' || k == 'category'}
    group_history.save
  end

  # === 所属選択UIにて制限なしを表す選択肢を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  System::Group
  def self.no_limit_group
    item = System::Group.new(level_no: 1, code: 0,
      name: I18n.t("rumi.gwboard.no_limit.name"))
    item.id = System::Group.no_limit_group_id

    return item
  end

  # === 所属選択UIにて制限なしを表すGroupのIDを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  0
  def self.no_limit_group_id
    return 0
  end

  # === 制限なしを表すGroupのIDか評価するメソッド
  #
  # ==== 引数
  #  * target_group_id: ID
  # ==== 戻り値
  #  boolean
  def self.no_limit_group_id?(target_group_id)
    return System::Group.no_limit_group_id.to_s == target_group_id.to_s
  end

  def ou_name
    code.to_s + name
  end

  def display_name
    name
  end

  # === 所属選択UIにて階層レベルを表す表現の選択肢用の表示名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列 Format: "+-- (code) name"
  def display_name_with_level_no
    return ["+", "--" * (self.level_no.to_i - 1), " ", name].join
  end

  # === 所属選択UIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [value, display_name_with_level_no]
  def to_select_option(value_method = :id)
    return [Gw.trim(self.display_name_with_level_no), self.send(value_method)]
  end

  # === 選択済み所属UIにて表示する選択肢の作成を行うメソッド
  #
  # ==== 引数
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  [code, value, display_name_with_level_no]
  def to_json_option(value_method = :id)
    return [self.code, self.send(value_method), Gw.trim(self.display_name_with_level_no)]
  end

  # === 所属選択UIにて表示するグループの抽出を行うメソッド
  #
  # ==== 引数
  #  * target_group_id: 抽出対象のグループID
  #  * options: Hash
  #      e.g. without_disable: boolean, unshift_parent_group: boolean
  # ==== 戻り値
  #  Array.<group>
  def self.child_groups_to_select_option(target_group_id, options = System::Group::TO_SELECT_OPTION_SETTINGS[:default])
    to_without_disable = options.key?(:without_disable) && options[:without_disable] == true
    to_unshift_parent_group = options.key?(:unshift_parent_group) && options[:unshift_parent_group] == true

    # 制限なしの場合
    if System::Group.no_limit_group_id?(target_group_id)
      groups = []
      groups << System::Group.no_limit_group if to_unshift_parent_group

      return groups
    else
      # 階層レベル1のグループの場合
      return [] if System::Group.root_id?(target_group_id)

      # それ以外の場合
      groups = System::Group.where(parent_id: target_group_id)
      groups = groups.without_disable if to_without_disable
      unshift_parent_group = System::Group.where(id: target_group_id).first if to_unshift_parent_group
    end

    groups = groups.to_a.unshift(unshift_parent_group) if to_unshift_parent_group

    return groups
  end

  def self.usable?(g_id,day=nil)
    return false if g_id==nil
    return false if g_id.to_i==0
    day   = Time.now     if day==nil
    g = System::Group.find(g_id)

    if g.start_at <= day && g.end_at==nil
      return true
    end
    if g.start_at <= day && day < g.end_at
      return true
    end
    return false
  end

  def self.get_gid(u_id = Site.user.id , day=nil)
    if day==nil
      ug_order  = "user_id ASC  , job_order ASC , start_at DESC "
      ug_cond   = "user_id = #{u_id} and job_order=0 and start_at <= '#{Date.today} 00:00:00' and (end_at IS null or end_at = '0000-00-00 00:00' or end_at > '#{Date.today} 00:00:00')"
      user_group = System::UsersGroup.find(:all , :conditions=> ug_cond ,:order => ug_order)
      if user_group.blank?
        return Site.user_group.id
      else
        return user_group[0].group_id
      end
    else
      ug_order  = "user_id ASC , start_at DESC , job_order ASC"
      ug_cond   = "user_id = #{u_id} and job_order=0 and start_at < #{day}"
      user_group = System::UsersGroup.find(:all , :conditions=> ug_cond ,:order => ug_order)
      return nil if user_group.blank?
      user_group.each do |g|
        return g.id if System::Group.usable?(g.id , nil)==true
      end
      return nil
    end
  end

  def self.get_level2_groups
    group = System::Group.new
    cond  = "level_no = 2"
    order = "code, sort_no, id"
    groups = group.find(:all, :order=>order, :conditions=>cond)
    return groups
  end

  def self.get_groups(user = Site.user)
    g_cond = "user_id=#{user.id}"
    g_order= "user_id ASC,start_at DESC"
    u_groups = System::UsersGroup.find(:all,:conditions=>g_cond,:order=>g_order)
    return nil if u_groups.blank?
    groups = []
    u_groups.each do |ug|
      groups << System::Group.find(ug.group_id)
    end
    return groups
  end

  def self.select_dd_group(day=nil,level=nil,parent_id=nil,all=nil)
    day   = Time.now     if day==nil
    dd_lists = []
    dd_lists << ['すべて',0] if all == 'all'
    if parent_id ==nil
      if level==nil
        dd_lists = System::Group.self.select_dd_tree(all)
      else

      end
    else

      g_order="code ASC , start_at DESC"
      g_cond="parent_id='#{parent_id}' and state = 'enabled'"
      groups = System::Group.find(:all,:conditions=>g_cond,:orde=>g_order)
      groups.each do |g|
        next if System::Group.usable?(g.id , "#{day}" )==false
        dd_lists << ['('+g.code+')'+g.name,g.id]
      end unless groups.blank?
    end
  end

  def self.select_dd_tree(all=nil)
    dd_lists = []
    dd_lists << ['すべて',0] if all == 'all'
    roots = System::Group.find(:all,:conditions=>"level_no=1 and state='enabled'")
    roots.each do |r|
      dd_lists << ['('+r.code+')'+r.name,r.id]
      dd_lists = System::Group.get_childs(dd_lists,r)
    end
    return dd_lists
  end

  def self.get_childs(dd_lists,parent)
    c_lists = dd_lists
    childs = System::Group.find(:all,:conditions=>"state='enabled' and parent_id=#{parent.id}" ,:order=>'sort_no')
    return c_lists if childs.blank?
    pad_str = "　"*(parent.level_no.to_i-1)*2+"+"+"-"*(parent.level_no.to_i)*2
    childs.each do |c|
      c_lists << [pad_str+'('+c.code+')'+c.name,c.id]
      c_lists = System::Group.get_childs(c_lists,c)
    end
    return c_lists
  end

  def self.select_dd_tree2(all=nil)
    dd_lists = []
    dd_lists << ['すべて',0] if all == 'all'
    roots = System::Group.find(:all,:conditions=>"level_no=2 and state='enabled'" ,:order=>'sort_no')
    roots.each do |r|
      dd_lists << ['('+r.code+')'+r.name,r.id]
      dd_lists = System::Group.get_childs(dd_lists,r)
    end
    return dd_lists
  end

  def self.get_group_tree(_group_id)
    _groups = []

    if _group_id.blank?
        _dept_conditions =  "state = 'enabled'"
        _dept_conditions << " and level_no = 2"
        _dept_conditions << " and parent_id = 1"
        _dep_order = "code ASC"
        _departments = System::Group.find(:all , :conditions => _dept_conditions ,:order => _dep_order )

        _departments.each do | _dep |

        _groups << _dep
            _sec_conditions =  "state = 'enabled'"
            _sec_conditions << " and level_no = 3"
            _sec_conditions << " and parent_id = #{_dep.id}"
            _sec_order = "code ASC"
            _sections = System::Group.find(:all , :conditions => _sec_conditions ,:order => _sec_order )

            _sections.each do | _sec |
                _groups << _sec
            end
        end
    else
        _dep = System::Group.find(_group_id)
        _groups << _dep
        if _dep.level_no == 2
            _sec_conditions =  "state = 'enabled'"
            _sec_conditions << " and level_no = 3"
            _sec_conditions << " and parent_id = #{_dep.id}"
            _sec_order = "code ASC"
            _sections = System::Group.find(:all , :conditions => _sec_conditions ,:order => _sec_order )

            _sections.each do | _sec |
                _groups << _sec
            end
        end
    end
    return _groups
  end

  # === 閲覧画面で組織・任意を表示するメソッド
  #
  # ==== 引数
  #  * category: 数値(0: 組織、1:任意)
  # ==== 戻り値
  #  文字列(組織、任意)
  def self.category_show(category_value)
    return "" if category_value.blank?
    return Gw.yaml_to_array_for_select('system_groups_categories')[category_value.to_i].first
  end

  # === 組織・任意で使用されている表示名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.category_names
    return Gw.yaml_to_array_for_select("system_groups_categories").map { |factor| factor.first }
  end

  # === 組織・任意で使用されている値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  配列
  def self.category_values
    return Gw.yaml_to_array_for_select("system_groups_categories").map { |factor| factor.last }
  end

  # deprecated
  def self.ldap_show(ldap)
    ldap_state = []
    ldaps = Gw.yaml_to_array_for_select 'system_users_ldaps'
    ldaps.each do |value , key|
      ldap_state << [key,value]
    end
    ldap_str = ldap_state.assoc(ldap.to_i)
    return ldap_str[1]
  end

  def self.truncate_table
    connect = self.connection()
    truncate_query = "TRUNCATE TABLE `system_groups` ;"
    connect.execute(truncate_query)
  end

  def self.get_group_select(all=nil, prefix='', options={})
    selects = []
    selects << ['すべて',0] if all=='all'
    selects << ['制限なし',0] if all=='nolimit'
    cond = ''
    cond += ' AND ' + options[:add_conditions] if !options[:add_conditions].blank?
    groups_select = System::Group.find(:all,
      :conditions=>"state='enabled' " + cond,
      :order=>'code, sort_no, name')
    selects += groups_select.map{|group| [ Gw.trim(group.ou_name), prefix+group.id.to_s]}
    return selects
  end

  # === レコード情報をCSVに保存するためのメソッド
  #
  # ==== 引数
  #  * csv: CSV
  # ==== 戻り値
  #  CSV
  def to_csv(csv)
    # [
    #   "状態", "種別", "階層レベル",
    #   "", 所属グループID", "ID", "組織・任意", "LDAP同期",
    #   "", "名前", "名前（英）", "", "メールアドレス", "並び順", "", "", "開始日", "終了日",
    #   "", "", "", "", ""
    # ]

    # グループ情報CSV
    csv << [
      System::UsersGroup.state_show(self.state), System::UsersGroupsCsvdata.group_data_type, self.level_no,
      "", self.parent.code, self.code, System::Group.category_show(self.category), System::UsersGroup.ldap_show(self.ldap),
      "", self.name, self.name_en, "", self.email, self.sort_no, "", "", Gw.date_str(self.start_at), Gw.date_str(self.end_at),
      "", "", "", "", ""
    ]

    # グループに配属されているユーザー情報CSV
    target_user_groups = System::UsersGroup.unscoped.where(group_id: self.id).order_user_default_scope
    target_user_groups.each { |target_user_group| csv << target_user_group.to_csv }

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
    msg << "[parent] #{self.parent.inspect}"
    msg << "[children] #{self.children.inspect}"
    msg << "[user_group] #{self.user_group.inspect}"

    return msg.join("\n")
  end

end
