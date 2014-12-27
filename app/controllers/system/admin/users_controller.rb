# encoding: utf-8
class System::Admin::UsersController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  include Gw::Controller::Image
  layout "admin/template/admin"

  before_filter :editable_user!, only: [:show, :edit, :update, :destroy]
  before_filter :set_groups, only: [:new, :create]

  def initialize_scaffold
    return redirect_to(request.env['PATH_INFO']) if params[:reset]
  end

  # === 管理グループに設定された所属に属するユーザーか評価するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def editable_user!
    is_editable_user = Site.user.editable_user_in_system_users?(params[:id])
    return authentication_error(403) unless is_editable_user
  end

  # === 管理グループに設定された所属をセットするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_groups
    @groups = System::Group.without_root.without_disable.extract_readable_group_in_system_users
    @disabled_group_ids = Site.user.uneditable_group_ids_in_system_users(@groups)
    @any_group_ids = @groups.extract_any_group.map(&:id)
  end

  def index
    init_params
    return authentication_error(403) unless @u_role

    params[:state] = params[:state].presence || 'enabled'
    item = System::User.new
    item.search params

    item.and :ldap, params[:ldap] if params[:ldap] && params[:ldap] != 'all'
    item.and :state, params[:state] if params[:state] && params[:state] != 'all'
    item.page params[:page], nz(params[:limit], 30)
    @items = item.find(:all)

    # 管理グループに設定された所属に属するユーザーのみ表示する
    @items = @items.extract_editable_user_in_system_users(Site.user.id)

    _index @items
  end

  def show
    init_params
    return authentication_error(403) unless @u_role
    @item = System::User.new.find(params[:id])

  end

  def new
    init_params
    return authentication_error(403) unless @u_role

    @item = System::User.new({
      :state => 'enabled',
      :ldap => '0',
      :sort_no => 100
    })
  end

  def create
    init_params
    return authentication_error(403) unless @u_role

    @item = System::User.new(params[:item])

    options = {
      :location => system_users_path,
      :params => params
    }

    begin
      ActiveRecord::Base.transaction do
        # System::User
        @item.save!
        # System::UsersGroup
        @users_group = System::UsersGroup.new(params[:ug])
        @users_group.user_id = @item.id
        @users_group.save!
        # System::UsersGroupHistory
        users_groups_history = System::UsersGroupHistory.new(params[:ug])
        users_groups_history.user_id = @item.id
        users_groups_history.save!
      end

      # 登録が完了した場合
      flash[:notice] = '登録処理が完了しました。'
      status = params[:_created_status] || :created
      options[:location] ||= url_for(:action => :index)
      respond_to do |format|
        format.html { redirect_to options[:location] }
        format.xml  { render :xml => @item.to_xml(:dasherize => false), :status => status, :location => url_for(:action => :index) }
      end

    # 登録に失敗した場合
    rescue
      flash.now[:notice] = '登録処理に失敗しました。'
      respond_to do |format|
        format.html { render :action => :new }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit
    init_params
    return authentication_error(403) unless @u_role
    @item = System::User.new.find(params[:id])
  end

  def update
    init_params
    return authentication_error(403) unless @u_role

    @item = System::User.new.find(params[:id])
    @item.attributes = params[:item]
    
    location = system_user_path(@item.id)
    options = {
      :success_redirect_uri=>location
      }
    _update(@item, options)
  end

  def destroy
    init_params
    return authentication_error(403) unless @role_editable
    @item = System::User.find_by_id(params[:id])

    if @item.has_uneditable_users_group?
      flash[:notice] = I18n.t("rumi.system.user.state.message.has_uneditable_users_group")
      redirect_to action: :show
    else
      @item.state = 'disabled'
      _update(@item, {:notice => 'ユーザーを無効状態に更新しました。'})
    end
  end
  
  # === CSV仮データ確認
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def csv
    init_params
    return authentication_error(403) unless @role_admin == true

    @csvdata = System::UsersGroupsCsvdata.extract_group.extract_level_no_2
  end

  # === CSV仮データ閲覧
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def csvshow
    init_params
    return authentication_error(403) unless @role_admin == true

    @item = System::UsersGroupsCsvdata.find(params[:id])
  end

  # === CSV仮登録
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def csvup
    init_params
    return authentication_error(403) unless @role_admin == true

    par_item = params[:item] || {}
    case par_item[:csv]
    # フォーム送信情報処理
    when RumiHelper::CsvForm.import_mode
      @item = RumiHelper::CsvForm.new(params[:item])
      if @item.valid?
        begin
          parse_nkf_options = @item.utf8? ? "-w -W" : "-w -S"
          csv_string = NKF::nkf(parse_nkf_options, @item.file.read)

          valid_info = System::UsersGroupsCsvdata.import_csv(csv_string)
          # エラーを検出した場合
          if valid_info[:invalid]
            serialize_nkf_options = @item.utf8? ? "-w -W" : "-s -W"
            invalid_csv_string = Gw::Script::Tool.ary_to_csv(valid_info[:invalid_csv_array])
            invalid_csv_string = NKF::nkf(serialize_nkf_options, invalid_csv_string)

            filename = "#{@item.file.original_filename}_エラー箇所追記.csv"
            filename = NKF::nkf("-s -W", filename) if @ie

            send_data invalid_csv_string, filename: filename, type: "text/csv", disposition: "attachment"
          # 検証OKの場合
          else
            flash.now[:notice] = "正常にインポートされました。"
          end
        rescue
          flash.now[:notice] = "予期せぬエラーが発生しました。ファイル内容と文字コードを確認してください。"
        end
      end
    # CSV仮登録画面表示
    else
      @item = RumiHelper::CsvForm.new_import_mode
    end

  end

  # === CSV出力
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def csvget
    init_params
    return authentication_error(403) unless @role_admin == true

    par_item = params[:item] || {}
    case par_item[:csv]
    # フォーム送信情報処理
    when RumiHelper::CsvForm.export_mode
      @item = RumiHelper::CsvForm.new(params[:item])
      if @item.valid?
        filename = "ユーザー・グループ情報_#{@item.nkf}.csv"
        filename = NKF::nkf('-s -W', filename) if @ie

        csv_string = System::UsersGroupsCsvdata.to_csv
        csv_string = NKF::nkf('-s', csv_string) if @item.sjis?

        send_data csv_string, filename: filename, type: "text/csv", disposition: "attachment"
      end
    # CSV出力画面表示
    else
      @item = RumiHelper::CsvForm.new_export_mode
    end
  end

  # === CSV本登録
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def csvset
    init_params
    return authentication_error(403) unless @role_admin == true

    if params[:item].present? && params[:item][:csv] == 'set'
      _synchro

      if @errors.size > 0
        flash[:notice] = 'Error: <br />' + @errors.join('<br />')
      else
        flash[:notice] = '処理が完了しました'
      end
      redirect_to csvset_system_users_path
    else
      @count = System::UsersGroupsCsvdata.count
    end

  end
  
  def list
    init_params
    return authentication_error(403) unless @role_editable
    Page.title = "ユーザー・グループ 全一覧画面"

    # 管理グループに設定された所属 + 親グループにおいて階層レベル2のみ抽出する
    @groups = System::Group.extract_level_no_2.extract_readable_group_in_system_users
  end

  def init_params
    @current_no = 1
    @role_developer  = System::User.is_dev?
    @role_admin      = System::User.is_admin?
    @role_editor     = System::User.is_editor?
    @u_role = @role_developer || @role_admin || @role_editor
    @role_editable = @role_admin || @role_editor

    @limit = nz(params[:limit],30)

    search_condition

    @css = %w(/layout/admin/style.css)
    Page.title = "ユーザー・グループ管理"
    if params[:action].index("csv").present?
      Page.title = "ユーザー・グループ CSV管理"
    end
    @ie = Gw.ie?(request)
  end

  def search_condition
    params[:limit]        = nz(params[:limit],@limit)

    qsa = ['limit', 's_keyword']
    @qs = qsa.delete_if{|x| nz(params[x],'')==''}.collect{|x| %Q(#{x}=#{params[x]})}.join('&')
  end

  # === CSV本登録マージ処理
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def _synchro
    @errors  = []

    begin
      # 状態が有効でかつシステム管理者のユーザーが仮データに存在するか検証する
      system_admin_users = System::User.system_admin_users
      system_admin_user_codes = system_admin_users.map(&:code)
      provisional_user_codes = System::UsersGroupsCsvdata.without_disable.extract_user.map(&:code)
      # 仮データにシステム管理者が存在しない場合はエラーを発生させる
      not_included_system_admin_user = (system_admin_user_codes - provisional_user_codes) == system_admin_user_codes
      raise I18n.t("rumi.config_settings.base.user_and_group.csv.feature.save.message.errors.not_included_system_admin_user") if not_included_system_admin_user

      # 仮データマージ処理開始
      ActiveRecord::Base.transaction do

        # 終了日の条件、更新値まとめ
        end_at_condition = "end_at > '#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}' or end_at is null"
        end_at_value = "end_at = '#{Time.now.strftime("%Y-%m-%d 00:00:00")}'"

        # 全ユーザーを無効状態にする
        System::User.update_all(state: "disabled")
        # 全ユーザーの所属情報を無効状態にする
        System::UsersGroup.where(end_at_condition).update_all(end_at_value)
        # 全ユーザーの所属情報履歴を無効状態にする
        System::UsersGroupHistory.where(end_at_condition).update_all(end_at_value)

        # rootを除く全グループを無効状態にする
        System::Group.without_root.update_all(state: "disabled")
        System::Group.without_root.update_all(end_at_value)
        # rootを除く全グループ履歴を無効状態にする
        System::GroupHistory.without_root.update_all(state: "disabled")
        System::GroupHistory.without_root.where(end_at_condition).update_all(end_at_value)

        # 階層レベル2のグループと所属ユーザーをマージ
        level_no_2_provisional_groups = System::UsersGroupsCsvdata.extract_group.extract_level_no_2
        level_no_2_provisional_groups.each do |level_no_2_provisional_group|
          # 既存のレコードがあれば上書きする、既存のレコードがなければ新規作成する
          level_no_2_provisional_group.update_or_create_by_system_group!
          level_no_2_provisional_group.users.each do |level_no_2_affiliated_user|
            level_no_2_affiliated_user.update_or_create_by_system_user!
          end
          # 階層レベル3のグループと所属ユーザーをマージ
          level_no_2_provisional_group.groups.each do |level_no_3_provisional_group|
            # 既存のレコードがあれば上書きする、既存のレコードがなければ新規作成する
            level_no_3_provisional_group.update_or_create_by_system_group!
            level_no_3_provisional_group.users.each do |level_no_3_affiliated_user|
              level_no_3_affiliated_user.update_or_create_by_system_user!
            end
          end
        end

      end

    rescue => e
      if e.is_a?(ActiveRecord::RecordInvalid)
        errors_record = e.record
        @errors << errors_record.errors.full_messages.join
        # レコード状況をログに出力する
        Rails.logger.error record_inspect_changed(errors_record)
      else
        @errors << e.message
      end

      # 本番のログでも出力する
      Rails.logger.error "[ERROR] _synchro Invalid Error"
      Rails.logger.error @errors.inspect

    ensure
      # 既存処理のおまじない
      Rails.cache.clear
    end

  end

  # === プロフィール項目管理画面を表示するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def profile_settings
    init_params
    @current_no = 4
    Page.title = I18n.t("rumi.config_settings.base.user_profile_setting.name")
    @role_admin = System::User.is_admin?
    return authentication_error(403) unless @role_admin == true
    @items = System::UsersProfileSetting.find(:all, :order => "id")
  end

  # === プロフィール項目管理情報を更新するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def edit_profile_settings
    init_params
    ret = true
    if params[:item].present?
      params[:item].each do |key, value|
        profile_id = key.slice(5, key.length - 4 ) #name_*, used_*
        item = System::UsersProfileSetting.new.find(profile_id)
        if (key.match(/^name_(\d+)$/))
          item.name = value.strip
        elsif (key.match(/^used_(\d+)$/))
          item.used = value.to_i
        end
        if item.save
        else
          ret = false
        end
      end
    end

    if ret
      flash[:notice] = '更新処理が完了しました'
    else
      flash[:notice] = '更新処理が失敗しました'
    end
    return redirect_to profile_settings_system_users_path
  end

  # === プロフィール画面を表示するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  http_error(404)
  def show_profile
    init_params
    Page.title = I18n.t("rumi.system.user.user_profile.name")
    @item = System::User.new.find(:first, :conditions => {:code => params[:user_code]})
    return http_error(404) unless @item
    @role_editable_profile = role_editable_profile(@item)
    @model = System::UsersProfileSetting
    @is_profile = @item.user_profile.present?
    @is_profile_image = @item.user_profile_image.present?
    @is_add_column_used = @model.add_column_used?
  end

  # === プロフィール編集画面を表示するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403) or http_error(404)
  def edit_profile
    init_params
    Page.title = I18n.t("rumi.system.user.user_profile.name")
    @model = System::UsersProfileSetting
    @is_add_column_used = @model.add_column_used?
    @item = System::User.new.find(:first, :conditions => {:code => params[:user_code]})
    return http_error(404) unless @item
    @role_editable_profile = role_editable_profile(@item)
    return authentication_error(403) unless @role_editable_profile
    return http_error(404) unless @is_add_column_used
    
    @is_profile = @item.user_profile.present?
    if @is_profile
      @profile_item = @item.user_profile
    else
      @profile_item = System::UsersProfile.new({
      :user_id    =>  @item.id,
      :user_code  =>  @item.code
    })
    end
  end

  # === プロフィール情報を更新するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_profile
    init_params
    item = params[:profile_item]

    @profile_item = System::UsersProfile.new.find(:first, :conditions => {:user_code => item[:user_code]})
    if @profile_item.present?
      @profile_item.attributes = params[:profile_item]
    else
      @profile_item = System::UsersProfile.new(params[:profile_item])
    end
    location = "/system/users/#{@profile_item.user_code}/show_profile"
    options = {
      :success_redirect_uri=>location
    }
    _update(@profile_item, options)
  end

  # === プロフィール画像アップロード画面を表示するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403) or http_error(404)
  def profile_upload
    init_params
    Page.title = I18n.t("rumi.system.user.user_profile.name")
    @model = System::UsersProfileSetting
    @item = System::User.new.find(:first, :conditions => {:code => params[:user_code]})
    return http_error(404) unless @item
    @role_editable_profile = role_editable_profile(@item)
    return authentication_error(403) unless @role_editable_profile
    @is_profile = @item.user_profile.present?
    @is_profile_image = @item.user_profile_image.present?
    if @is_profile_image
      @profile_image = @item.user_profile_image
    else
      @profile_image = System::UsersProfileImage.new({
      :user_id    =>  @item.id,
      :user_code  =>  @item.code
    })
    end
  end
  
  # === プロフィール画像情報を登録するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def image_create
    init_params
    item = params[:profile_image]
    @item = System::User.new.find(:first, :conditions => {:code => item[:user_code]})
    return http_error(404) unless @item
    @role_editable_profile = role_editable_profile(@item)
    return authentication_error(403) unless @role_editable_profile
    model_image = System::UsersProfileImage
    item_image_name = I18n.t("rumi.system.user.user_profile.upload_name")
    module_path = 'system/users'
    _profile_image_create model_image, item_image_name, module_path, item
  end

  # === プロフィール画像情報を削除するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def image_destroy
    init_params
    @item = System::User.new.find(:first, :conditions => {:code => params[:user_code]})
    return http_error(404) unless @item
    @role_editable_profile = role_editable_profile(@item)
    return authentication_error(403) unless @role_editable_profile
    model_image = System::UsersProfileImage.where(user_code: params[:user_code]).first
    item_image_name = I18n.t("rumi.system.user.user_profile.upload_name")
    module_path = 'system/users'
    _profile_image_destroy model_image, item_image_name, module_path
  end

  # === プロフィール画面の操作権限の取得
  #
  # ==== 引数
  #  * item: プロフィールユーザー情報
  # ==== 戻り値
  #  なし
  def role_editable_profile(item)
    role_admin  = System::User.is_admin?
    role_editor = System::User.is_editor?
    edit_users = System::User.extract_editable_user_in_system_users(Site.user.id)
    role_user = false
    edit_users.each do |user|
      role_user = true if(item.code == user.code)
    end
    role_editable_profile = role_admin || (role_editor && role_user) || (item.code == Site.user.code)
    return role_editable_profile
  end
end
