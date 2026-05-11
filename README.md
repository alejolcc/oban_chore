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

## ✨ Core Features

* 🛠️ **Zero-Boilerplate Internal Tooling:** Stop building custom HTML forms and controllers for one-off admin tasks. Define your argument schema once in the backend, and let ObanChore generate the UI.
* 📡 **Live Execution Streaming:** Leveraging Phoenix PubSub, ObanChore streams logs and progress updates from the isolated background process directly back to the user's browser in real-time.
* 🔐 **Operational Safety by Default:** Move away from direct database manipulation. Chores run within the strict, idempotent boundaries of your Oban workers. 
* 📜 **Compliance & Auditability:** Every executed chore leaves a permanent trail. Know exactly *who* triggered a script, *when* it was run, and *what* parameters were used.
* 🚦 **Concurrency Control:** Prevent race conditions by ensuring specific operational tasks cannot be triggered concurrently by multiple users.

## 🏗️ Architectural Philosophy

ObanChore is **not** a replacement for Oban. It is a complementary operational layer. 

While Oban excels at automated, system-driven tasks (sending emails, processing webhooks), ObanChore provides the missing interface for **human-driven** tasks. By piggybacking on your existing Oban supervision tree and PostgreSQL queues, ObanChore requires minimal infrastructure overhead while delivering massive operational value.

## 🎯 Who is this for?

* **Engineering Teams:** Looking to reduce interruptions from operational requests and eliminate the need for production IEx access.
* **Customer Support & Ops:** Needing safe, self-serve access to resolve customer issues without waiting on engineering.
* **Technical Founders:** Wanting to implement enterprise-grade compliance, audit logging, and secure internal tooling from day one.