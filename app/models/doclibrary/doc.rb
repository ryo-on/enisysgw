# -*- encoding: utf-8 -*-
class Doclibrary::Doc < Gwboard::CommonDb
  include System::Model::Base
  include System::Model::Base::Content
  include Cms::Model::Base::Content
  include Doclibrary::Model::Recognition
  include Doclibrary::Model::Systemname

  belongs_to :content,   :foreign_key => :content_id,   :class_name => 'Cms::Content'
  belongs_to :control,   :foreign_key => :title_id,     :class_name => 'Doclibrary::Control'

  belongs_to :parent, :foreign_key => :category1_id, :class_name => 'Doclibrary::Folder'

  has_many :attach_files, foreign_key: :parent_id, class_name: 'Doclibrary::File',
      dependent: :destroy

  has_many :recognizers, foreign_key: :parent_id, class_name: 'Doclibrary::Recognizer',
      dependent: :destroy

  has_many :reminders, foreign_key: :item_id, class_name: 'Gw::Reminder',
      conditions: { category: 'doclibrary' },
      dependent: :destroy

  validates_presence_of :state
  after_validation :validate_edit_start, :validate_title, :validate_category1_id, :validate_form002
  before_destroy :notification_destroy
  after_save :check_digit, :send_reminder, :title_update_save, :notification_create, :count_doc_record
  after_destroy :count_doc_delete_record

  attr_accessor :_notification
  attr_accessor :_bbs_title_name
  attr_accessor :_acl_records
  attr_accessor :_note_section
  attr_accessor :edit_start

  def validate_edit_start
    # 編集中に他ユーザ-が更新した場合
    if self.updated_at.present?
      if self.edit_start.present? &&
          self.updated_at > DateTime.parse(self.edit_start)
        errors.add(:base, I18n.t('rumi.doclibrary.message.concurrent_editing'))
      end
    end
  end

  def validate_title
    if self.title.blank?
      errors.add :title, "を入力してください。" unless self.form_name == 'form002'
      errors.add :title, "件名を入力してください。" if self.form_name == 'form002'
    end unless self.state == 'preparation'

    if self.section_code.blank?
        errors.add :section_code, "を設定してください。"
    end unless self.form_name == 'form002' unless self.state == 'preparation'

    if self.category1_id.blank?
        errors.add :category1_id, "を設定してください。" unless self.form_name == 'form002'
        errors.add :category1_id, "号区分,区分を設定してください。" if self.form_name == 'form002'
    end unless self.state == 'preparation'
  end

  def validate_category1_id
    unless self.category1_id.blank?
      folder = Doclibrary::Folder.find(self.category1_id)
      if folder.blank?
        # フォルダが見つからなかった場合
        errors.add :category1_id, "が見つかりません。" unless self.form_name == 'form002'
      end unless self.state == 'preparation'

      unless folder.present? && folder.admin_user?
        # フォルダへの管理権限がなかった場合
        errors.add :category1_id, "への管理権限がありません。" unless self.form_name == 'form002'
      end unless self.state == 'preparation' || self.state == 'recognized'
    end
  end

  def validate_form002
    if self.form_name == 'form002'
      if self.inpfld_001.blank?
        errors.add :category2_id, "文書を選択してください。"
      end unless self.state == 'preparation'
    end
    if self.form_name == 'form002'
      if self.note.blank?
        errors.add :category2_id, "文書に添付ファイルがありません。文書の内容を確認してください。"
      end unless self.state == 'preparation'
    end
  end

  def no_recog_states
    {'draft' => '下書き保存', 'recognized' => '公開待ち'}
  end

  def recog_states
    {'draft' => '下書き保存', 'recognize' => '承認待ち', 'recognized' => '公開待ち'}
  end

  def ststus_name
    str = ''
    str = '下書き' if self.state == 'draft'
    str = '承認待ち' if self.state == 'recognize'
    str = '公開待ち' if self.state == 'recognized'
    str = '公開中' if self.state == 'public'
    return str
  end

  def public_path
    if name =~ /^[0-9]{8}$/
      _name = name
    else
      _name = File.join(name[0..0], name[0..1], name[0..2], name)
    end
    Site.public_path + content.public_uri + _name + '/index.html'
  end

  def public_uri
    content.public_uri + name + '/'
  end

  def check_digit
    return true if name.to_s != ''
    return true if @check_digit == true

    @check_digit = true

    self.name = Util::CheckDigit.check(format('%07d', id))
    save
  end

  def search(params)
    params.each do |n, v|
      next if v.to_s == ''
      case n
      when 'kwd'
        and_keywords v, :title, :body
      end
    end if params.size != 0

    return self
  end

  def get_keywords_condition(words, *columns)
    cond = Condition.new
    words.to_s.split(/[ 　]+/).each_with_index do |w, i|
      break if i >= 10
      cond.and do |c|
        columns.each do |col|
          qw = connection.quote_string(w).gsub(/([_%])/, '\\\\\1')
          c.or col, 'LIKE', "%#{qw}%"
        end
      end
    end
    return cond
  end

  # === 作成者検索の条件作成用メソッド
  #  作成者検索の条件を作成するメソッドである。
  # 　ファイルの作成者名と作成者所属名から検索を行い、引数valueと部分一致するファイルを抽出する。
  # ==== 引数
  #  * value: 検索条件の作成者名
  #  * column: DBのカラム名（作成者）
  #  * column: DBのカラム名（作成者所属ID）
  #            ※Doclibrary::Doc.createrdivision_idには所属コードが登録されている
  # ==== 戻り値
  #  作成者検索条件のConditionオブジェクトを戻す
  def get_creator_condition(value, column, division_id_column)
    cond = Condition.new
    quote_string = connection.quote_string(value).gsub(/([_%])/, '\\\\\1')

    cond.and do |c|
      # == 作成者名での部分一致検索条件 ==
      c.or column, 'LIKE', "%#{quote_string}%"

      # == 所属名での部分一致検索条件 ==
      # 所属名で部分一致するSystem::Groupを取得
      groups = System::Group.where("name LIKE '%#{quote_string}%'")

      # 所属コード配列を取得
      # ※Doclibrary::Doc.createrdivision_idには所属コードが登録されているので
      # 　検索条件には所属コードを使用する
      group_codes = groups.map(&:code)
      c.or division_id_column, group_codes
    end
    
    return cond
  end

  # === 日付期間検索の条件作成用メソッド
  #  日付期間検索の条件を作成するメソッドである。
  # ==== 引数
  #  * value: 検索条件の日付
  #  * column: DBのカラム名
  #  * option:
  #    ハッシュにより下記のオプションを指定可能
  #    - is_term_start
  #      引数valueが期間開始の日付（下限値）かどうか(true/false)
  # ==== 戻り値
  #  日付期間検索条件のConditionオブジェクトを戻す
  def get_date_condition(value, column, option={:is_term_start => true})
    cond = Condition.new
    if option[:is_term_start]
      # 引数valueが期間開始の日付（下限値）の場合
      quote_string = connection.quote_string(value).gsub(/([_%])/, '\\\\\1')
      cond.and column, ">=", quote_string
    else
      # 引数valueが期間終了の日付（上限値）の場合
      finish_date = (DateTime.parse(value) + 1).strftime("%Y-%m-%d")
      quote_string = connection.quote_string(finish_date).gsub(/([_%])/, '\\\\\1')
      cond.and column, "<", quote_string
    end
    return cond
  end
  
  def notification_delete_old_records
    Gwboard::Synthesis.destroy_all(["latest_updated_at < ?", 5.days.ago])
  end

  def notification_create
    return nil unless self._notification == 1
    Gwboard::Synthesis.destroy_all(["latest_updated_at < ?", 5.days.ago])
    Gwboard::Synthesis.destroy_all("system_name='#{self.system_name}' AND title_id=#{self.title_id} AND parent_id=#{self.id}")

    self._acl_records.each do |acl_item|
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
        :acl_flag => acl_item.acl_flag ,
        :acl_section_code => acl_item.acl_section_code ,
        :acl_user_code => acl_item.acl_user_code
      })
    end
  end

  def notification_destroy
    return nil unless self._notification == 1
    Gwboard::Synthesis.destroy_all("system_name='#{self.system_name}' AND title_id=#{self.title_id} AND parent_id=#{self.id}")
  end


  def item_path(params=nil)
    if params.blank?
      state = 'CATEGORY'
    else
      state = params[:state]
    end
    base_path = "/doclibrary/docs?title_id=#{self.title_id}&state=#{state}"
    if state=='GROUP'
      ret = base_path+"&grp=#{params[:grp]}&gcd=#{params[:gcd]}"
    else
      ret = base_path+"&cat=#{params[:cat]}"
    end
    return ret
  end

  def docs_path(params=nil)
    if params.blank?
      state = 'CATEGORY'
    else
      state = params[:state]
    end
    base_path = "/doclibrary/docs/#{self.id}?title_id=#{self.title_id}&state=#{state}"
    if state=='GROUP'
      ret = base_path+"&grp=#{params[:grp]}&gcd=#{params[:gcd]}"
    else
      ret = base_path+"&cat=#{params[:cat]}"
    end
    return ret
  end

  def show_path(params=nil)
    if params.blank?
      state = 'CATEGORY'
    else
      state = params[:state]
    end
    ret = "/doclibrary/docs/#{self.id}/?title_id=#{self.title_id}&gcd=#{self.section_code}" if state == 'GROUP'
    ret = "/doclibrary/docs/#{self.id}/?title_id=#{self.title_id}&cat=#{self.category1_id}&gcd=#{self.section_code}" if state == 'DATE'
    ret = "/doclibrary/docs/#{self.id}/?title_id=#{self.title_id}&cat=#{self.category1_id}" unless state == 'GROUP' unless state == 'DATE'
    return ret
  end

  def edit_path(params=nil)
    if params.blank?
      state = 'CATEGORY'
    else
      state = params[:state]
    end
    base_path = "/doclibrary/docs/#{self.id}/edit?title_id=#{self.title_id}&state=#{state}"
    if state=='GROUP'
      ret = base_path+"&grp=#{params[:grp]}&gcd=#{params[:gcd]}"
    else
      ret = base_path+"&cat=#{params[:cat]}"
    end
    return ret
  end

  def delete_path(params=nil)
    if params.blank?
      state = 'CATEGORY'
    else
      state = params[:state]
    end
    base_path = "/doclibrary/docs/#{self.id}/delete?title_id=#{self.title_id}&state=#{state}"
    if state=='GROUP'
      ret = base_path+"&grp=#{params[:grp]}&gcd=#{params[:gcd]}"
    else
      ret = base_path+"&cat=#{params[:cat]}"
    end
    return ret
  end

  def update_path(params=nil)
    if params.blank?
      state = 'CATEGORY'
    else
      state = params[:state]
    end
    base_path = "/doclibrary/docs/#{self.id}/update?title_id=#{self.title_id}&state=#{state}"
    if state=='GROUP'
      ret = base_path+"&grp=#{params[:grp]}&gcd=#{params[:gcd]}"
    else
      ret = base_path+"&cat=#{params[:cat]}"
    end
    return ret
  end

  def adms_edit_path
    return self.item_home_path + "adms/#{self.id}/edit/?title_id=#{self.title_id}"
  end

  def recognize_update_path
    return "/doclibrary/docs/#{self.id}/recognize_update?title_id=#{self.title_id}"
  end

  def publish_update_path
    return "/doclibrary/docs/#{self.id}/publish_update?title_id=#{self.title_id}"
  end

  def clone_path
    return "/doclibrary/docs/#{self.id}/clone/?title_id=#{self.title_id}"
  end

  def adms_clone_path
    return self.item_home_path + "adms/#{self.id}/clone/?title_id=#{self.title_id}"
  end

  def portal_show_path
    s_cat = ''
    s_cat = "&cat=#{self.category1_id}" unless self.category1_id == 0 unless self.category1_id.blank?
    return self.item_home_path + "docs/#{self.id}/?title_id=#{self.title_id}#{s_cat}"
  end

  def portal_index_path
    return self.item_home_path + "docs?title_id=#{self.title_id}"
  end

  def title_update_save
    if self.state=='public'
      item = Doclibrary::Control.find(self.title_id)
      item.docslast_updated_at = Time.now
      item.save(:validate=>false)
      unless self.category1_id.blank? == 0
        sql = "UPDATE doclibrary_folders SET updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = '#{self.category1_id}'"
        self.connection.execute(sql)
      end unless self.category1_id.blank?
    end
  end

  def count_doc_delete_record
    count_doc_record('DELETE')
  end

  def count_doc_record(state_flag=nil)
    return if self.state == 'preparation'

    sql = "SELECT COUNT(id) FROM doclibrary_docs WHERE state = 'public' AND section_code = '#{self.section_code}'"
    count = Doclibrary::Doc.count_by_sql(sql)
    item = Doclibrary::GroupFolder.find_by_code(self.section_code)
    return if item.blank?
    diff_count = count - item.children_size
    unless diff_count == 0
      item.children_size = count
      item.state = 'public' unless item.children_size == 0
      item.state = 'public' unless item.total_children_size == 0
      item.state = 'closed' if item.total_children_size == 0 if item.children_size == 0
      item.docs_last_updated_at = Time.now if self.state == 'public' unless state_flag == 'DELETE'
      item.save
      return  if item.level_no < 2
      parent_children_size_update(item, diff_count, state_flag)
    else
      s_state = 'public' unless item.children_size == 0
      s_state = 'public' unless item.total_children_size == 0
      s_state = 'closed' if item.total_children_size == 0 if item.children_size == 0
      unless item.state == s_state
        item.state = s_state
        item.docs_last_updated_at = Time.now if self.state == 'public'  unless state_flag == 'DELETE'
        item.save
        return  if item.level_no < 2
        parent_children_size_update(item, diff_count, state_flag)
      else
        if self.state == 'public'
          item.docs_last_updated_at = Time.now
          item.save
          return  if item.level_no < 2
          parent_children_size_update(item, diff_count, state_flag)
        end  unless state_flag == 'DELETE'
      end
    end
  end

  def parent_children_size_update(item, diff_count, state_flag=nil)
    return false if item.level_no < 2
    parent = Doclibrary::GroupFolder.find_by_id(item.parent_id)
    return false if parent.blank?

    parent.total_children_size = parent.total_children_size + diff_count
    parent.state = 'public' unless parent.children_size == 0
    parent.state = 'public' unless parent.total_children_size == 0
    parent.state = 'closed' if parent.total_children_size == 0 if parent.children_size == 0
    parent.docs_last_updated_at = Time.now if self.state == 'public' unless state_flag == 'DELETE'
    parent.save

    parent_children_size_update(parent, diff_count) if 1 < parent.level_no unless parent.parent.blank?
  end

  def update_group_folder_children_size
    Doclibrary::GroupFolder.update_all("children_size = 0, total_children_size = 0")
    sql = "SELECT `section_code`, COUNT(`id`) AS cnt  FROM doclibrary_docs WHERE `state` = 'public' GROUP BY `section_code`"
    items = Doclibrary::Doc.find_by_sql(sql)
    for cnt_item in items
      item = Doclibrary::GroupFolder.find_by_code(cnt_item.section_code)
      item.children_size = cnt_item.cnt unless item.blank?
      item.save unless item.blank?
    end

    item = Doclibrary::GroupFolder.new
    item.and :level_no, '>', 1
    item.order 'level_no DESC'
    items = item.find(:all,:select => 'level_no',:group => 'level_no')
    for up_item in items
      update_total_chilldren_size(up_item.level_no, items[0].level_no)
    end

    sql = "UPDATE doclibrary_group_folders SET state = 'closed' WHERE children_size = 0 AND total_children_size = 0 AND NOT (level_no = 1)"
    self.connection.execute(sql)
    sql = "UPDATE doclibrary_group_folders SET state = 'public' WHERE level_no = 1"
    self.connection.execute(sql)
  end

  def update_total_chilldren_size(level_no, start_level_no)
    item = Doclibrary::GroupFolder.new
    item.and :level_no, level_no
    item.order 'parent_id ,code'
    items = item.find(:all)
    parent_id = 0
    total_children_count = 0
    for up_item in items
      unless parent_id == up_item.parent_id
        item = Doclibrary::GroupFolder.find_by_id(parent_id)
        unless item.blank?
          item.total_children_size = total_children_count
          item.save
        end
        total_children_count = 0
      end unless parent_id == 0
      parent_id = up_item.parent_id
      if level_no == start_level_no
        total_children_count += up_item.children_size
      else
        total_children_count += up_item.children_size
        total_children_count += up_item.total_children_size
      end
    end
    unless parent_id == 0
      item = Doclibrary::GroupFolder.find_by_id(parent_id)
      unless item.blank?
        item.total_children_size = total_children_count
        item.save
      end
    end unless total_children_count == 0
  end

  def send_reminder
    self._recognizers.each do |k, v|
      unless v.blank?
        Gw.add_memo(v.to_s, "#{self.control.title}「#{self.title}」についての承認依頼が届きました。", "次のボタンから記事を確認し,承認作業を行ってください。<br /><a href='/doclibrary/docs/#{self.id}?title_id=#{self.title_id}&state=RECOGNIZE'><img src='/_common/themes/gw/files/bt_approvalconfirm.gif' alt='承認処理へ' /></a>",{:is_system => 1})
      end
    end if self._recognizers if self.state == 'recognize'
  end

  # === 承認依頼の新着情報作成メソッド
  #  承認者(作成者以外)のユーザーに対して承認依頼の新着情報を作成するメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def build_request_remind
    # 承認者のユーザーIDを取得
    recognizer_ids = []
    self.recognizers.each do |recognizer|
      recognizer_ids << recognizer.user_id
    end

    # 承認者のユーザーに通知する
    recognizer_ids.each do |user_id|
      build_remind(user_id, self.updated_at, 'request')
    end
  end

  # === 承認完了の新着情報作成メソッド
  #  作成者のユーザーに対して承認完了の新着情報を作成するメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def build_approve_remind
    # 作成者のユーザーに対して作成する
    user = System::User.find_by_code(self.creater_id)
    build_remind(user.id, self.recognized_at, 'approve') unless user.blank?
  end

  # === 新着情報作成メソッド
  #  指定ユーザーに対して新着情報を作成するメソッドである。
  # ==== 引数
  #  * user_id: ユーザーID
  #  * datetime: 日付
  #  * action: 操作名（'request': 承認依頼 / 'approve': 承認完了）
  # ==== 戻り値
  #  Gw::Reminder
  def build_remind(user_id, datetime, action)
    Gw::Reminder.create!(category: 'doclibrary',
                         user_id: user_id,
                         title_id: self.title_id,
                         item_id: self.id,
                         title: self.title, 
                         datetime: datetime,
                         action: "#{action}",
                         url: "/doclibrary/docs/#{self.id}/?title_id=#{self.title_id}")
  end

  # === 新着情報（承認依頼）既読化メソッド
  #  指定ユーザーの新着情報（承認依頼）を既読にするメソッドである。
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  なし
  def seen_request_remind(user_id)
    reminders.where(user_id: user_id, action: 'request').each do |reminder|
      # 新着情報を既読にする
      reminder.seen
    end
  end

  # === 新着情報（承認完了）既読化メソッド
  #  指定ユーザーの新着情報（承認完了）を既読にするメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def seen_approve_remind
    reminders.where(action: 'approve').each do |reminder|
      # 新着情報を既読にする
      reminder.seen
    end
  end

  # === 新着情報未読判定メソッド
  #  指定ユーザーの新着情報が未読か判定するメソッドである。
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  boolean true: 未読あり false: 全て既読
  def unseen?(user_id)
    return reminders.extract_user_id(user_id).extract_request.exists?
  end

  # === 新着情報削除メソッド
  #  該当ファイルに対する新着情報を全て削除するメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def desroy_reminder_all
    reminders.each do |reminder|
      # 新着情報を削除する
      reminder.destroy
    end
  end

  # === ファイル管理の同時編集チェックメソッド
  #  ファイル管理で、他ユーザーによる同時編集の有無を判定するメソッドである。
  # ==== 引数
  #  * edit_start: 編集開始日時
  # ==== 戻り値
  #  true:同時編集あり / false:同時編集無し
  def concurrent_editing?(edit_start)
    return false if edit_start.blank?

    begin
      edit_start = DateTime.parse(edit_start) if edit_start.class.name != 'DateTime'
      if self.updated_at.present? && self.updated_at > edit_start
        return true
      end
    rescue
      return false
    end
    return false
  end


  def _execute_sql(strsql)
    return connection.execute(strsql)
  end
end

