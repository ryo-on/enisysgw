# encoding: utf-8
class Gw::Admin::PropOthersController < Gw::Admin::PropGenreCommonController
  include System::Controller::Scaffold
  include Gw::RumiHelper
  layout "admin/template/schedule"

  before_filter :set_groups_user, only: [:new, :create, :edit, :update]

  def initialize_scaffold
    super
    @genre = 'other'
    @model = Gw::PropOther
    @model_image = Gw::PropOtherImage
    @uri_base = '/gw/prop_others'
    @item_name = '施設'
    Page.title = "施設マスタ"
    #現状の@prop_typesを施設グループも含めるようにする
    @prop_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no, id')

    #施設マスタ権限を持つユーザーかの情報
    @schedule_prop_admin = Gw.is_other_admin?('schedule_prop_admin')
    @is_gw_admin = (@is_gw_admin || @schedule_prop_admin)
    gids = Array.new
    Core.user.groups.each do |group|
      gids << group.id
      gids << group.parent_id
    end
    @prop_other_admin = false
    if gids.present?
      gids.uniq!
      @search_gids = Gw.join([gids], ',')
      cond = " auth='admin' and gid in (#{@search_gids}) "
      auth_admin = Gw::PropOtherRole.find(:all, :conditions => cond)
      @prop_other_admin = true if auth_admin.present?
    end
  end

  # === 初期値のグループ、ユーザー情報
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_groups_user
    @parent_group_id = Core.user_group.parent_id
    @group_child_groups = System::Group.child_groups_to_select_option(@parent_group_id)
  end

  def get_index_items
    @s_admin_group = Gw::PropOtherRole.get_search_select("admin", (@is_gw_admin || @schedule_prop_admin))
  end

  def index
    init_params
    return authentication_error(403) unless @is_gw_admin || @schedule_prop_admin || @prop_other_admin
    get_index_items
    item = @model.new
    item.page  params[:page], params[:limit]

    @prop_types = select_prop_type
    @prop_types += select_prop_group_tree('partition')
    prop_type_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no, id')

    if params[:s_type_id].present?
      @type_id = params[:s_type_id]
    else
      if prop_type_types.present?
        @type_id = @prop_types[0]
        match_type_id = @type_id[1].match(/^type_(\d+)$/)
        @default_type_id = match_type_id[1]
      end
    end

    cond = "delete_state = 0"
    if(params[:s_type_id]).present?
      if (match_result = params[:s_type_id].match(/^groups_(\d+)$/))
        s_type_id = match_result
        @s_type_id = s_type_id[1].to_i
        @group_set = Gw::PropGroupSetting.find(:all, :conditions => ["prop_group_id=?", [@s_type_id]], :select => "prop_other_id")
        if @group_set.blank?
          cond += " and gw_prop_others.id=0 "
        else
          cond += " and ("
          cnt=0
          @group_set.each do | set|
            cond += " or " if cnt!=0
            cnt=1
            cond += "gw_prop_others.id = #{set.prop_other_id}"
          end
          cond += ")"
        end
      elsif (match_result = params[:s_type_id].match(/^type_(\d+)$/))
        s_type_id = match_result
        @s_type_id = s_type_id[1].to_i
        cond += " and type_id = #{@s_type_id}"
      else
        @s_type_id = @default_type_id.to_i
        cond += " and type_id = #{@s_type_id}"
      end
    else
      @s_type_id = @default_type_id.to_i
      cond += " and type_id = #{@s_type_id}"
    end
    @s_admin_gid = nz(params[:s_admin_gid], "0").to_i

    if @s_admin_gid != 0 && (@is_gw_admin || @schedule_prop_admin)
      cond_other_admin = ""
      s_other_admin_group = System::GroupHistory.find_by_id(@s_admin_gid)
      s_other_admin_group
      cond_other_admin = "  "
      if s_other_admin_group.level_no == 2
        gids = Array.new
        gids << @s_admin_gid
        parent_groups = System::GroupHistory.new.find(:all, :conditions => ['parent_id = ?', @s_admin_gid])
        parent_groups.each do |parent_group|
          gids << parent_group.id
        end
        search_group_ids = Gw.join([gids], ',')
        cond_other_admin += " and (auth = 'admin' and  gw_prop_other_roles.gid in (#{search_group_ids}))"
      else
        cond_other_admin += " and (auth = 'admin' and  gw_prop_other_roles.gid = #{s_other_admin_group.id})"
      end
      cond += cond_other_admin
    elsif !(@is_gw_admin || @schedule_prop_admin)
      if @search_gids.blank?
        cond += " and auth = 'admin' and ((gw_prop_other_roles.gid = #{Site.user_group.id}) or (gw_prop_other_roles.gid = 0))" if !(@is_gw_admin || @schedule_prop_admin)
      else
        cond += " and auth = 'admin' and (gw_prop_other_roles.gid in (#{@search_gids}) or (gw_prop_other_roles.gid = 0))" if !(@is_gw_admin || @schedule_prop_admin)
      end
    end

    @items = item.find(:all, :conditions=>cond,
            :joins => :prop_other_roles, :group => "prop_id")

    parent_groups = Gw::PropOther.get_parent_groups

    @items.sort!{|a, b|
        ag = System::GroupHistory.find_by_id(a.get_admin_first_id(parent_groups))
        bg = System::GroupHistory.find_by_id(b.get_admin_first_id(parent_groups))
        flg = (!ag.blank? && !bg.blank?) ? ag.sort_no <=> bg.sort_no : 0
        (b.reserved_state <=> a.reserved_state).nonzero? or (a.type_id <=> b.type_id).nonzero? or (flg).nonzero? or a.sort_no <=> b.sort_no
    }
  end

  def new
    init_params
    return authentication_error(403) unless @is_gw_admin || @schedule_prop_admin

    @item = @model.new({})
    @prop_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no, id')

    base_groups_json = []
    base_groups_json << Core.user_group.to_json_option if @group_child_groups.map(&:id).include?(Core.user_group.id)
    base_groups_json = base_groups_json.to_json

    @admin_json = base_groups_json
    @editors_json = base_groups_json
    @readers_json = []
  end

  def show
    init_params
    @item = @model.find(params[:id])

    if @item.delete_state == 1
      if @genre == 'other'
        return authentication_error(404) unless @is_admin
        #raise 'この施設は削除されています。'
      end
    end

    @is_other_admin = Gw::PropOtherRole.is_admin?(params[:id])
  end

  def create
    init_params
    return authentication_error(403) unless @is_admin
    #raise '管理者権限がありません。' if !@is_admin
    @item = @model.new()

    if @item.save_with_rels params, :create
      flash_notice '一般施設の登録', true
      redirect_to "#{@uri_base}?cls=#{@cls}"
    else
      respond_to do |format|
        format.html { render :action => "new" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    init_params
    return authentication_error(403) unless @is_admin || @schedule_prop_admin || @prop_other_admin
    #raise '管理者権限がありません。' if !@is_admin
    @item = @model.find(params[:id])
    if @item.save_with_rels params, :update
      flash_notice '一般施設の編集', true
      redirect_to "#{@uri_base}?cls=#{@cls}"
    else
      respond_to do |format|
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit
    init_params
    parent_groups = Gw::PropOther.get_parent_groups
    @prop_types = Gw::PropType.find(:all, :conditions => ["state = ?", "public"], :select => "id, name", :order => 'sort_no, id')
    @item = @model.find(params[:id])
    return authentication_error(403) unless @is_admin || @schedule_prop_admin || @prop_other_admin
    #raise '管理者権限がありません。' if !@is_admin

    @admin_json = @item.admin(:select, parent_groups).to_json
    @editors_json = @item.editor(:select, parent_groups).to_json
    @readers_json = @item.reader(:select, parent_groups).to_json
  end

  class DummyItem
    attr_accessor  :id, :name
  end
  
  # === 施設マスタインポートメソッド
  #  本メソッドは施設マスタのCSVインポートを行うメソッドである。
  # ==== 引数
  #  無し
  # ==== 戻り値
  #  無し
  def import
    init_params
    return authentication_error(403) unless @is_gw_admin || @schedule_prop_admin
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    Page.title = 'インポート'
  end

  # === 施設マスタエクスポートメソッド
  #  本メソッドは施設マスタのCSVエクスポートを行うメソッドである。
  # ==== 引数
  #  無し
  # ==== 戻り値
  #  無し
  def export
    init_params
    return authentication_error(403) unless @is_gw_admin || @schedule_prop_admin
    get_index_items
    item = @model.new

    @s_type_id = nz(params[:s_type_id], "0").to_i
    @s_admin_gid = nz(params[:s_admin_gid], "0").to_i

    cond = "delete_state = 0"
    cond += " and type_id = #{@s_type_id}" if @s_type_id != 0

    if @s_admin_gid != 0 && (@is_gw_admin || @schedule_prop_admin)
      cond_other_admin = ""
      s_other_admin_group = System::GroupHistory.find_by_id(@s_admin_gid)
      s_other_admin_group
      cond_other_admin = "  "
      if s_other_admin_group.level_no == 2
        gids = Array.new
        gids << @s_admin_gid
        parent_groups = System::GroupHistory.new.find(:all, :conditions => ['parent_id = ?', @s_admin_gid])
        parent_groups.each do |parent_group|
          gids << parent_group.id
        end
        search_group_ids = Gw.join([gids], ',')
        cond_other_admin += " and (auth = 'admin' and  gw_prop_other_roles.gid in (#{search_group_ids}))"
      else
        cond_other_admin += " and (auth = 'admin' and  gw_prop_other_roles.gid = #{s_other_admin_group.id})"
      end
        cond += cond_other_admin
    elsif !(@is_gw_admin || @schedule_prop_admin)
        cond += " and auth = 'admin' and ((gw_prop_other_roles.gid = #{Site.user_group.id}) or (gw_prop_other_roles.gid = 0))" if !(@is_gw_admin || @schedule_prop_admin)
    end

    @items = item.find(:all, :conditions=>cond,
            :joins => :prop_other_roles, :group => "prop_id")

    parent_groups = Gw::PropOther.get_parent_groups

    @items.sort!{|a, b|
        ag = System::GroupHistory.find_by_id(a.get_admin_first_id(parent_groups))
        bg = System::GroupHistory.find_by_id(b.get_admin_first_id(parent_groups))
        flg = (!ag.blank? && !bg.blank?) ? ag.sort_no <=> bg.sort_no : 0
        (b.reserved_state <=> a.reserved_state).nonzero? or (a.type_id <=> b.type_id).nonzero? or (flg).nonzero? or a.sort_no <=> b.sort_no
    }

    csv_field = '"種別","名称"' + "\n"
    csv = ""
    @items.each_with_index{ | item, cnt |
      name = item.name
      type_name = item.prop_type.name

      name = name.gsub('"', '""') unless name.blank?
      type_name = type_name.gsub('"', '""') unless type_name.blank?

      csv += "\"#{type_name}\",\"#{name}\"" + "\n"
    }

    if params[:nkf].blank?
      nkf_options = '-Lws'
    else
      nkf_options = case params[:nkf]
      when 'utf8'
        '-w'
      when 'sjis'
        '-Lws'
      end
    end

    filename = "prop_other_lists.csv"
    send_data(NKF::nkf(nkf_options, csv_field + csv), :type => 'text/csv', :filename => filename)

    #send_data(ical, :type => 'text/csv', :filename => filename)

    #send_download "#{filename}", ical
  end


  # === 施設マスタインポートメソッド
  #  本メソッドは施設マスタのCSVインポートを行うメソッドである。
  # ==== 引数
  #  無し
  # ==== 戻り値
  #  無し
  def import_file
    init_params
    Page.title = "インポート - #{Page.title}"
    @css = %w(/_common/themes/gw/css/prop_extra/schedule.css)
    par_item = params[:item]

    if par_item.nil? || par_item[:file].nil?
      flash[:notice] = 'ファイル名を入力してください<br />'
      respond_to do |format|
        format.html { render :action => "import" }
      end
      return
    end

    # CSVファイル取得
    filename =  par_item[:file].original_filename
    extname = File.extname(filename)
    tempfile = par_item[:file].open

    success = 0
    error = 0
    invalid = 0
    error_msg = ''

    # 拡張子確認
    if extname != '.csv'
      flash[:notice] = '拡張子がCSV形式のものと異なります。拡張子が「csv」のファイルを指定してください。<br />'
      respond_to do |format|
        format.html { render :action => "import" }
      end
      return
    end

    require 'csv'
    return if params[:item].nil?
    par_item = params[:item]

    file_data =  NKF::nkf('-w -Lu',tempfile.read)
    csv_result = Array.new

    # ファイルが空
    if file_data.blank?
    else
      csv = CSV.parse(file_data)

      parent_groups = System::GroupHistory.new.find(:all, :conditions =>"level_no = 2", :order=>"sort_no , code, start_at DESC, end_at IS Null ,end_at DESC")
      json = []
      json.push ["", Site.user_group.id, Site.user_group.name]
      json = json.to_json
      @admin_json = json
      @editors_json = json

      csv.each_with_index do |row, i|
        _params = Hash::new
        _params[:item] = Hash::new
        item = @model.new
        if i == 0
        elsif row.length == 2
          # 施設種別を取得する
          prop_types = Gw::PropType.find(:all, :conditions => ["state = ? AND name = ?", "public", row[0]], :select => "id, name")
          unless prop_types.length == 0
            _params[:item][:sort_no] = ""
            _params[:item][:name] = "#{row[1]}"
            _params[:item][:type_id] = "#{prop_types[0].id}"
            _params[:item][:state] = ""
            _params[:item][:edit_state] = ""
            _params[:item][:delete_state] = ""
            _params[:item][:reserved_state] = 0
            _params[:item][:comment] = ""
            _params[:item][:created_at] = 'now()'
            _params[:item][:updated_at] = ""
            _params[:item][:extra_flag] = ""
            _params[:item][:extra_data] = ""
            _params[:item][:gid] = Site.user_group.id
            _params[:item][:gname] = Site.user_group.name
            _params[:item][:creator_uid] = Site.user.id
            _params[:item][:updater_uid] = ""
            _params[:item][:admin_json] = @admin_json
            _params[:item][:editors_json] = @editors_json
            _params[:item][:readers_json] = @readers_json
            # 未登録の場合は登録を行う
            items = item.find(:all, :conditions=> ["name = ? AND type_id = ?", row[1], prop_types[0].id])
            if items.length == 0
              if item.save_with_rels_csv _params, :create
                success += 1

              else
                error += 1
                _csv = row.join(",") + ","
                _csv += item.errors.full_messages.join(",")
                csv_result << _csv
              end
            else
              invalid += 1
            end
            
          else
            error += 1
            _csv = row.join(",") + ","
            _csv += "存在しない施設種別が指定されています。"
            csv_result << _csv
          end
        else
          _csv = row.join(",") + ","
          _csv += '項目数に誤りがあります。'
          csv_result << _csv
          error += 1
        end
      end
    end
    
    # エラーが存在した場合CSVダウンロード
    if error > 0
      filename += "_result.csv"
      csv_field = '"種別","名称"' + "\n"
      send_data(NKF::nkf('-Lws', csv_field + csv_result.join("\n")), :type => 'text/csv', :filename => filename)
      
    # エラーが存在しなかった場合
    else
      _error_msg = 'インポート処理が完了しました。<br />'+
        '------結果-----<br />' +
        '有効' + success.to_s + '件を登録し、無効' + invalid.to_s + '件は無視しました。<br />'

      if success > 0
        flash[:notice] = _error_msg
        redirect_to "/gw/prop_others"
      else
        flash[:notice] = _error_msg
        respond_to do |format|
          format.html { render :action => "import" }
        end
      end
    end
  end
end
