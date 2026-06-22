# Create an inventory

An **inventory** tells Semaphore *which* hosts a job runs against. You'll create one that
reads the `inventory/hosts.yml` file straight from the linked repository.

## In the Semaphore UI

1. In the **Acme Automation** project, open **Inventory** in the left sidebar.
2. Click **New Inventory** → **Ansible Inventory**.
3. Fill in the form. Selecting **Type → File** reveals the last two fields:

   | Field | Value |
   |---|---|
   | **Name** | `acme-nodes` |
   | **User Credentials** | `nodes-ssh` |
   | **Sudo Credentials (Optional)** | `None` |
   | **Type** | `File` |
   | **Path to Inventory file** | `inventory/hosts.yml` |
   | **Repository (Optional)** | `acme` |

4. Click **Create**.

### Why these choices

- **File** type means the inventory is read from a file in your repo — the same
  `inventory/hosts.yml` you looked at in the last step — rather than typed into the UI. This
  keeps the source of truth in Git.
- **User Credentials** (`nodes-ssh`) is the SSH key Semaphore uses to connect to the nodes as
  the `ansible` user.
- **Sudo Credentials** can stay `None` — our `ansible` user has passwordless sudo.
- **Repository** (`acme`) tells Semaphore which repo holds that inventory file.

Click **Check** once the inventory exists.
