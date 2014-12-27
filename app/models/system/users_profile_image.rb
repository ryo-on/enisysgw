# encoding: utf-8
class System::UsersProfileImage < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Base::Content

  belongs_to :user, :foreign_key => :user_id, :class_name => 'System::User'

  def deletable?
    return true
  end

  def _size
    path = "public#{self.path}"
    size = ''
    if File.exists?(path) && File.stat(path).ftype == 'file'
      s = File.stat path
      siz = s.size.to_f
      case
      when siz > 1.kilobytes
        size += "#{(siz / 1.kilobytes).round 1}KB"
      when siz > 1.megabytes
        size += "#{(siz / 1.megabytes).round 1}MB"
      else
        size += "#{siz}"
      end
      require 'RMagick'
      img = Magick::ImageList.new(path) rescue nil
      size += !img.nil? ? "(#{img.columns}x#{img.rows})" : ''
    end
    nz(size)
  end
end