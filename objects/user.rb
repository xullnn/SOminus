class User < SOMBase
  attr_accessor :name, :id, :password

  def self.create(params)
    params["password"] = BCrypt::Password.create(params[:password])
    super(params)
  end
end
