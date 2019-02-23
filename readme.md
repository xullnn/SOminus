A simplified version of stackoverflow

---

v 0.0

Core features:

- user registration
- ask questions
- answer questions

Data store:

yaml

- User
  - id
- Question
  - id
  - user_id(who asked)
  - title
  - description
- Answer
  - id
  - question_id(which question it is answering)
  - user_id(who answered)
  - content

---

v 0.1

Logged in user can vote for question and answers
- one user can only vote for specific question or answer one time.
  - need to store which users have voted for a question/answer(voted_by: [1, 3, 4, 5]) user ids
  - or what questions/answers a user voted for(q and a don't need to know who have voted them)
    - voted_questions: [1 ,2, 3]
    - voted_answers: [3, 4, 5]
  - how to update yaml file?

Which Objects need to change
- database layer
  - add voted_answers: to user => []
  - add voted_questions: to user => []
  - add votes_count: to question => 0 can be negative?
  - add votes_count: to answer
- app layer
  - user interface
    - all at questions/:id page
    - post "/questions/:id/vote"
      - vote for question
        - check if current_user had voted this question before?
        - if not, question's votes_count + 1 and add question id to user's voted_questions attr
        - if yes, redirect back and show message
    - Write data into yaml
    - post "/questions/:id/veto"
      - similar steps
