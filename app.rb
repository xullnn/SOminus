# require files in /objects
require_relative "./som_base.rb"

Dir.children("objects").each do |f|
  require File.expand_path("../objects/#{f}", __FILE__)
end
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
  @latest_questions = Question.all.last(5)
  erb :index
end

get "/users/new" do
  erb :signup
end

post "/users/signup" do
  name, password = params[:name].strip, params[:password].strip
  check_name_uniqueness(name)
  if invalid_name_and_password?(name, password)
    status 422
    erb(:signup)
  else
    User.create(params)
    session[:signed_in_as] = name
    session[:message] = "Signed up successfully."
    redirect "/"
  end
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  name, password = params[:name].strip, params[:password].strip
  validate_user_credential(name, password)
  session[:signed_in_as] = name
  session[:message] = "Successfully signed in as \"#{name}\"."
  redirect "/"
end

get "/users/signout" do
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
  validate_question(params)
  params["user_id"] = current_user.id
  Question.create(params)
  session[:message] = "Successfully posted a question."
  redirect "/"
end

get "/questions/:id" do
  @question = Question.find_by(:id, params[:id])
  if @question
    @asker = User.find_by(:id, @question.user_id)
    @answers = Answer.find_all_by(:question_id, params[:id])
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
  @questions = Question.all
  erb :questions
end

post "/questions/:question_id/answers" do
  validate_user
  validate_answer(params)
  params["user_id"] = current_user.id
  Answer.create(params)
  session[:message] = "Successfully posted an answer."
  redirect "/questions/#{params["question_id"]}"
end

get "/users/:id" do
  @user = User.find_by(:id, params[:id])
  @user_s_asked_questions = Question.all.select { |question| question.user_id == params[:id] }
  user_s_answers_question_ids =
    Answer.all.select { |answer| answer.user_id == params[:id] }.map { |answer| answer.question_id }
  @user_s_answered_questions = Question.all.select { |question| user_s_answers_question_ids.include?(question.id) }
  erb :user
end

post "/questions/:id/vote" do
  validate_user
  check_vote_validity_for_question(params[:id])
  @question = Question.find_by(:id, params[:id])
  @question.votes_count = (@question.votes_count.to_i + 1)
  Question.update(params[:id], votes_count: @question.votes_count )
  @user = current_user
  votes = @user.voted_questions << params[:id].to_i
  User.update(@user.id, voted_questions: votes)
  session[:message] = "Vote successfully :)"
  redirect "/questions/#{@question.id}"
end

post "/questions/:id/veto" do
  validate_user
  check_vote_validity_for_question(params[:id])
  @question = Question.find_by(:id, params[:id])

  @question.votes_count = (@question.votes_count.to_i - 1)
  Question.update(params[:id], votes_count: @question.votes_count )
  @user = current_user
  votes = @user.voted_questions << params[:id].to_i
  User.update(@user.id, voted_questions: votes)
  session[:message] = "Veto successfully :("
  redirect "/questions/#{@question.id}"
end

post "/answers/:id/vote" do
  validate_user
  check_vote_validity_for_answer(params[:id])

  @answer = Answer.find_by(:id, params[:id])
  @answer.votes_count = (@answer.votes_count.to_i + 1)
  Answer.update(params[:id], votes_count: @answer.votes_count )
  @user = current_user
  votes = @user.voted_answers << params[:id].to_i
  User.update(@user.id, voted_answers: votes)
  session[:message] = "Vote successfully :)"
  redirect "/questions/#{@answer.question_id}"
end

post "/answers/:id/veto" do
  validate_user
  check_vote_validity_for_answer(params[:id])

  @answer = Answer.find_by(:id, params[:id])
  @answer.votes_count = (@answer.votes_count.to_i - 1)
  Answer.update(params[:id], votes_count: @answer.votes_count )
  @user = current_user
  votes = @user.voted_answers << params[:id].to_i
  User.update(@user.id, voted_answers: votes)
  session[:message] = "Veto successfully :("
  redirect "/questions/#{@answer.question_id}"
end

private

def check_vote_validity_for_question(question_id)
  if current_user.voted_questions.include?(question_id.to_i)
    @question = Question.find_by(:id, question_id)
    @asker = User.find_by(:id, @question.user_id)
    @answers = Answer.find_all_by(:question_id, question_id)
    session[:message] = "You've voted for this question before."
    redirect "/questions/#{@question.id}"
  end
end

def check_vote_validity_for_answer(answer_id)
  if current_user.voted_answers.include?(answer_id.to_i)
    @answer = Answer.find_by(:id, answer_id)
    @question = Question.find_by(:id, @answer.question_id)
    @asker = User.find_by(:id, @answer.user_id)
    @answers = Answer.find_all_by(:id, answer_id)
    session[:message] = "You've voted for this answer before."
    redirect "/questions/#{@question.id}"
  end
end

  def validate_question(params)
    if !(10..120).cover?(params[:title].strip.size)
      session[:message] = "Question title should be between 10 and 120 characters."
      status 422
      halt erb(:new_question)
    elsif !(10..2000).cover?(params[:description].strip.size)
      session[:message] = "Question description should be between 10 and 2000 characters."
      status 422
      halt erb(:new_question)
    end
  end

  def validate_answer(params)
    unless (10..3000).cover?(params[:content].strip.size)
      session[:message] = "Answer length should be between 10 and 3000 characters."
      redirect back
    end
  end

  def find_user_latest_answered_id_for_question(user_id, question_id)
    answers = Answer.find_all_by(:question_id, question_id)
    user_answers = answers.select { |answer| answer.user_id == user_id }
    user_answers.map { |answer| answer.id.to_i }.max.to_s
  end

  def current_user
    User.find_by(:name, session[:signed_in_as].to_s)
  end

  def search_questions_by_title(query)
    questions = Question.all
    words = query.strip.split # ruby's select method
    questions.select do |question|
      title_matched?(question.title.downcase, words)
    end
  end

  def title_matched?(title, words)
    score = 0
    words.each do |word|
      score += 1 if title.match(Regexp.new(word))
    end
    score >= 2 ? true : false
  end

  def check_name_uniqueness(username)
    return unless User.all
    if User.find_by(:name, username)
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

  def validate_user_credential(name, password)
    user = User.find_by(:name, name)
    unless user && BCrypt::Password.new(user.password) == password
      status 422
      session[:message] = "Wrong user name or password"
      halt erb(:signin)
    end
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

  def valid_types(type)
    valid_types = Dir.children(data_path).map do |file|
      File.basename(file).split(".").first
    end
    unless valid_types.include?(type.to_s)
      session[:message] = "Invalid request."
      redirect "/"
    end
  end
