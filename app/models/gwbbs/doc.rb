# -*- encoding: utf-8 -*-
class Gwbbs::Doc < Gwboard::CommonDb
  include System::Model::Base
  include System::Model::Base::Content
  include Cms::Model::Base::Content
  include Gwboard::Model::Recognition
  include Gwbbs::Model::Systemname

  belongs_to :control,   :foreign_key => :title_id,     :class_name => 'Gwbbs::Control'
  has_many   :comment,   :foreign_key => :parent_id,    :class_name => 'Gwbbs::Comment'
  has_many :reminders, foreign_key: :item_id, dependent: :destroy, class_name: "Gw::Reminder",
    conditions: Proc.new { { category: "bbs", title_id: self.title_id } }

  validates_presence_of :state, :able_date
  after_validation :validate_title
  before_destroy :notification_destroy
  before_save :expiry_date_update
  after_save :check_digit, :send_reminder, :title_update_save, :notification_update
  after_destroy :doc_body_size_currently_update

  attr_accessor :_notification
  attr_accessor :_bbs_title_name
  attr_accessor :_note_section
  attr_accessor :_no_validation

#    validates :name_editor_section_id, presence: true, if: Proc.new{ |record| (record.name_type == 1 || record.name_type == 2) }

  def validate_title
    return if self._no_validation

    unless self.state == 'preparation'
      item = Gwbbs::Control.find(self.title_id)
      body_size_capacity = 0
      body_size_currently = 0
      body_size_capacity = item.doc_body_size_capacity.megabytes unless item.doc_body_size_capacity.blank?
      body_size_currently = item.doc_body_size_currently unless item.doc_body_size_currently.blank?
      body_size_currently = body_size_currently + self.body.size
      errors.add :title, "記事本文の容量制限を#{body_size_currently - body_size_capacity}バイト超過しました。　不要な記事を削除するか、管理者に連絡してください。" if body_size_capacity < body_size_currently unless body_size_capacity == 0
    end unless self.body.blank?

    if self.title.blank?
      errors.add :title, "タイトルを入力してください。"
    else
      str = self.title.to_s.gsub(/　/, '').strip
      errors.add :title, "スペースのみのタイトルは登録できません。" if str.blank?
      unless str.blank?

        s_chk = self.title.gsub(/\r\n|\r|\n/, '')
        self.title = s_chk
        errors.add :title, "タイトルは140文字以内で記入してください。" if 140 < s_chk.split(//).size
      end
    end if self.form_name == 'form001' unless self.state == 'preparation'

    if self.category1_id.blank?
      errors.add :category1_id, "を設定してください。"
    end if self.category_use == 1 unless self.state == 'preparation'

    if self.section_code.blank?
      errors.add :section_code,"を選択してください。"
    end unless self.state == 'preparation'

    if ((self.name_type == 1 || self.name_type == 2) && self.name_editor_section_id.blank?)
      errors.add :name_editor_section_id,"を選択してください。"
    end

    if self.able_date > self.expiry_date
      errors.add :able_date, "を確認してください。（期限日が公開日より前になっています。）"
      errors.add :expiry_date, "を確認してください。（期限日が公開日より前になっています。）"
    end unless self.able_date.blank? unless self.expiry_date.blank?

      form002_validate if form_name == "form002"
      form003_validate if form_name == "form003"
      form004_validate if form_name == "form004"
      form005_validate if form_name == "form005"
      form006_validate if form_name == "form006"
      form007_validate if form_name == "form007"
      form009_validate if form_name == "form009"
  end

  def form002_validate
    if title.blank?
      errors.add :title,"研修名を入力してください。"
    end

    if self.inpfld_001 != "" && self.inpfld_002 != ""
      if is_date(self.inpfld_001) == false
        errors.add :inpfld_001,"研修開始日入力に誤りがあります。"
      end
      if is_date(self.inpfld_002) == false
        errors.add :inpfld_002,"申込締切日入力に誤りがあります。"
      end
      f1 = Time.parse self.inpfld_001
      f2 = Time.parse self.inpfld_002
      if f1 < f2
        errors.add :inpfld_002,"申込締切日は、研修開始日より前の日付に設定してください。"
      end
    end
  end

  def form003_validate
    if is_date(self.inpfld_001) == false
      errors.add :inpfld_001,"逝去日を入力してください。"
    else
      self.inpfld_001 = Date.parse(self.inpfld_001).strftime('%Y-%m-%d').to_s
    end
    if self.inpfld_012.blank?
      errors.add :inpfld_012,"役職名を選択してください。"
    end
    if self.inpfld_013.blank?
      errors.add :inpfld_013,"職員の名前を入力してください。"
    end if self.inpfld_024 == "家族"
    if self.inpfld_014.blank?
      errors.add :inpfld_014,"続柄を選択してください。"
    end if self.inpfld_024 == "家族"
    if self.inpfld_015.blank?
      errors.add :inpfld_015,"故人の名前を入力してください。"
    end if self.inpfld_024 == "家族"
    if self.inpfld_025.blank?
      errors.add :inpfld_025,"職員の名前を入力してください。"
    end if self.inpfld_024 == "職員"
    if is_date(self.inpfld_003) == false
       errors.add :inpfld_003,"通夜の日付を入力してください。"
    else
      self.inpfld_003 = Date.parse(self.inpfld_003).strftime('%Y-%m-%d').to_s
    end unless self.inpfld_003.blank?
    if is_date(self.inpfld_006) == false
      errors.add :inpfld_006,"告別式の日付を入力してください。"
    else
      self.inpfld_006 = Date.parse(self.inpfld_006).strftime('%Y-%m-%d').to_s
    end unless self.inpfld_006.blank?
  end

  def form004_validate
    if self.inpfld_001.blank?
      errors.add :inpfld_001,"職を入力してください。"
    end
    if self.title.blank?
      errors.add :title,"氏名を入力してください。"
    end
    if self.body.blank?
      errors.add :body,"電話番号を入力してください。"
    end
    if self.inpfld_002.blank?
      errors.add :inpfld_002,"メールアドレスを入力してください。"
    end
  end

  def form005_validate

    unless (self.state == 'preparation')
      if self.title.blank?
        errors.add :title,"事務の名称を入力してください。"
      end
      if self.body.blank?
        errors.add :body,"保有課名を入力してください。"
      end
    end
  end

  def form006_validate
    unless (self.state == 'preparation')
      if self.title.blank?
        errors.add :title, "文書名を入力してください。"
      end
      if self.inpfld_002.blank?
        errors.add :inpfld_002, "区分を入力してください。"
      end
      unless is_date(self.inpfld_006d)
        errors.add :inpfld_006d, "通知日を入力してください。"
      end
    end
  end

  def form007_validate
    unless (self.state == 'preparation')
      if self.title.blank?
        errors.add :title, "文書名を入力してください。"
      end
      if self.inpfld_002.blank?
        errors.add :inpfld_002, "担当別を入力してください。"
      end
      unless is_date(self.inpfld_006d)
        errors.add :inpfld_006d, "国通知日を入力してください。"
      end
    end
  end

  def form009_validate
    if self.title.blank?
      errors.add :title, "タイトルを入力してください。"
    else
      str = self.title.to_s.gsub(/　/, '').strip
      errors.add :title, "スペースのみのタイトルは登録できません。" if str.blank?
      unless str.blank?
        s_chk = self.title.gsub(/\r\n|\r|\n/, '')
        errors.add :title, "タイトルは140文字以内で記入してください。" if 140 < s_chk.split(//).size
      end
    end unless self.state == 'preparation'
  end

  def is_date(date_state)
    begin
      date_state.to_time
    rescue
      return false
    end
    return true
  end

  def importance_states
    {'0' => '重要必読', '1' => '普通'}
  end

  def importance_states_select
    return [
      ['重要必読', 0] ,
      ['普通', 1]
    ]
  end

  def one_line_states
    return [
      ['使用しない', 0] ,
      ['使用する', 1]
    ]
  end

  def no_recog_states
    {'draft' => '下書き保存', 'recognized' => '公開待ち'}
  end

  def recog_states
    {'draft' => '下書き保存', 'recognize' => '承認待ち', 'recognized' => '公開待ち'}
  end

  def family_states
    {'0' => '家族', '1' => '職員'}
  end

  def ststus_name
    str = ''
    str = '下書き' if self.state == 'draft'
    str = '承認待ち' if self.state == 'recognize'
    str = '公開待ち' if self.state == 'recognized'
    str = '公開中' if self.state == 'public'
    str = '期限切れ' if self.expiry_date < Time.now unless self.expiry_date.blank? if self.state == 'public'
    return str
  end

  def name_types_select
    return [
      ['ユーザ名のみ', 0] ,
      ['所属名のみ', 1] ,
      ['ユーザ名と所属名', 2]
    ]
  end

  def public_path
    if name =~ /^[0-9]{8}$/
      _name = name
    else
      _name = File.join(name[0..0], name[0..1], name[0..2], name)
    end
    Core.public_path + content_public_uri + _name + '/index.html'
  end

  def public_uri
    content_public_uri + name + '/'
  end

  def content_public_uri
    ""
  end

  def check_digit
    return true if name.to_s != ''
    return true if @check_digit == true

    @check_digit = true

    self.name = Util::CheckDigit.check(format('%07d', id))
    save
  end

  def search(params,item=nil)
    params.each do |n, v|
      next if v.to_s == ''
      case n
      when 'cat1'
        self.and :category1_id, v
      when 'cat2'
        self.and :category2_id, v
      when 'cat3'
        self.and :category3_id, v
      when 'grp'
        self.and :section_code, v unless item == 'form007' unless item =='form006'
        self.and :inpfld_002, v if item == 'form006'
        self.and :inpfld_002, v if item == 'form007'
      when 'yyyy'
        self.and :inpfld_006w, v if item == 'form006'
      when 'kwd'
        and_keywords v, :title, :body
      #作成者を検索条件に追加
      when 'creater'
        search_creator(params)
      #公開日を検索条件に追加
      when 'startdate'
        self.and :able_date, '>=', v+" 00:00:00"
      when 'enddate'
        self.and :able_date, '<=', v+" 23:59:59"
      end
    end if params.size != 0

    return self
  end

  # === 作成者検索の条件追加用メソッド
  #  作成者検索の条件を追加するメソッドである。
  # 　掲示板の作成者名と作成者所属名から検索を行い、入力値と部分一致する掲示板を抽出する。
  # ==== 引数
  #  * params: アクションパラメータ
  # ==== 戻り値
  #  作成者検索条件のConditionオブジェクトを戻す
  def search_creator(params)
    params.each do |n, v|
      next if v.to_s == ''
      case n
      #作成者を検索条件に追加
      when 'creater'
        cond = Condition.new
        quote_string = connection.quote_string(v).gsub(/([_%])/, '\\\\\1')
        cond.and do |c|
          # == 作成者名での部分一致検索条件 ==
          c.or :creater, 'LIKE', "%#{quote_string}%"

          # == 所属名での部分一致検索条件 ==
          # 所属名で部分一致するSystem::Groupを取得
          groups = System::Group.where("name LIKE '%#{quote_string}%'")

          # 所属コード配列を取得
          # ※Gwbbs::Doc.createrdivision_idには所属コードが登録されているので
          # 　検索条件には所属コードを使用する
          group_codes = groups.map(&:code)
          c.or :createrdivision_id, group_codes
        end

        self.and cond
      end
    end if params.size != 0

    return self
  end

  def notification_delete_old_records
    Gwboard::Synthesis.destroy_all(["latest_updated_at < ?", 5.days.ago])
  end

  def notification_create
    return nil unless self._notification == 1

    notification_delete_old_records
    Gwboard::Synthesis.destroy_all(["latest_updated_at < ?", 5.days.ago])

    Gwboard::Synthesis.create({
      :system_name => self.system_name,
      :state => self.state,
      :title_id => self.title_id,
      :parent_id => self.id,
      :latest_updated_at => self.latest_updated_at ,
      :board_name => self._bbs_title_name,
      :title => self.title,
      :url => self.portal_show_path,
      :editordivision => self._note_section ,
      :editor => self.editor || self.creater ,
      :able_date => self.able_date ,
      :expiry_date => self.expiry_date
    })
  end

  def notification_update
    return if self._no_validation
    return nil unless self._notification == 1

    notification_delete_old_records

    item = Gwboard::Synthesis.new
    item.and :title_id, self.title_id
    item.and :parent_id, self.id
    item.and :system_name , self.system_name
    item = item.find(:first)
    unless item.blank?
      item.system_name = self.system_name
      item.state = self.state
      item.title_id = self.title_id
      item.parent_id = self.id
      item.latest_updated_at = self.latest_updated_at
      item.board_name = self._bbs_title_name
      item.title = self.title
      item.url = self.portal_show_path
      item.editordivision = self._note_section
      item.editor = self.editor || self.creater
      item.able_date = self.able_date
      item.expiry_date = self.expiry_date
      item.save
    else
      notification_create
    end
  end

  def notification_destroy
    return nil unless self._notification == 1

    item = Gwboard::Synthesis.new
    item.and :title_id, self.title_id
    item.and :parent_id, self.id
    item.and :system_name, self.system_name
    item = item.find(:first)
    item.destroy if item
  end

  def importance_name
    return self.importance_states[self.importance.to_s]
  end

  def new_comment_path
    return self.item_home_path + "comments/new?title_id=#{self.title_id}&p_id=#{self.id}"
  end

  def image_edit_path
    return self.item_home_path + "images?title_id=#{self.title_id}&p_id=#{self.id}"
  end

  def upload_edit_path
    return self.item_home_path + "uploads?title_id=#{self.title_id}&p_id=#{self.id}"
  end

  def item_path
    return "/gwbbs/docs?title_id=#{self.title_id}"
  end

  def show_path
    return "/gwbbs/docs/#{self.id}/?title_id=#{self.title_id}"
  end

  def edit_path
    return "/gwbbs/docs/#{self.id}/edit/?title_id=#{self.title_id}"
  end

  def adms_edit_path
    return self.item_home_path + "adms/#{self.id}/edit/?title_id=#{self.title_id}"
  end

  def recognize_update_path
    return "/gwbbs/docs/#{self.id}/recognize_update?title_id=#{self.title_id}"
  end

  def publish_update_path
    return "/gwbbs/docs/#{self.id}/publish_update?title_id=#{self.title_id}"
  end

  def clone_path
    return "/gwbbs/docs/#{self.id}/clone/?title_id=#{self.title_id}"
  end
  #
  def adms_clone_path
    return self.item_home_path + "adms/#{self.id}/clone/?title_id=#{self.title_id}"
  end

  def delete_path
    return "/gwbbs/docs/#{self.id}/delete?title_id=#{self.title_id}"
  end

  def update_path
    #return "/_admin/gwbbs/docs/#{self.id}/update?title_id=#{self.title_id}"
    return "/gwbbs/docs/#{self.id}?title_id=#{self.title_id}"
  end

  def portal_show_path
    return self.item_home_path + "docs/#{self.id}/?title_id=#{self.title_id}"
  end

  def portal_index_path
    return self.item_home_path + "docs?title_id=#{self.title_id}"
  end

  def get_domain
    rails_env = ENV['RAILS_ENV']
    ret = 'localhost'
    begin
      site = YAML.load_file('config/core.yml')
      ret = site[rails_env]['domain']
    rescue
    end
    return ret
  end

  def send_reminder
    return if self._no_validation
    self._recognizers.each do |k, v|
      unless v.blank?
        Gw.add_memo(v.to_s, "#{self.control.title}「#{self.title}」についての承認依頼が届きました。", "次のボタンから記事を確認し,承認作業を行ってください。<br /><a href='#{self.show_path}&state=RECOGNIZE'><img src='/_common/themes/gw/files/bt_approvalconfirm.gif' alt='承認処理へ' /></a>",{:is_system => 1})
      end
    end if self._recognizers if self.state == 'recognize'
  end

  def title_update_save
    return if self._no_validation

    sql = "SELECT SUM(LENGTH(`body`)) AS total_size FROM `gwbbs_docs` WHERE title_id = #{self.title_id} GROUP BY title_id"
    item = Gwbbs::Doc.find_by_sql(sql)
    total_size = 0
    total_size = item[0].total_size unless item[0].total_size.blank? unless item.blank?
    item = Gwbbs::Control.find(self.title_id)
    item.doc_body_size_currently  = total_size
    item.docslast_updated_at = Time.now if self.state=='public'   #記事の最終更新日時設定
    item.save(:validate=>false)
  end

  #記事削除時に記事本文のサイズを集計
  def doc_body_size_currently_update
    sql = "SELECT SUM(LENGTH(`body`)) AS total_size FROM `gwbbs_docs` WHERE title_id = #{self.title_id} GROUP BY title_id"
    item = Gwbbs::Doc.find_by_sql(sql)
    total_size = 0
    total_size = item[0].total_size unless item[0].total_size.blank? unless item.blank?
    item = Gwbbs::Control.find(self.title_id)
    item.doc_body_size_currently  = total_size
    item.save
  end

  #終了日を設定しない場合に上限日をセットする
  def expiry_date_update
    if self.inpfld_001 == "1"
      self.expiry_date = "9999-12-31 23:59:59"
    else
      self.inpfld_001 = nil
    end
  end

  def _execute_sql(strsql)
    return connection.execute(strsql)
  end

  def new_mark_flg
    flg = false
    if self.createdate.blank?
      #flg = false
    else
      begin
        new_mark_start = Time.parse(self.createdate) + 86400
        time_now = Time.now
        if new_mark_start >= time_now
          flg = true
        else
          #flg = false
        end
      rescue
        #flg = false
      end
    end
    return flg
  end

  # === 新着情報(新規作成時)を作成するメソッド
  #  参加者(作成者以外)のユーザーに対して作成する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def build_created_remind
    # 閲覧、編集、管理権限を持つユーザーに通知する
    group_ids = []
    user_ids = []
    control.role.each do |role|
      group_ids << role.group_id
      user_ids << role.user_id
    end
    group_ids = group_ids.flatten.compact.uniq

    # 制限なしが選択されていた場合
    if group_ids.include?(0)
      send_group_ids = System::Group.all.to_a.map(&:id)
    else
      send_group_ids = group_ids
    end

    # 所属からユーザー通知するユーザーを抽出
    user_ids = build_remind_user_ids(send_group_ids)

    # ユーザーに通知
    build_remind(user_ids)

    # 更新者は通知を既読にする
    seen_remind(Core.user.id)
  end

  # === 新着情報(編集時)を作成するメソッド
  #  参加者(作成者以外)のユーザーに対して作成する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def build_updated_remind
    # 閲覧、編集、管理権限を持つユーザーに通知する
    group_ids = []
    user_ids = []
    control.role.each do |role|
      group_ids << role.group_id
      user_ids << role.user_id
    end
    group_ids = group_ids.flatten.compact.uniq

    # 制限なしが選択されていた場合
    if group_ids.include?(0)
      send_group_ids = System::Group.all.to_a.map(&:id)
    else
      send_group_ids = group_ids
    end

    # 所属からユーザー通知するユーザーを抽出
    user_ids = build_remind_user_ids(send_group_ids)

    # ユーザーに通知
    build_remind(user_ids, "update")

    # 更新者は通知を既読にする
    seen_remind(Core.user.id)
  end

  # === 新着情報を作成するユーザIDの一覧を取得するメソッド
  #  グループに対して作成する
  # ==== 引数
  #  * group_ids: 対象となるグループIDの配列
  # ==== 戻り値
  #  ユーザIDの配列
  def build_remind_user_ids(group_ids)
    user_ids = System::User.includes(:groups).
      where("system_users.state" => "enabled").
      where(["system_groups.id IN (?)", group_ids]).map(&:id)
    return user_ids.flatten.compact.uniq
  end

  # === 新着情報を作成するメソッド
  #  ユーザーに対して作成する
  # ==== 引数
  #  * user_ids: ユーザーIDの配列
  # ==== 戻り値
  #  なし
  def build_remind(user_ids, action = "open")
    timestamp = connection.quote(Time.now.utc)
    values = user_ids.collect { |user_id|
      attrs = [
        "'bbs'", user_id, title_id, id, "'#{title}'",
        connection.quote(able_date),
        "'/gwbbs/docs/#{id}/?title_id=#{title_id}'",
        "'#{action}'", timestamp, timestamp,
        connection.quote(expiry_date),
      ]
      "(#{attrs.join(',')})"
    }
    sql =<<SQL
INSERT INTO #{Gw::Reminder.table_name}
  (category, user_id, title_id, item_id, title, datetime, url,
   action, created_at, updated_at, expiration_datetime)
  VALUES #{values.join(",")}
SQL
    Gw::Reminder.connection.execute(sql)
  end

  # === 新着情報を既読にするメソッド
  #  ユーザーに対して実行する
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  なし
  def seen_remind(user_id)
    reminders.extract_user_id(user_id).each do |reminder|
      # 既読にする
      reminder.seen
    end
  end

  # === 未読か評価するメソッド
  #  ユーザーに対して実行する
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  boolean true: 未読あり false: 全て既読
  def unseen?(user_id)
    reminders.extract_user_id(user_id).exists?
  end

  # === 記事が公開状態、かつ公開期限内であるか評価するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean true: public / false: それ以外
  def public_status?
    return state == "public"
  end

end
