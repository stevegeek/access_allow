# frozen_string_literal: true

class User < ::ActiveRecord::Base
  has_many :permissions

  def admin?
    role == "admin"
  end
end
