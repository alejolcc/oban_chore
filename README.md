# ObanChore 🎭

**Bridge the gap between robust background processing and safe, manual operational control in Elixir.**

ObanChore is an Elixir library that transforms your standard Oban workers into secure, UI-driven operational tools. It automatically generates a Phoenix LiveView dashboard allowing your team to trigger, monitor, and audit ad-hoc scripts and backfills without touching a production console.

---

## 🛑 The Problem: The "IEx Bottleneck"

In growing applications, developers frequently write ad-hoc scripts: data migrations, one-off backfills, or specific customer support actions (like resetting a stuck billing state or refunding a transaction). 

Historically, executing these scripts involves:
1. A developer SSH-ing into the production server.
2. Opening an `iex -S mix` console.
3. Manually typing execution commands and passing arguments.

**This is risky and unscalable.** Direct production shell access is a security risk, typos in the shell can cause catastrophic data loss, there is zero auditability for compliance, and developers become a permanent bottleneck for Customer Support and Operations teams.

## 💡 The Solution: Democratized Execution

ObanChore solves this by bringing operations out of the terminal and into a secure UI, backed by the resilience of Oban. 

Instead of writing a disposable script, developers write a standard, resilient Oban worker and declare its expected inputs (e.g., `user_id`, `reason`). ObanChore dynamically reads these declarations and **automatically generates a secure Phoenix LiveView interface**.

```elixir
defmodule MyApp.Chores.UserBackfill do
  use ObanChore.Worker,
    name: "User Data Backfill",
    fields: [
      user_id: [type: :integer, required: true],
      reason: [type: :string, default: "Manual Update"]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Logic here
  end
end
```

Support, QA, or Product Managers can now log into an admin dashboard, fill out a user-friendly form, and safely trigger the job—while Oban handles the reliable, asynchronous execution in the background.

## 🚀 Getting Started

### 1. Install Dependency

Add `oban_chore` to your `mix.exs`:

```elixir
def deps do
  [
    {:oban_chore, "~> 0.1.0"}
  ]
end
```

### 2. Configure Oban

Add `ObanChore.Plugin` to your Oban configuration:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  plugins: [
    {ObanChore.Plugin, otp_app: :my_app},
    # ... other plugins
  ],
  queues: [default: 10]
```

### 3. Define a Chore

Replace `use Oban.Worker` with `use ObanChore.Worker` and define your fields:

```elixir
defmodule MyApp.Chores.UserBackfill do
  use ObanChore.Worker,
    name: "User Data Backfill",
    fields: [
      user_id: [type: :integer, required: true],
      reason: [type: :string, default: "Manual Update"]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Your logic here
    :ok
  end

  # Optional: Add custom validations using Ecto.Changeset
  @impl ObanChore.Worker
  def custom_changeset(changeset) do
    Ecto.Changeset.validate_number(changeset, :user_id, greater_than: 0)
  end
end
```

### 4. Advanced Configuration

Since `ObanChore.Worker` is a wrapper around `Oban.Worker`, you can use all standard Oban options like `queue`, `max_attempts`, and `priority`:

```elixir
defmodule MyApp.Chores.CriticalBackfill do
  use ObanChore.Worker,
    name: "Critical Data Backfill",
    queue: :operational,        # Run in a specific queue
    max_attempts: 5,            # Set custom retry limit
    priority: 1,                # Set job priority
    fields: [
      user_id: [type: :integer, required: true]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # ...
  end
end
```

### 5. Mount the Dashboard

Add the dashboard to your Phoenix router:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import ObanChore.Router

  scope "/" do
    pipe_through :browser

    # Mount the dashboard at any path
    oban_chore_dashboard "/chores"
  end
end
```

### 5. Configure PubSub (Optional but Recommended)

To enable real-time logging from your workers, configure your PubSub server:

```elixir
# config/config.exs
config :oban_chore, pubsub_server: MyApp.PubSub
```

### 6. Use Real-Time Logging

Inside your worker's `perform/1` function, use `ObanChore.log/2` to stream updates:

```elixir
defmodule MyApp.Chores.UserBackfill do
  use ObanChore.Worker, name: "User Backfill"

  @impl Oban.Worker
  def perform(%Oban.Job{} = job) do
    ObanChore.log(job, "Starting backfill...")
    # ... logic ...
    ObanChore.log(job, "Processed 50%...")
    # ... logic ...
    ObanChore.log(job, "Done!")
    :ok
  end
end
```

## ✨ Core Features

* 🛠️ **Zero-Boilerplate Internal Tooling:** Stop building custom HTML forms and controllers for one-off admin tasks. Define your argument schema once in the backend, and let ObanChore generate the UI.
* 📡 **Live Execution Streaming:** Leveraging Phoenix PubSub, ObanChore streams logs and progress updates from the isolated background process directly back to the user's browser in real-time.
* 🔐 **Operational Safety by Default:** Move away from direct database manipulation. Chores run within the strict, idempotent boundaries of your Oban workers. 
* 🚦 **Concurrency Control:** Prevent race conditions by ensuring specific operational tasks cannot be triggered concurrently by multiple users.

## 🏗️ Architectural Philosophy

ObanChore is **not** a replacement for Oban. It is a complementary operational layer. 

While Oban excels at automated, system-driven tasks (sending emails, processing webhooks), ObanChore provides the missing interface for **human-driven** tasks. By piggybacking on your existing Oban supervision tree and PostgreSQL queues, ObanChore requires minimal infrastructure overhead while delivering massive operational value.

## 🎯 Who is this for?

* **Engineering Teams:** Looking to reduce interruptions from operational requests and eliminate the need for production IEx access.
* **Customer Support & Ops:** Needing safe, self-serve access to resolve customer issues without waiting on engineering.
* **Technical Founders:** Wanting to implement enterprise-grade compliance, audit logging, and secure internal tooling from day one.

## 🗺️ Roadmap

- [ ] **Custom UI Components:** Support for more complex field types and custom LiveView components for argument input.
- [ ] **Permission Management:** Integration with existing auth systems to restrict who can execute specific chores.
- [ ] **Dry-Run Mode:** Ability to simulate chore execution before committing changes.