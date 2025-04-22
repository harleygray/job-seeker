defmodule JobHuntWeb.Router do
  use JobHuntWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JobHuntWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JobHuntWeb do
    pipe_through :browser

    live "/interface", JobLive.Interface
    live "/resume", JobLive.Resume

  end

end
