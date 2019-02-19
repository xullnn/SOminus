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

get "/new_question" do
  validate_user
  erb :new_question
end

post "/questions" do
  validate_user
  title, description = params[:title], params[:description]
  id = new_id_of(:questions)
  user_id = load_data_of(:users)[session[:signed_in_as]]["id"]
  write_new_question({title => { 'id' => id, 'user_id' => user_id, 'description' => description }})
  session[:message] = "Successfully posted a question."
  redirect "/"
end

get "/questions/:id" do
  question = find_question_by_id(params[:id])
  if question
    @question = question # array [title, {infs}]
    @asker = find_user_by_id(@question.last["user_id"])
    @answers = find_answers_by_question_id(params[:id])
    erb :question
  else
    session[:message] = "This question doesn't exist."
    redirect "/"
  end
end

get "/question" do
  redirect "/" if params[:query].nil?
  query = params[:query].downcase.strip
  @questions = search_questions_by_title(query)
  if @questions.empty?
    session[:message] = "No results were found for \"#{query}\"."
    redirect "/"
  end
  erb :search_results
end

get "/questions" do
  @questions = load_data_of(:questions)
  erb :questions
end

post "/questions/:question_id/answers" do
  validate_user
  id = new_id_of(:answers)
  question_id = params[:question_id]
  user_id = current_user["id"]
  content = params[:content]
  answer = {
    id => {
      "question_id" => question_id,
      "user_id" => user_id,
      "content" => content
    }
  }
  write_new_answer(answer)
  session[:message] = "Successfully posted an answer."
  redirect "/questions/#{question_id}"
end

get "/users/:id" do
  @user = find_user_by_id(params[:id])
  @user_s_asked_questions = load_data_of(:questions).select { |_, infs| infs["user_id"] == params[:id] }
  user_s_answers_question_ids = load_data_of(:answers).select do |_, infs|
     infs["user_id"] == params[:id]
  end.map { |_, infs| infs["question_id"] }.uniq
  @user_s_answered_questions = load_data_of(:questions).select { |_, infs| user_s_answers_question_ids.include?(infs["id"]) }
  erb :user
end

private

  def find_user_latest_answered_id_for_question(user_id, question_id)
    answers = find_answers_by_question_id(question_id)
    user_answers = answers.select { |id, infs| infs["user_id"] == user_id }
    user_answers.keys.max
  end

  def find_user_by_id(user_id)
    load_data_of(:users).select { |name, infs| infs["id"] == user_id }
  end

  def find_answers_by_question_id(question_id)
    answers = load_data_of(:answers)
    return nil unless answers
    answers.select { |id, answer| answer["question_id"] == question_id }
  end

  def write_new_answer(answer)
    File.open(File.join(data_path, "answers.yaml"), "a+") do |f|
      f.write(Psych.dump(answer).delete("---"))
    end
  end

  def current_user
    load_data_of(:users)[session[:signed_in_as].to_s]
  end

  def last_datum_of(type)
    [load_data_of(type).to_a.last].to_h
  end

  def search_questions_by_title(query)
    questions = load_data_of(:questions)
    words = query.strip.split # ruby's select method
    questions.select do |title, _|
      title_matched?(title.downcase, words)
    end
  end

  def title_matched?(title, words)
    score = 0
    words.each do |word|
      score += 1 if title.match(Regexp.new(word))
    end
    score >= 2 ? true : false
  end

  def find_question_by_id(id)
    questions = load_data_of(:questions)
    questions.find { |_, infs| infs["id"] == id.to_s }
  end

  def write_new_question(question_obj)
    File.open(File.join(data_path, "questions.yaml"), "a+") do |f|
      f.write(Psych.dump(question_obj).delete("---"))
    end
  end

  def check_name_uniqueness(username)
    return unless load_data_of(:users)
    if load_data_of(:users)[username]
      session[:message] = "Name \"#{username}\" has been taken. Please choose another one."
      status 422
      halt erb(:signup)
    end
  end

  def validate_user
    unless session[:signed_in_as]
      session[:message] = "You need to sign in first to perform this operation."
      redirect "/"
    end
  end

  def validate_user_credential(username, password)
    user_list = load_data_of(:users)
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

  def load_data_of(type)
    filename = type.to_s + ".yaml"
    Psych.load_file(File.join(data_path, filename))
  end

  def new_id_of(type)
    valid_types(type)
    data = load_data_of(type)
    return "1" unless data
    if type == :answers
      max_id = data.keys.map(&:to_i).max
    else
      max_id = data.map { |_, infs| infs["id"].to_i }.max
    end
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
