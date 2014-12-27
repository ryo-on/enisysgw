# encoding: utf-8
module Gw::Controller::Image
  def _image_create(model_image, image_name, module_name, genre_name, params, options={})
    parent_id = params[:id]
    genre_name_prefix = nz(options[:genre_name_prefix])
    qs = Gw.join(@image_upload_qsa, '&amp;')
    qs = qs.blank? ? '' : "?#{qs}"
    redirect_uri = "/#{module_name}/#{("#{[genre_name_prefix,genre_name].delete_if{|x| x.nil?}.join('_')}").pluralize}/#{parent_id}/upload#{qs}"

    params[:item].delete :id
    params[:item][:parent_id] = parent_id
    idx = nz(model_image.maximum(:idx, :conditions => "parent_id = #{parent_id}"),0) + 1
    params[:item][:idx] = idx
    file = params[:item][:upload]

    unless file.blank?
      params[:item][:orig_filename] = file.original_filename
      content_type = file.content_type
      if /^image\// !~ content_type
        flash[:notice] = '画像以外はアップロードできません。'
        redirect_to redirect_uri
        return
      end

      params[:item][:content_type] = file.content_type
      path = %Q(/_common/modules/#{("#{[module_name,genre_name_prefix,genre_name].delete_if{|x| x.nil?}.join('_')}").pluralize}/#{parent_id}/#{idx}#{File.extname file.original_filename})
      params[:item][:path] = path
      filepath = RAILS_ROOT
      filepath += '/' unless filepath.ends_with?('/')
      filepath += "public#{path}"

      unless Gw.mkdir_for_file filepath
        flash[:notice] = 'ディレクトリの作成に失敗しました。'
        redirect_to redirect_uri
        return
      end
      File.open(filepath, 'wb') { |f| f.write file.read }
    else
      flash[:notice] = '添付画像ファイルを選択してください。'
      redirect_to redirect_uri
      return
    end
    params[:item].delete :upload
    item = model_image.new(params[:item])
    _create item, :success_redirect_uri=>redirect_uri, :notice => "#{image_name}の追加に成功しました。"
  end

  def _profile_image_create(model_image, image_name, module_name, params)
    parent_id = params[:user_id]
    user_code = params[:user_code]
    redirect_uri = "/#{module_name}/#{user_code}/profile_upload"
    module_forder_name = "system_users_profile"

    file = params[:upload]

    unless file.blank?
      params[:orig_filename] = file.original_filename
      content_type = file.content_type
      if /^image\// !~ content_type
        flash[:notice] = I18n.t("rumi.system.user.user_profile.error_message.no_image")
        redirect_to redirect_uri
        return
      end

      params[:content_type] = file.content_type
      path = %Q(/_common/modules/#{module_forder_name}/#{user_code}/#{1}#{File.extname file.original_filename})
      params[:path] = path
      filepath = RAILS_ROOT
      filepath += '/' unless filepath.ends_with?('/')
      filepath += "public#{path}"

      File.delete(filepath) if File.exist?(filepath)
      unless Gw.mkdir_for_file filepath
        flash[:notice] = I18n.t("rumi.system.user.user_profile.error_message.fail_mkdir")
        redirect_to redirect_uri
        return
      end
      File.open(filepath, 'wb') { |f| f.write file.read }
    else
      flash[:notice] = I18n.t("rumi.system.user.user_profile.error_message.no_file")
      redirect_to redirect_uri
      return
    end
    params.delete :upload
    profile_image_item = model_image.new.find(:first, :conditions => {:user_code => params[:user_code]})
    if profile_image_item.present?
      profile_image_item.destroy
    end
    profile_image_item = model_image.new(params)
    _create profile_image_item, :success_redirect_uri=>redirect_uri, :notice => "#{image_name}" + I18n.t("rumi.system.user.user_profile.success_message.upload_create")
  end

  def _image_destroy(model_image, image_name, module_name, genre_name, params, options={})
    _img_id = params[:id]
    item = model_image.find(_img_id)

    genre_name_prefix = nz(options[:genre_name_prefix])
    qs = Gw.join(@image_upload_qsa, '&amp;')
    qs = qs.blank? ? '' : "?#{qs}"

    redirect_uri = "/#{module_name}/#{("#{[genre_name_prefix,genre_name].delete_if{|x| x.nil?}.join('_')}").pluralize}/#{item.parent_id}/upload#{qs}"
    _destroy item, :success_redirect_uri => redirect_uri, :notice => "#{image_name}の削除に成功しました。"
  end
  def _prop_image_destroy(model_image, image_name, module_name, genre_name, params, options={})
    _img_id = params[:id]
    item = model_image.find_by_id(_img_id)
    path = "#{RAILS_ROOT}/public#{item.path}"
    File.delete(path) if File.exist?(path)
    genre_name_prefix = nz(options[:genre_name_prefix])
    qs = Gw.join(@image_upload_qsa, '&amp;')
    qs = qs.blank? ? '' : "?#{qs}"
    redirect_uri = "/#{module_name}/#{("#{[genre_name_prefix,genre_name].delete_if{|x| x.nil?}.join('_')}").pluralize}/#{item.parent_id}/upload#{qs}"
    _destroy item, :success_redirect_uri => redirect_uri, :notice => "#{image_name}の削除に成功しました。"
  end
  
  def _profile_image_destroy(model_item, image_name, module_name)
    user_code = model_item.user_code

    redirect_uri = "/#{module_name}/#{user_code}/profile_upload"
    path = "#{RAILS_ROOT}/public#{model_item.path}"
    File.delete(path) if File.exist?(path)
    _destroy model_item, :success_redirect_uri => redirect_uri, :notice => "#{image_name}" + I18n.t("rumi.system.user.user_profile.success_message.upload_delete")
  end
private
  def get_redirect_uri_for_image(model_image, image_name, module_name, genre_name, params, options={})

  end
end
