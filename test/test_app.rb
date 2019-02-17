ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require_relative '../app'
require 'rack/test'
require 'fileutils'
require 'pry'


class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    # create test data directory
    FileUtils.mkdir_p(File.join(data_path))
  end

  def teardown
    FileUtils.rm_rf(File.join(data_path))
  end

  def test_signup_validation
    create_test_user("test", "123456")

    post "/users/signup", { username: "Aa", password: "123456" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "\"Aa\" is not a valid name, name should be between 3 - 100 characters."

    post "/users/signup", { username: "Abc", password: "12345" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid password, password should be between 6 - 100 alphanumeric chars."

    post "/users/signup", { username: "Abc", password: "12>456" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid password, password should be between 6 - 100 alphanumeric chars."

    post "/users/signup", { username: "test", password: "123456" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Name \"test\" has been taken. Please choose another one"
  end

  def test_user_signin_signup_links
    get "/"
    assert_includes last_response.body, "Sign In"
    assert_includes last_response.body, "Sign Up"
    refute_includes last_response.body, "Sign Out"

    get "/users/signin"
    assert_includes last_response.body, "User Name"
    assert_includes last_response.body, "Password"

    get "/", {}, login_for_test
    refute_includes last_response.body, "Sign In"
    refute_includes last_response.body, "Sign Up"
    assert_includes last_response.body, "Sign Out"
  end

  def test_valid_signin
    create_test_user("test", "123456")

    post "/users/signin", username: "test", password: "123456"
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "Successfully signed in as \"test\""
  end

  def test_invalid_signin
    create_test_user("test", "123456")

    post "/users/signin", username: "test", password: "123450"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Wrong user name or password"
  end

  def test_signout
    get "/", {}, login_for_test
    assert_includes last_response.body, "Sign Out"
    assert_includes last_response.body, "Welcome. You're currently signed in as \"test_user\""

    post "/users/signout"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_nil last_request_session[:signed_in_as]
    assert_includes last_response.body, "Successfully signed out"
  end

  def create_test_user(username, password)
    File.open(File.join(data_path, "users.yaml"), "a+") do |f|
      f.write(Psych.dump({username => {"id" => new_id_of(:users), "password" => BCrypt::Password.create(password)}}).delete("---"))
    end
  end

  def login_for_test
    {'rack.session' => { signed_in_as: "test_user" } }
  end

  def last_request_session
    last_request.env["rack.session"]
  end
end
