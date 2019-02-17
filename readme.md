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
- Questions
  - id
  - user_id(who asked)
- Answers
  - id
  - question_id(which question it is answering)
  - user_id(who answered)
