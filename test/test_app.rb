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
    FileUtils.mkdir_p(data_path)
    FileUtils.touch(File.join(data_path, 'users.yaml'))
    FileUtils.touch(File.join(data_path, 'questions.yaml'))
    FileUtils.touch(File.join(data_path, 'answers.yaml'))
  end

  def teardown
    FileUtils.rm_rf(File.join(data_path))
  end

  def test_signup_validation
    create_test_user("test", "123456")

    post "/users/signup", { name: "Aa", password: "123456" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "\"Aa\" is not a valid name, name should be between 3 - 100 characters."

    post "/users/signup", { name: "Abc", password: "12345" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid password, password should be between 6 - 100 alphanumeric chars."

    post "/users/signup", { name: "Abc", password: "12>456" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid password, password should be between 6 - 100 alphanumeric chars."

    post "/users/signup", { name: "test", password: "123456" }
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
    skip # why?
    create_test_user("test", "123456")

    post "/users/signin", { name: "test", password: "123456" }
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "Successfully signed in as \"test\""
  end

  def test_invalid_signin
    create_test_user("test", "123456")

    post "/users/signin", name: "test", password: "123450"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Wrong user name or password"
  end

  def test_signout
    get "/", {}, login_for_test
    assert_includes last_response.body, "Sign Out"
    assert_includes last_response.body, "Welcome. You're currently signed in as \"test\""

    post "/users/signout"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_nil last_request_session[:signed_in_as]
    assert_includes last_response.body, "Successfully signed out"
  end

  def test_ask_question_button
    get "/"
    refute_includes last_response.body, "Ask Question</button>"

    get "/", { }, login_for_test
    assert_includes last_response.body, "Ask Question</button>"
  end

  def test_ask_new_question
    get "/new_question"
    assert_equal "You need to sign in first to perform this operation.", last_request_session[:message]

    get "/new_question", {}, login_for_test
    assert_includes last_response.body, "Question Title"
  end

  def test_create_question
    create_test_user("test", "123456")

    post "/questions", { title: 'test question', description: "some text" }
    assert_equal "You need to sign in first to perform this operation.", last_request_session[:message]

    post "/questions", { title: 'test question', description: "some text some text" }, login_for_test
    assert_equal "Successfully posted a question.", last_request_session[:message]
  end

  def test_view_single_question
    # need not user credential
    create_test_user("test", "123456")
    create_test_questions
    get "/questions/2"
    assert_includes last_response.body, "This is a test question"
  end

  def test_search_questions
    create_test_questions
    get "/question?query=test+5"
    assert_includes last_response.body, "test question 5"

    get "/question?query=test+6"
    assert_equal "No results were found for \"test 6\".", last_request_session[:message]
  end

  def test_view_all_questions
    create_test_questions
    get "/questions"
    assert_includes last_response.body, Question.last.title
  end

  def test_answer_questions_button
    create_test_questions
    create_test_user("test", "123456")

    get "/questions/3"
    assert_includes last_response.body, "<button disabled>Answer This Question</button>"
    assert_includes last_response.body, "Please login to answer questions."

    get "/questions/3", {}, login_for_test
    assert_includes last_response.body, "<button type=\"submit\">Answer This Question</button>"
    refute_includes last_response.body, "Please login to answer questions."
  end

  def test_user_answer_questions
    create_test_questions
    create_test_user("test", "123456")

    post "/questions/3/answers", content: "Some answer"
    assert_equal "You need to sign in first to perform this operation.", last_request_session[:message]

    post "/questions/3/answers", { content: "Some answer" }, login_for_test
    assert_equal 302, last_response.status
    assert_equal "Successfully posted an answer.", last_request_session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "test question 3"
    assert_includes last_response.body, "answered by: <a href=\"/users/1\">test</a>"
    assert_includes last_response.body, "Some answer"
  end

  def test_view_user_link_in_answer
    create_test_questions
    create_test_user("test", "123456")
    post "/questions/3/answers", { content: "Some answer" }, login_for_test

    get "/questions/3"
    assert_includes last_response.body, "<a href=\"/users/1\">test</a>"
  end

  def test_user_page
    create_test_questions
    create_test_user("test", "123456")
    post "/questions/3/answers", { content: "Some answer" }, login_for_test
    post "/questions/5/answers", { content: "test content" }

    get "/users/1"
    assert_includes last_response.body, "Asked Questions:"
    assert_includes last_response.body, "Answered Questions:"

    (1..5).each { |n| assert_includes last_response.body, "test question #{n}" }
  end

  def test_question_create_validation
    create_test_user("test", "123456")
    post "/questions", { title: "abc", description: "test question"}, login_for_test

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Question title should be between 10 and 120 characters."

    post "/questions", { title: "abcdefghijk", description: "a" * 2001 }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Question description should be between 10 and 2000 characters."
  end

  def test_answer_create_valiattion
    create_test_questions
    create_test_user("test", "123456")

    post "/questions/3/answers", { content: "abc" }, login_for_test
    assert_equal "Answer length should be between 10 and 3000 characters.", last_request_session[:message]

    post "/questions/3/answers", { content: "a" * 3001 }, login_for_test
    assert_equal "Answer length should be between 10 and 3000 characters.", last_request_session[:message]
  end

  def create_test_user(name, password)
    User.create({ "name" => name, "password" => BCrypt::Password.create(password)})
  end

  def create_test_questions
    (1..5).each do |id|
      Question.create({ "title" => "test question #{id}", "user_id" => "1", "description" => "This is a test question"})
    end
  end

  def login_for_test
    {'rack.session' => { signed_in_as: "test" } }
  end

  def last_request_session
    last_request.env["rack.session"]
  end
end
