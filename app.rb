require 'sinatra'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'

if development?
  require 'pry'
  require 'sinatra/reloader'
end

configure do
  enable :sessions
  set :session_secret, "secret"
end

get "/" do
  erb :index
end

get "/users/new" do
  erb :signup
end

post "/users/signup" do
  username, password = params[:username].strip, params[:password].strip
  check_name_uniqueness(username)
  if invalid_name_and_password?(username, password)
    status 422
    erb(:signup)
  else
    register_user(username, password)
    session[:message] = "Signed up successfully."
    redirect "/"
  end
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username, password = params[:username].strip, params[:password].strip
  validate_user_credential(username, password)
  session[:signed_in_as] = username
  session[:message] = "Successfully signed in as \"#{username}\"."
  redirect "/"
end

post "/users/signout" do
  session.delete(:signed_in_as)
  session[:message] = "Successfully signed out."
  redirect "/"
end

private

  def check_name_uniqueness(username)
    return unless load_user_credentials
    if load_user_credentials[username]
      session[:message] = "Name \"#{username}\" has been taken. Please choose another one."
      status 422
      halt erb(:signup)
    end
  end

  def validate_user_credential(username, password)
    user_list = load_user_credentials
    user = user_list[username]
    unless user && BCrypt::Password.new(user["password"]) == password
      status 422
      session[:message] = "Wrong user name or password"
      halt erb(:signin)
    end
  end

  def register_user(username, password)
    File.open(File.join(data_path, "users.yaml"), "a+") do |f|
      f.write(Psych.dump({username => {"id" => new_id_of(:users), "password" => BCrypt::Password.create(password)}}).delete("---"))
    end
    session[:signed_in_as] = username
  end

  def data_path
    if ENV["RACK_ENV"] == 'test'
      File.expand_path("../test/data", __FILE__)
    else
      File.expand_path("../data", __FILE__)
    end
  end

  def invalid_name_and_password?(username, password)
    return false if valid_name_and_password?(username, password)
    if !(3..100).cover?(username.size)
      session[:message] = "\"#{username}\" is not a valid name, name should be between 3 - 100 characters."
    end
    if !(6..100).cover?(password.size) || password.match(/\W/)
      if session[:message]
        session[:message] += "<br>Invalid password, password should be between 6 - 100 alphanumeric chars."
      else
        session[:message] = "Invalid password, password should be between 6 - 100 alphanumeric chars."
      end
    end
    true
  end

  def valid_name_and_password?(username, password)
    (3..100).cover?(username.size) && (6..100).cover?(password.size) && !password.match(/\W/)
  end

  def load_user_credentials
    Psych.load_file(File.join(data_path, "users.yaml"))
  end

  def new_id_of(type)
    valid_types(type)
    user_list = load_user_credentials
    return "1" unless user_list
    max_id = user_list.map { |_, infs| infs["id"] }.max.to_i
    (max_id + 1).to_s
  end

  def valid_types(type)
    valid_types = Dir.children(data_path).map do |file|
      File.basename(file).split(".").first
    end
    unless valid_types.include?(type.to_s)
      session[:message] = "Invalid request."
      redirect "/"
    end
  end
