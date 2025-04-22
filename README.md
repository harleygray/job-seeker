# 🚀 Job Seeker 🎯

My personal toolkit for efficient job applications. This is a full-stack application built on Elixir which allows me to quickly apply to jobs and showcase my best skills.

## ✨ How it works

*   📄 **crafts applications:** generate personalised CVs ([`cv_generator.ex`](lib/job_hunt/cv_generator.ex)) and cover letters ([`cover_letter_generator.ex`](lib/job_hunt/cover_letter_generator.ex)) that highlight my experience relevant to the position
*   🤖 **powered by groq:** uses the groq ai api for smart text generation ([`groq_client.ex`](lib/job_hunt/groq_client.ex)) using open source large language models (typically Meta's LLaMA series)
*   📊 **keeps me organized:** tracks my job applications in one place ([`job.ex`](lib/job_hunt/job.ex))
*   💅 **looks professional:** creates polished pdf documents from HTML

## 🛠️ Setting it up

if you want to use this tool too:

1. **Install Elixir and Erlang:**
   
   Follow the installation guide at [Gigalixir's beginner guide](https://www.gigalixir.com/blog/a-beginners-guide-to-installing-elixir-with-asdf/)
   
   (note that asdf has a new version so some commands are deprecated but this will get you most of the way)

2. **grab the dependencies:**
   ```bash
   mix setup
   ```

3. **fire it up:**
   ```bash
   mix phx.server
   ```

## 📂 how it's organized


