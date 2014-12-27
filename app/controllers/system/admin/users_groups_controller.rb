# encoding: utf-8
class System::Admin::UsersGroupsController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  layout "admin/template/admin"

  before_filter :editable_group!, only: [:show, :edit, :update, :destroy]
  before_filter :readable_group!, only: [:index]
  before_filter :set_groups_user, only: [:new, :create, :edit, :update]

  def initialize_scaffold
    @current_no = 2
    id      = params[:parent] == '0' ? System::Group.root_id : params[:parent]
    @parent = System::Group.find_by_id(id)
    return http_error(404) if @parent.blank?
    params[:limit] = Gw.nz(params[:limit],30)
    Page.title = "ユーザー・グループ管理"
    @role_admin      = System::User.is_admin?
    @role_editor = System::User.is_editor?
    @role_editable = @role_admin || @role_editor
    return authentication_error(403) unless @role_editable
  end

  # === 管理グループに設定された所属に含まれるグループか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  authentication_error(403)
  def editable_group!
    users_group = System::UsersGroup.where(rid: params[:id]).first
    is_editable_group = users_group && Site.user.editable_group_in_system_users?(users_group.group_id)
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

  # === 管理グループに設定された所属をセットするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_groups_user
    @groups = System::Group.without_root.without_disable.extract_readable_group_in_system_users
    @disabled_group_ids = Site.user.uneditable_group_ids_in_system_users(@groups)
    @any_group_ids = @groups.extract_any_group.map(&:id)

    # 管理グループに設定された所属に属するユーザーのみ表示する
    @users = System::User.without_disable.extract_editable_user_in_system_users(Site.user.id)
  end

  def index
    # 管理グループが階層レベル3のグループのみの場合は、その親グループは
    # 表示可能だか、ユーザーは閲覧できない。
    if Site.user.editable_group_in_system_users?(@parent.id)
      # 並び順をユーザーのdefault_scopeと同様(ユーザーの表示順 > ユーザーコードの昇順)にする
      item = System::UsersGroup.unscoped.where(group_id: @parent.id).order_user_default_scope
      @items = item.paginate(page: params[:page], per_page: params[:limit])
    else
      @items = []
    end

    _index @items
  end

  def show
    @item = System::UsersGroup.new.find(params[:id])
    _show @item
  end

  def new
    # 新規作成ボタンをクリックした時の親グループ管理グループでなかったらnilを初期値とする
    if Site.user.editable_group_in_system_users?(@parent.id)
      init_group_id = @parent.id
    else
      init_group_id = nil
    end

    @item = System::UsersGroup.new({
      :job_order => 0,
      :start_at  => Time.now,
      :group_id => init_group_id
    })

    # 新規作成ボタンをクリックした時の親グループ管理グループでなかったらnilを初期値とする
    unless params[:user_id].nil?
      @item.user_id = params[:user_id]
    end
  end

  def create
    @item = System::UsersGroup.new(params[:item])
    _create @item
  end

  def edit
    @item = System::UsersGroup.new.find(params[:id])
  end

  def update
    @item = System::UsersGroup.new.find(params[:id])
    @item.attributes = params[:item]
    _update @item
  end

  def destroy
    @item = System::UsersGroup.new.find(params[:id])
    _destroy @item
  end

  def item_to_xml(item, options = {})
    options[:include] = [:user]
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
