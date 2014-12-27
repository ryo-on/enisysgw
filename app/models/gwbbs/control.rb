# -*- encoding: utf-8 -*-
require_dependency 'rake'
class Gwbbs::Control < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content
  include Gwboard::Model::ControlCommon
  include Gwboard::Model::AttachFile
  include Gwbbs::Model::Systemname
  include System::Model::Base::Status
  
  has_many :adm, :foreign_key => :title_id, :class_name => 'Gwbbs::Adm', :dependent => :destroy
  has_many :role, :foreign_key => :title_id, :class_name => 'Gwbbs::Role', :dependent => :destroy
  
  validates_presence_of :state,:recognize,:title,:sort_no,:categoey_view_line,:monthly_view_line,:default_published
  validates_presence_of :upload_graphic_file_size_capacity,:upload_graphic_file_size_max,:upload_document_file_size_max
  after_validation :validate_params
  after_create :create_bbs_system_database
  before_save :set_icon_and_wallpaper_path
  after_save :save_admingrps, :save_editors, :save_readers, :save_readers_add, :save_sueditors, :save_sureaders , :board_css_create

  attr_accessor :_makers
  attr_accessor :_design_publish

  def save_admingrps
    unless self.admingrps_json.blank?
      Gwbbs::Adm.destroy_all("title_id=#{self.id}")
      groups = JsonParser.new.parse(self.admingrps_json)
      @dsp_admin_name = ''
      groups.each do |group|
        item_grp = Gwbbs::Adm.new()
        item_grp.title_id = self.id
        # グループの管理権限の場合はuser_idには"0"をセットする
        item_grp.user_id = 0
        item_grp.user_code = nil
        item_grp.group_id = group[1]
        item_grp.group_code = group_code(group[1])
        item_grp.group_name = group[2]
        item_grp.save!
        @dsp_admin_name = group[2] if @dsp_admin_name.blank?
      end
    end
    save_adms
    unless self.dsp_admin_name == @dsp_admin_name
      strsql = "UPDATE gwbbs_controls SET dsp_admin_name = '#{@dsp_admin_name}' WHERE id ='#{self.id}'"
      connection.execute(strsql)
    end
  end

  def save_adms
    unless self.adms_json.blank?
      users = JsonParser.new.parse(self.adms_json)
      users.each do |user|
        item_adm = Gwbbs::Adm.new()
        item_adm.title_id = self.id
        item_adm.user_id = user[1].to_i
        item_user = System::User.find(item_adm.user_id)
        if item_user
          tg = item_user.groups[0]
          item_adm.user_id = item_user[:id]
          item_adm.user_code = item_user[:code]
          item_adm.group_id = tg[:group_id]
          item_adm.group_code = tg[:code]
          @dsp_admin_name = tg[:name] unless tg[:name].blank? if @dsp_admin_name.blank?
        end
        item_adm.user_name = user[2]
        item_adm.save!
      end
    end
  end

  def save_editors
    unless self.editors_json.blank?
      Gwbbs::Role.destroy_all("title_id=#{self.id} and role_code = 'w'")
      groups = JsonParser.new.parse(self.editors_json)
      groups.each do |group|
        unless group[1].blank?
          item_grp = Gwbbs::Role.new()
          item_grp.title_id = self.id
          item_grp.role_code = 'w'
          item_grp.group_code = group_code(group[1])
          item_grp.group_code = '0' if group[1].to_s == '0'
          item_grp.group_id = group[1]
          item_grp.group_name = group[2]
          item_grp.save! unless item_grp.group_code.blank?
        end
      end
    end
  end

  def save_readers
    unless self.readers_json.blank?
      Gwbbs::Role.destroy_all("title_id=#{self.id} and role_code = 'r'")
      groups = JsonParser.new.parse(self.readers_json)
      groups.each do |group|
        unless group[1].blank?
          item_grp = Gwbbs::Role.new()
          item_grp.title_id = self.id
          item_grp.role_code = 'r'
          item_grp.group_code = group_code(group[1])
          item_grp.group_code = '0' if group[1].to_s == '0'
          item_grp.group_id = group[1]
          item_grp.group_name = group[2]
          item_grp.save!  unless item_grp.group_code.blank?
        end
      end
    end
  end

  def save_readers_add
    unless self.editors_json.blank?
      item = Gwbbs::Role.find(:all, :conditions => "title_id=#{self.id} and role_code = 'r' and group_code = '0'")
      if item.length == 0
        groups = JsonParser.new.parse(self.editors_json)
        groups.each do |group|
          unless group[1].blank?
            item_grp = Gwbbs::Role.find(:all, :conditions => "title_id=#{self.id} and role_code = 'r' and group_id = #{group[1]}")
            if item_grp.length == 0
              item_grp = Gwbbs::Role.new()
              item_grp.title_id = self.id
              item_grp.role_code = 'r'
              item_grp.group_code = group_code(group[1])
              item_grp.group_code = '0' if group[1].to_s == '0'
              item_grp.group_id = group[1]
              item_grp.group_name = group[2]
              item_grp.save! unless item_grp.group_code.blank?
            end
          end
        end
      end
    end
  end

  def save_sueditors
    unless self.sueditors_json.blank?
      suedts = JsonParser.new.parse(self.sueditors_json)
      suedts.each do |suedt|
        unless suedt[1].blank?
          item_sue = Gwbbs::Role.new()
          item_sue.title_id = self.id
          item_sue.role_code = 'w'
          item_sue.user_id = suedt[1].to_i
          item_user = System::User.find(item_sue.user_id)
          if item_user
            item_sue.user_id = item_user[:id]
            item_sue.user_code = item_user[:code]
          end
          item_sue.user_name = suedt[2]
          item_sue.save!
          item_sue = Gwbbs::Role.new()
          item_sue.title_id = self.id
          item_sue.role_code = 'r'
          item_sue.user_id = suedt[1].to_i
          item_user = System::User.find(item_sue.user_id)
          if item_user
            item_sue.user_id = item_user[:id]
            item_sue.user_code = item_user[:code]
          end
          item_sue.user_name = suedt[2]
          item_sue.save!
        end
      end
    end
  end

  def save_sureaders
    unless self.sueditors_json.blank?
      surds = JsonParser.new.parse(self.sureaders_json)
      surds.each do |surd|
        unless surd[1].blank?
          item_sur = Gwbbs::Role.new()
          item_sur.title_id = self.id
          item_sur.role_code = 'r'
          item_sur.user_id = surd[1].to_i
          item_user = System::User.find(item_sur.user_id)
          if item_user
            item_sur.user_id = item_user[:id]
            item_sur.user_code = item_user[:code]
          end
          item_sur.user_name = surd[2]
          item_sur.save!
        end
      end
    end
  end

  def group_code(id)
    item = System::Group.find_by_id(id)
    ret = ''
    ret = item.code if item
    return ret
  end

  def gwbbs_form_name
    return 'gwbbs/admin/user_forms/' + self.form_name + '/'
  end

  def use_form_name()
    return [
      ['一般掲示板', 'form001'],
    ]
  end

  def validate_params
    errors.add :default_published, "は数値で1以上を入力してください。" if self.default_published.blank?
    errors.add :default_published, "は数値で1以上を入力してください。" if self.default_published == 0
    errors.add :upload_graphic_file_size_capacity, "は数値で1以上を入力してください。" if self.upload_graphic_file_size_capacity.blank?
    errors.add :upload_graphic_file_size_capacity, "は数値で1以上を入力してください。" if self.upload_graphic_file_size_capacity == 0
    errors.add :upload_document_file_size_capacity, "は数値で1以上を入力してください。" if self.upload_document_file_size_capacity.blank?
    errors.add :upload_document_file_size_capacity, "は数値で1以上を入力してください。" if self.upload_document_file_size_capacity == 0
    errors.add :upload_graphic_file_size_max, "は数値で1以上を入力してください。" if self.upload_graphic_file_size_max.blank?
    errors.add :upload_graphic_file_size_max, "は数値で1以上を入力してください。" if self.upload_graphic_file_size_max == 0
    errors.add :upload_document_file_size_max, "は数値で1以上を入力してください。" if self.upload_document_file_size_max.blank?
    errors.add :upload_document_file_size_max, "は数値で1以上を入力してください。" if self.upload_document_file_size_max == 0
    errors.add :doc_body_size_capacity, "は数値で1以上を入力してください。" if self.doc_body_size_capacity.blank?
    errors.add :doc_body_size_capacity, "は数値で1以上を入力してください。" if self.doc_body_size_capacity == 0

    error_users = validate_users(self.adms_json)
    unless error_users.blank?
      errors.add(:adms_json, "の#{error_users.join(", ")}は無効になっています。削除するか、または有効なユーザーを選択してください。")
    end

    error_users = validate_users(self.sueditors_json) unless self.sueditors_json.blank?
    unless error_users.blank?
      errors.add(:sueditors_json, "の#{error_users.join(", ")}は無効になっています。削除するか、または有効なユーザーを選択してください。")
    end

    error_users = validate_users(self.sureaders_json) unless self.sureaders_json.blank?
    unless error_users.blank?
      errors.add(:sureaders_json, "の#{error_users.join(", ")}は無効になっています。削除するか、または有効なユーザーを選択してください。")
    end
  end

  def validate_users(json)
    error_users = []
    fields = JsonParser.new.parse(json)
    fields.each do |field|
      user = System::User.find(field[1])
      if !user || user.state != "enabled"
        error_users << field[2]
      end
    end
    error_users
  end

  def create_bbs_system_database
    if self.dbname.blank?
      self.dbname = "#{default_database_name}_#{sprintf('%06d', self.id)}"
      self.save
    end
    create_db
    rake_task = Rake.application
    rake_task.init
    rake_task.load_rakefile
    rake_task["db:jgw_bbs:migrate"].reenable
    rake_task["db:jgw_bbs:migrate"].invoke
  end

  def default_database_name
    return "#{Rails.env}_jgw_bbs" 
  end

  def create_db
    strsql = "CREATE DATABASE IF NOT EXISTS `#{self.dbname}`;"
    return connection.execute(strsql)
  end

  def categorys_path
    return self.item_home_path + "categories?title_id=#{self.id}"
  end

  def postindices_path
    return self.item_home_path + "postindices?title_id=#{self.id}"
  end

  def new_upload_path
    return self.item_home_path + "uploads/new?title_id=#{self.id}"
  end

  def docs_path
    return self.item_home_path + "docs?title_id=#{self.id}"
  end

  def adm_show_path
    return self.item_home_path + "makers/#{self.id}"
  end

  def design_publish_path
    return self.item_home_path + "makers/#{self.id}/design_publish"
  end

  def void_destroy_path
    return "#{Core.current_node.public_uri}destroy_void_documents?title_id=#{self.id}"
  end

  def set_icon_and_wallpaper_path
    return unless self._makers
  end

  def original_css_file
    return "#{RAILS_ROOT}/public/_common/themes/gw/css/option.css"
  end

  def board_css_file_path
    return "#{RAILS_ROOT}/public/_attaches/css/#{self.system_name}"
  end

  def board_css_preview_path
    return "#{RAILS_ROOT}/public/_attaches/css/preview/#{self.system_name}"
  end

  def board_css_create
    ret = false
    ret = true if self._makers
    ret = true if self._design_publish
    return nil unless ret
  end

  # === 掲示板毎の未読件数取得メソッド
  #  ログインユーザーが閲覧権限を持つ掲示板において公開された未読の記事件数を掲示板毎に取得する
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  通知件数(整数)
  def notification_each_db(user_id)
    return Gw::Reminder.extract_bbs(user_id, nil, nil).where(title_id: self.id).count
  end

  class << self

    # === 新着情報取得メソッド
    #  新着情報に表示する未読の掲示板記事情報を取得する
    # ==== 引数
    #  * user_id: ユーザーID
    #  * sort_key: 並び替えするKey（日付／概要）
    #  * order: 並び順（昇順／降順）
    # ==== 戻り値
    #  掲示板記事情報(Hashオブジェクト)
    def remind(user_id, sort_key, order)
      return Gw::Reminder::to_rumi_format(Gw::Reminder.extract_bbs(user_id, sort_key, order))
    end

    # === 通知件数取得メソッド
    #  ログインユーザーが閲覧権限を持つ掲示板において公開された未読の記事件数を取得する
    # ==== 引数
    #  * user_id: ユーザーID
    # ==== 戻り値
    #  通知件数(整数)
    def notification(user_id)
      return Gw::Reminder.extract_bbs(user_id, nil, nil).count
    end

    # === 掲示板毎の通知件数取得メソッド
    #  ログインユーザーが閲覧権限を持つ掲示板において公開された未読の記事件数を掲示板毎に取得する
    # ==== 引数
    #  * user_id: ユーザーID
    # ==== 戻り値
    #  掲示板毎の通知件数(Hashオブジェクト)
    #  タイトルIDがkey、通知件数がvalue。
    def notification_counts(user_id)
      result = {}
      Gw::Reminder.extract_bbs(user_id, nil, nil).
          select("title_id, count(item_id) AS item_count").
          group(:title_id).each do |target|
        result[target.title_id] = target.item_count
      end
      return result
    end
  end

end
