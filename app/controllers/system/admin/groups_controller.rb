# encoding: utf-8
class System::Admin::GroupsController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  layout "admin/template/admin"

  before_filter :creatable_child_group!, only: [:new, :create]
  before_filter :editable_group!, only: [:show, :edit, :update, :destroy]
  before_filter :readable_group!, only: [:index]
  after_filter :add_editable_group, only: [:create]

  def initialize_scaffold
    @current_no = 2
    @action = params[:action]
    if params[:parent].blank? || params[:parent] == '0'
      parent_id = System::Group.root_id
    else
      parent_id = params[:parent]
    end
    @parent = System::Group.find_by_id(parent_id)
    @parent_groups = System::Group.where(level_no: @parent.level_no, state: 'enabled')
    return http_error(404) if @parent.blank?
    Page.title = "ユーザー・グループ管理"
    @role_admin = System::User.is_admin?
    @role_editor = System::User.is_editor?
    @role_editable = @role_admin || @role_editor
    return authentication_error(403) unless @role_editable
  end

  # === 管理グループに設定された所属、かつ階層レベルが2以上のグループか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def creatable_child_group!
    is_creatable_child_group = Site.user.creatable_child_group_in_system_users?(@parent.id)
    return authentication_error(403) unless is_creatable_child_group
  end

  # === 管理グループに設定された所属に含まれるグループか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def editable_group!
    is_editable_group = Site.user.editable_group_in_system_users?(params[:id])
    return authentication_error(403) unless is_editable_group
  end

  # === 管理グループに設定された所属 + それらの親グループか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def readable_group!
    is_readable_group = Site.user.readable_group_in_system_users?(@parent.id)
    return authentication_error(403) unless is_readable_group
  end

  def index
    params[:state] = params[:state].presence || 'enabled'

    item = System::Group.new
    item.and :parent_id, @parent.id
    item.and :ldap, params[:ldap] if params[:ldap] && params[:ldap] != 'all'
    item.and :state, params[:state] if params[:state] && params[:state] != 'all'
    item.page params[:page], params[:limit]
    @items = item.find(:all)

    # 管理グループに設定された所属 + 親グループのみ表示する
    @items = @items.extract_readable_group_in_system_users

    _index @items
  end

  def show
    @item = System::Group.new.find(params[:id])
    _show @item
  end

  def new
    @item = System::Group.new({
        :parent_id    =>  @parent.id,
        :state        =>  'enabled',
        :level_no     =>  @parent.level_no.to_i + 1,
        :version_id   =>  @parent.version_id.to_i,
        :start_at     =>  Time.now.strftime("%Y-%m-%d 00:00:00"),
        :sort_no      =>  @parent.sort_no.to_i ,
        :ldap_version =>  nil,
        :ldap         =>  0,
        :category     =>  0
    })
  end

  def create
    @item = System::Group.new(params[:item])
    @item.parent_id     = @parent.id
    @item.level_no      = @parent.level_no.to_i + 1
    @item.version_id    = @parent.version_id.to_i
    @item.ldap_version  = nil

    _create @item
  end

  def add_editable_group
    # 保存済み、かつシステム管理者でない場合は管理グループを追加する
    if @item.persisted? && !Site.user.system_admin?
      # 運用管理者であれば、自身の権限に付加されている管理グループに
      # 今回、新規作成したグループを追加する。
      if Site.user.system_users_editor?
        editor_role = Site.user.system_users_editor_role
        editor_role.add_editable_group_json(@item)
      end
    end
  end

  def update
    @item = System::Group.new.find(params[:id])
    @item.attributes = params[:item]
    _update @item
  end

  def destroy
    @item = System::Group.new.find(params[:id])
    # 所属するユーザーが存在する場合は不可
    # 下位に有効な所属が存在する場合は不可
    if !@item.has_enable_child_or_users_group?
      @item.state  = 'disabled'
      @item.end_at = Time.now.strftime("%Y-%m-%d 00:00:00")
      _update @item,{:success_redirect_uri=>url_for(:action=>'show'),:notice=>'無効にしました。'}
    else
      flash[:notice] = flash[:notice]||'ユーザーが所属しているか、下位に有効な所属があるときは、無効にできません。'
      redirect_to :action=>'show'
    end
  end
  
  def item_to_xml(item, options = {})
    options[:include] = [:status]
    xml = ''; xml << item.to_xml(options) do |n|
    end
    return xml
  end

  def list
    return authentication_error(403) unless @role_editable
    Page.title = "ユーザー・グループ 全一覧画面"

    # 管理グループに設定された所属 + 親グループにおいて階層レベル2のみ抽出する
    @groups = System::Group.extract_level_no_2.extract_readable_group_in_system_users
  end
  
end
