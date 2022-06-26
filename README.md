# Galley

Galley is a cooking application with the goal of making it easier and more fun
to plan & cook meals. At this time users can only create and browse recipes, but
future features may include meal planners, finding recipes based on the
ingredients you have etc.

## Development

### Requirements

* Elixir >= 1.12
* An AWS account + S3 buckets
* A sendgrid account (or other mailer if you wish to set that up yourself)
* Sqlite installed

### Get up and going

* Install dependencies with `mix deps.get`
* Create and migrate your database with `mix ecto.setup`
* Fill your .env.dev variables (see `env.example`) for a template.
  * our shell implies using fish shell.
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
* You can migrate recipes from [Aris Garden](https://github.com/theiceshelf/arisgarden) by runnimg `mix db.migrate_aris` if you want test data
* Visit [`localhost:4000`](http://localhost:4000) from your browser.
  

## Screenshots

![](./docs/screenshots/screen_index.png)

![](./docs/screenshots/screen_show.png)

