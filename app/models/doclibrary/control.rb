# -*- encoding: utf-8 -*-
require_dependency 'rake'
class Doclibrary::Control < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content
  include Gwboard::Model::ControlCommon
  include Gwboard::Model::AttachFile
  include Doclibrary::Model::Systemname
  include System::Model::Base::Status

  has_many :adm, :foreign_key => :title_id, :class_name => 'Doclibrary::Adm', :dependent => :destroy
  has_many :role, :foreign_key => :title_id, :class_name => 'Doclibrary::Role', :dependent => :destroy

  validates_presence_of :state, :title
  validates_presence_of :upload_graphic_file_size_capacity,:upload_document_file_size_capacity, :upload_graphic_file_size_max,:upload_document_file_size_max
  after_validation :validate_params
  after_create :create_doclib_system_database
  after_save :save_admingrps, :save_readers, :save_sureaders

  attr_accessor :_editing_group

  def doclib_form_name
    return 'doclibrary/admin/user_forms/' + self.form_name + '/'
  end

  def use_form_name()
    return [
      ['一般書庫', 'form001']
    ]
  end

  def save_admingrps
    unless self.admingrps_json.blank?
      Doclibrary::Adm.destroy_all("title_id=#{self.id}")
      groups = JsonParser.new.parse(self.admingrps_json)
      @dsp_admin_name = ''
      groups.each do |group|
        item_grp = Doclibrary::Adm.new()
        item_grp.title_id = self.id
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
      strsql = "UPDATE doclibrary_controls SET dsp_admin_name = '#{@dsp_admin_name}' WHERE id ='#{self.id}'"
      connection.execute(strsql)
    end
  end

  def save_adms
    unless self.adms_json.blank?
      users = JsonParser.new.parse(self.adms_json)
      users.each do |user|
        item_adm = Doclibrary::Adm.new()
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

  def save_readers
    unless self.readers_json.blank?
      Doclibrary::Role.destroy_all("title_id=#{self.id} and role_code = 'r'")
      groups = JsonParser.new.parse(self.readers_json)
      groups.each do |group|
        unless group[1].blank?
          item_grp = Doclibrary::Role.new()
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

  def save_sureaders
    unless self.sureaders_json.blank?
      surds = JsonParser.new.parse(self.sureaders_json)
      surds.each do |surd|
        unless surd[1].blank?
          item_sur = Doclibrary::Role.new()
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

  def validate_params
    error_users = validate_users(self.adms_json)
    unless error_users.blank?
      errors.add(:adms_json, "の#{error_users.join(", ")}は無効になっています。削除するか、または有効なユーザーを選択してください。")
    end

    error_users = validate_users(self.sureaders_json)
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

  def create_doclib_system_database
    if self.dbname.blank?
      self.dbname = "#{default_database_name}_#{sprintf('%06d', self.id)}"
      self.save
    end
    # データベース作成
    create_db

    # Rakeタスクを実行し、migration実行
    rake_task = Rake.application
    rake_task.init
    rake_task.load_rakefile
    rake_task["db:jgw_doc:migrate"].reenable
    rake_task["db:jgw_doc:migrate"].invoke

    # ルートフォルダの設定
    set_category_folder_root
  end

  def default_database_name
    return "#{Rails.env}_jgw_doc"
  end

  def create_db
    strsql = "CREATE DATABASE IF NOT EXISTS `#{self.dbname}`;"
    return connection.execute(strsql)
  end

  def set_category_folder_root
    cnn = Doclibrary::Folder.establish_connection
    cnn.spec.config[:database] = self.dbname
    folder_item = Doclibrary::Folder
    folder_item.establish_connection(cnn.spec.config)
    item = folder_item.new
    item.and :title_id, self.id
    item.and :level_no, 1
    folder = item.find(:first)
    unless folder.blank?
      folder_item.update(folder.id,
        :updated_at => Time.now,
        :_acl_create_skip => true ,
        :name => self.category1_name
      )
    else
      folder = folder_item.new(
        :state => 'public',
        :title_id => self.id,
        :parent_id => nil,
        :sort_no => 0,
        :level_no => 1,
        :_acl_create_skip => true ,
        :name => self.category1_name
      )
      folder.save!
      save_role_json_all(folder.id)
    end
  end

  def save_role_json_all(folder_id)
    cnn = Doclibrary::Folder.establish_connection
    cnn.spec.config[:database] = self.dbname
    item = Doclibrary::FolderAcl
    item.establish_connection(cnn.spec.config)
    item = item.new
    item.acl_flag = 0
    item.title_id = self.id
    item.folder_id = folder_id
    item.save!
  end

  # === 添付ファイル利用可能容量超過判定メソッド
  #  本メソッドは、添付ファイルの利用可能容量超過を判定するメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  True: 利用可能容量超過 / False:利用可能容量範囲内
  def is_disk_full_for_document_file?
    if self.upload_document_file_size_capacity_unit == 'MB'
      used = self.upload_document_file_size_currently.to_f / 1.megabyte.to_f
      capa_div = self.upload_document_file_size_capacity.megabyte.to_f
    else
      used = self.upload_document_file_size_currently.to_f / 1.gigabyte.to_f
      capa_div = self.upload_document_file_size_capacity.gigabytes.to_f
    end
    availability = 0
    availability = (self.upload_document_file_size_currently / capa_div) * 100 unless capa_div == 0
    tmp = availability * 100
    tmp = tmp.to_i
    availability = sprintf('%g',tmp.to_f / 100)
    tmp = used * 100
    tmp = tmp.to_i
    used = sprintf('%g',tmp.to_f / 100)
    used = used.to_s + self.upload_document_file_size_capacity_unit
    return (capa_div < self.upload_document_file_size_currently)
  end

  # === 画像ファイル利用可能容量超過判定メソッド
  #  本メソッドは、画像ファイルの利用可能容量超過を判定するメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  True: 利用可能容量超過 / False:利用可能容量範囲内
  def is_disk_full_for_graphic_file?
    if self.upload_graphic_file_size_capacity_unit == 'MB'
      used = self.upload_graphic_file_size_currently.to_f / 1.megabyte.to_f
      capa_div = self.upload_graphic_file_size_capacity.megabyte.to_f
    else
      used = self.upload_graphic_file_size_currently.to_f / 1.gigabyte.to_f
      capa_div = self.upload_graphic_file_size_capacity.gigabytes.to_f
    end
    availability = 0
    availability = (self.upload_graphic_file_size_currently / capa_div) * 100 unless capa_div == 0
    tmp = availability * 100
    tmp = tmp.to_i
    availability = sprintf('%g',tmp.to_f / 100)
    tmp = used * 100
    tmp = tmp.to_i
    used = sprintf('%g',tmp.to_f / 100)
    used = used.to_s + self.upload_graphic_file_size_capacity_unit
    return (capa_div < self.upload_graphic_file_size_currently)
  end

  def menu_item_path
    "/doclibrary/doc?title_id=#{self.id}"
  end

  def group_folders_path
    "/doclibrary/" + "group_folders?title_id=#{self.id}"
  end

  def categorys_path
    "/doclibrary/" + "categories?title_id=#{self.id}"
  end

  def new_uploads_path
    "/doclibrary/" + "docs/new?title_id=#{self.id}"
  end

  def docs_path
    "/doclibrary/" + "docs?title_id=#{self.id}"
  end

  def adm_docs_path
    "/doclibrary/" + "adms?title_id=#{self.id}"
  end

  def date_index_display_states
    {'0' => '使用する', '1' => '使用しない'}
  end

  class << self

    # === 新着情報取得メソッド
    #  新着情報に表示する未承認の承認依頼と未読の承認が完了したファイル情報を取得する
    # ==== 引数
    #  * user_id: ユーザーID
    #  * sort_key: 並び替えするKey（日付／概要）
    #  * order: 並び順（昇順／降順）
    # ==== 戻り値
    #  ファイル情報(Hashオブジェクト)
    def remind(user_id, sort_key, order)
      return Gw::Reminder::to_rumi_format(Gw::Reminder.extract_doclibrary(user_id, sort_key, order))
    end

    # === 通知件数取得メソッド
    #  ログインユーザーへの未承認の承認依頼とログインユーザーの公開待ち(未読の承認が完了したファイル)の件数を取得する
    # ==== 引数
    #  * user_id: ユーザーID
    # ==== 戻り値
    #  通知件数(整数)
    def notification(user_id)
      return Gw::Reminder.extract_doclibrary(user_id, nil, nil).count
    end

  end

end