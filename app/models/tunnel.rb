class Tunnel < ApplicationRecord
  belongs_to :user

  before_create :generate_token
  before_create :generate_subdomain

  enum :status, { inactive: "inactive", active: "active" }, default: :inactive

  private

  def generate_token
    self.token = SecureRandom.hex(16)
  end

  def generate_subdomain
    self.subdomain = SecureRandom.alphanumeric(8).downcase
  end
end
