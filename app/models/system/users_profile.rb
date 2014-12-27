# encoding: utf-8
class System::UsersProfile < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Base::Content

  belongs_to :user, :foreign_key => :user_id, :class_name => 'System::User'
end
