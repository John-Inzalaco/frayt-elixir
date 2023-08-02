# FraytElixir
![Build status](https://github.com/Frayt-Technologies/frayt-elixir/actions/workflows/build.yml/badge.svg)
## Environment setup
Run the following command to enable hooks: `git config --local core.hooksPath .git_hooks`

Refer to Nifty > Development > Docs > Team Documentation > Environment Setup for prerequisite environment setup

 - Install tools with `asdf install` in the project root

## Running FraytElixir
### Setup

You'll need to create `config/dev.secret.exs` to store the api keys. Request the file content from one of your other team members
### Start your PostgreSQL server:
- Run `docker-compose up`

The master DB will be accessible on port 5560. Replicas - which are read only - will be available on consecutive ports. E.g. replica1 = 5561

If the database needs to be accessed directly with a tool like Postico, the database name is `frayt_elixir_dev`

Username and password generated will be `postgres`/`postgres`

### Start your Phoenix server:
- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `cd assets && npm install`
- Start Phoenix endpoint with `mix phx.server`
- This creates shipper, driver, and admin accounts with the following credentials 
  - email: `user@frayt.com`
  - password: `password@1`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
## Deploying

Deploying is done automatically using Github workflows/actions. Deploys are run when a new release is created in Github

## Import/Export data

Check out `scripts/export_data.sh` and `scripts/load_data.sh`. They will both need several env variables set. The values for them can be learned
by running `gigalixir pg` on the appropriate app. These scripts are designed to export data from production and import into staging (or a local environment).

**DANGER: NEVER IMPORT INTO PRODUCTION. ALL DATA WILL BE DESTROYED!!**

## Troubleshooting build deployments

Occasionally, deployments from github actions will fail. To resolve this, you may need to do a build from the command line that passes an extra argument to clear the gigalixir build cache:

```
git -c http.extraheader="GIGALIXIR-CLEAN: true" push frayt-dev master
```

Substitute the gigalixir git remote for the environment you are deploying to.

## ReleaseTasks

Because we are using elixir releases for our deployment, mix tasks will not be available. The recommended approach to this problem is to create a module with tasks designed to be run from the console in a deployed environment. As such, we have a module `FraytElixir.ReleaseTasks`. To run these, first you will need a console:

```
gigalixir ps:remote_console
```

Then, in the iEx session:

```
> alias FraytElixir.ReleaseTasks
> ReleaseTasks.<desired_function>
```

Each function in this module should be documented. On the console, do `h ReleaseTasks.<function>` to view.
