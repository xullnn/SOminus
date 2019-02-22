class User < SOMBase
  attr_accessor :name, :id, :password, :voted_answers, :voted_questions

  def self.create(params)
    params["password"] = BCrypt::Password.create(params[:password])
    super(params)
  end

  def voted_questions
    eval(@voted_questions)
  end

  def voted_answers
    eval(@voted_answers)
  end

end
