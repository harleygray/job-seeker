# 🚀 Job Seeker 🎯

My personal toolkit for efficient job applications. This full-stack application combines Elixir/Phoenix LiveView with Svelte components and AI-powered content generation to streamline the entire job application process.

## ✨ How it works

### 🏗️ **Architecture**
*   **Backend:** Elixir/Phoenix with LiveView for real-time updates
*   **Frontend:** Svelte components embedded in LiveView for reactive UI
*   **AI Integration:** Groq API with structured JSON output for intelligent content generation
*   **PDF Generation:** ChromicPDF for professional document creation

### 🎯 **Core Features**
*   📋 **Job Management:** Track applications with intelligent scoring across multiple role types (Data Analyst, Software Engineer, AI Engineer, etc.)
*   🤖 **AI-Powered Content:** Generate personalized CVs and cover letters using Groq's LLaMA models with structured output
*   📄 **Document Preview:** Live HTML preview with inline editing capabilities before PDF generation
*   💾 **Smart Storage:** Organize generated PDFs by company in `static/generated_pdfs/`
*   📊 **Application Tracking:** Monitor application status (Active/Archived) with detailed job information

### 🔄 **Workflow**
1. Add job postings through the Svelte-powered interface
2. AI analyzes job descriptions and generates role-specific scores
3. Generate tailored CV (2 pages) and cover letter using Groq API
4. Preview and edit documents in real-time with Svelte components
5. Export professional PDFs with zero margins, organized by company

## 🛠️ Setting it up

if you want to use this tool too:

1. **Install Elixir and Erlang:**
   
   Follow the installation guide at [Gigalixir's beginner guide](https://www.gigalixir.com/blog/a-beginners-guide-to-installing-elixir-with-asdf/)
   
   (note that asdf has a new version so some commands are deprecated but this will get you most of the way)

2. **Grab the dependencies:**
   ```bash
   mix setup
   ```

3. **Set environment variables and personalise:**

   Create a .env file in the project root with `GROQ_API_KEY`

   Save your chosen profile photo to `/priv/static/images/profile.png`

   Update your contact details in `/priv/static/left_column.html.heex`

4. **Fire it up:**
   ```bash
   mix phx.server
   ```



