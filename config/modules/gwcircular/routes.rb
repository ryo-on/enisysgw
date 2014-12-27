EnisysGw::Application.routes.draw do

  scope '_admin' do
    resources 'gwcircular' do
      resources :attachments, 
        :controller => 'gwcircular/admin/attachments' do
          collection do
           get :destroy_by_ids
          end
        end
      resources :export_files, :controller => 'gwcircular/admin/export_files'
    end
  end

  scope '_admin' do
    namespace 'gwcircular' do
      scope :module => 'admin' do
        resources :ajaxgroups do
          collection do
            get :getajax
          end
        end
      end
    end
  end

  mod = "gwcircular"
  scp = "admin"
  namespace mod do
    scope :module => scp do
      resources :itemdeletes
      resources :basics
      resources :settings
      resources :menus do
        collection do
          get :close
        end
      end
      resources :docs do
        member do
          get :edit_show
        end
      end
      resources :custom_groups do
        collection do
          put :sort_update
        end
      end
      resources :csv_exports, :controller => 'menus/csv_exports', :path => ':id/csv_exports' do
          collection do
            put :export_csv
          end
      end
      resources :file_exports, :controller => 'menus/file_exports', :path => ':id/file_exports' do
          collection do
            get :export_file
          end
      end
    end
  end

  match 'gwcircular/menus/:id/circular_publish' => 'gwcircular/admin/menus#circular_publish'
  match 'gwcircular/docs/:id/already_update' => 'gwcircular/admin/docs#already_update'
  match 'gwcircular/forward'       => 'gwcircular/admin/menus#forward'
  match 'gwcircular/new'       => 'gwcircular/admin/menus#new'
  match 'gwcircular'          => 'gwcircular/admin/menus#index'
  match 'gwcircular/docs/:id/gwbbs_forward' => 'gwcircular/admin/docs#gwbbs_forward'
  match 'gwcircular/docs/:id/mail_forward' => 'gwcircular/admin/docs#mail_forward'
  match 'gwcircular/menus/:id/gwbbs_forward' => 'gwcircular/admin/menus#gwbbs_forward'
  match 'gwcircular/menus/:id/mail_forward' => 'gwcircular/admin/menus#mail_forward'
end
