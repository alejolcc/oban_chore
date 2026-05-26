# ObanChore 🎭

**Bridge the gap between robust background processing and safe, manual operational control in Elixir.**

ObanChore is an Elixir library that transforms your standard Oban workers into secure, UI-driven operational tools. It automatically generates a Phoenix LiveView dashboard allowing your team to trigger and monitor ad-hoc scripts and backfills without touching a production console.

![ObanChore Dashboard Preview](assets/dashboard_preview.gif)

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

Instead of writing a disposable script, developers write a standard, resilient and testeable Oban worker and declare its expected inputs (e.g., `user_id`, `reason`). ObanChore dynamically reads these declarations and **automatically generates a secure Phoenix LiveView interface**.

```elixir
defmodule MyApp.Chores.UserBackfill do
  use ObanChore.Worker,
    name: "User Data Backfill",
    fields: [
      user_id: [type: :integer, required: true, label: "User ID"],
      role: [
        type: :select,
        options: [Admin: 1, Editor: 2, Viewer: 3],
        prompt: "Choose a role..."
      ],
      sleep_time: [type: :integer, label: "Sleep Time (ms)", default: 3000],
      reason: [type: :textarea, label: "Reason"],
      notify_user: [type: :boolean, label: "Notify User?"]
    ],
    description: "Backfill user data with new fields and values."

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "reason" => reason} = args}) do
    notify_user? = Map.get(args, "notify_user")
    role = Map.get(args, "role")
    # Your logic here
    :ok
  end
end
```

Support, QA, or Product Managers can now go to admin dashboard, fill out a user-friendly form, and safely trigger the job—while Oban handles the reliable, asynchronous execution in the background.

## 🚀 Getting Started

### 1. Prerequisites

ObanChore requires a working Phoenix application with **LiveView** and **Oban 2.15+** installed and configured.

### 2. Install Dependency

Add `oban_chore` to your `mix.exs`:

```elixir
def deps do
  [
    {:oban_chore, "~> 0.3.0"}
  ]
end
```

### 3. Configure Oban

Add `ObanChore.Plugin` to your Oban configuration. This plugin automatically discovers chores and attaches telemetry handlers for real-time updates:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  plugins: [
    {ObanChore.Plugin, otp_app: :my_app, pubsub_server: MyApp.PubSub},
    # ... other plugins
  ],
  queues: [default: 10]
```


### 4. Define a Chore

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
  def perform(%Oban.Job{args: %{"user_id" => user_id, "reason" => reason} = args}) do
    # Your logic here
    :ok
  end

  # Optional: Add custom validations using Ecto.Changeset
  @impl ObanChore.Worker
  def custom_changeset(changeset) do
    changeset
    |> Ecto.Changeset.validate_number(:user_id, greater_than: 0)
    |> Ecto.Changeset.validate_length(:reason, min: 5)
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

---

## ⚙️ Real-Time Monitoring

ObanChore provides deep visibility into your operational tasks as they happen.

### Live Console Logging

To stream custom logs from your workers use `ObanChore.log/2` inside your worker's `perform/1` function:

```elixir
defmodule MyApp.Chores.UserBackfill do
  use ObanChore.Worker, name: "User Backfill"

  @impl Oban.Worker
  def perform(%Oban.Job{} = job) do
    ObanChore.log(job, "Starting backfill...")
    # ... logic ...
    ObanChore.log(job, "Done!")
    :ok
  end
end
```

> [!NOTE]
> Currently, to maintain simplicity, the logs are ephemeral. However, storing them in an ETS table to survive Phoenix LiveView tab restarts it could be considered for future iterations.


---

## 🛠️ Field Configuration

### Supported Types

ObanChore supports several field types that automatically map to both Ecto types for validation and HTML input types for the dashboard:

| Type | Ecto Type | HTML Input |
| :--- | :--- | :--- |
| `:string` | `:string` | `text` |
| `:integer` | `:integer` | `number` |
| `:float` | `:float` | `number` |
| `:boolean` | `:boolean` | `checkbox` |
| `:date` | `:date` | `date` |
| `:time` | `:time` | `time` |
| `:utc_datetime` | `:utc_datetime` | `datetime-local` |
| `:textarea` | `:string` | `textarea` |
| `:select` | `:string` | `select` |
| `:checkbox` | `:boolean` | `checkbox` |

### Field Options

Each field can be customized with the following options:

| Option | Description |
| :--- | :--- |
| `:type` | **(Required)** The field type from the table above. |
| `:label` | The display name for the field in the UI. Defaults to the key name. |
| `:required` | Whether the field must be present. Adds validation to the form. |
| `:default` | The initial value for the field in the form. |
| `:options` | Required for `:select`. A list of strings or `{"Label", "Value"}` tuples. |
| `:prompt` | Optional for `:select`. The placeholder text for the dropdown. |

---

## ⚙️ Advanced Configuration

Since `ObanChore.Worker` is a wrapper around `Oban.Worker`, you can use all standard Oban options:

```elixir
defmodule MyApp.Chores.CriticalBackfill do
  use ObanChore.Worker,
    name: "Critical Data Backfill",
    queue: :operational,        # Run in a specific queue
    max_attempts: 5,            # Set custom retry limit
    priority: 1,                # Set job priority
    unique: [period: 60],       # Set custom uniqueness
    fields: [
      user_id: [type: :integer, required: true]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # ...
  end
end
```

> **Note on Uniqueness:** If you define `unique` options directly in the worker module (as shown above), they will **override** the default unique behavior of the dashboard. The manual "Unique per args" toggle in the UI will be disabled to respect your worker's specific constraints.

---

## ✨ Core Features

* 🛠️ **Zero-Boilerplate Internal Tooling:** Stop building custom HTML forms and controllers for one-off admin tasks. Define your argument schema once in the backend, and let ObanChore generate the UI.
* 📡 **Live Execution Streaming:** Leveraging Phoenix PubSub and Telemetry, ObanChore streams logs and status updates from the background process directly back to the user's browser in real-time.
* 🔐 **Operational Safety:** 
    * **Idempotency Check:** Automatically detects if a job with the same arguments is already running.
    * **Unique Execution Toggle:** Manually enforce single-job execution via the dashboard UI. (you can override this from the job definition)
    * **Validation:** Full Ecto-backed validation for all chore arguments.
* 🚦 **Concurrency Control:** Piggyback on Oban's powerful concurrency and unique job features to control your operational load.

## 🏗️ Architectural Philosophy

ObanChore is **not** a replacement for Oban. It is a complementary operational layer. 

While Oban excels at automated, system-driven tasks (sending emails, processing webhooks), ObanChore provides the missing interface for **human-driven** tasks. By piggybacking on your existing Oban supervision tree and PostgreSQL queues, ObanChore requires minimal infrastructure overhead while delivering massive operational value.

## 🎯 Who is this for?

* **Engineering Teams:** Looking to reduce interruptions from operational requests and eliminate the need for production IEx access.
* **Customer Support & Ops:** Needing safe, self-serve access to resolve customer issues without waiting on engineering.
* **Technical Founders:** Wanting to implement enterprise-grade compliance, audit logging, and secure internal tooling from day one.
