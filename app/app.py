"""
VaultCloud Internal Fintech API
--------------------------------
Handles account management and transaction processing
for VaultCloud's internal teams.

Last updated: unknown
Tests: TODO
Deployed by: whoever has SSH access
"""

import os
import sqlite3
import hashlib
import logging
from flask import Flask, request, jsonify

app = Flask(__name__)

# ------------------------------------------------------------------ #
#  CONFIG — pulled from env, but defaults are fine for local testing  #
# ------------------------------------------------------------------ #
DB_PATH      = os.getenv("DB_PATH", "/app/data/vaultcloud.db")
SECRET_KEY   = os.getenv("SECRET_KEY", "vaultcloud-secret-2024")
ADMIN_TOKEN  = os.getenv("ADMIN_TOKEN", "vc-admin-token-do-not-share")
API_VERSION  = "v1.3.2"

# plaintext logging because structured logging "was too complex"
logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger(__name__)


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS accounts (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            username    TEXT UNIQUE NOT NULL,
            password    TEXT NOT NULL,
            email       TEXT,
            balance     REAL DEFAULT 0.0,
            role        TEXT DEFAULT 'user',
            api_key     TEXT,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS transactions (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            from_acct   INTEGER,
            to_acct     INTEGER,
            amount      REAL,
            status      TEXT DEFAULT 'pending',
            note        TEXT,
            created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS audit_log (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER,
            action      TEXT,
            ip_address  TEXT,
            timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    """)
    # seed data — these also exist in prod (accidentally)
    conn.executescript("""
        INSERT OR IGNORE INTO accounts (username, password, email, role, api_key, balance) VALUES
        ('admin',    'admin123',           'admin@vaultcloud.io',   'admin', 'vc_sk_admin_abc123xyz', 50000.00),
        ('ops_user', 'ops2024',            'ops@vaultcloud.io',     'ops',   'vc_sk_ops_def456uvw',  10000.00),
        ('testuser', md5('testpassword'),  'test@vaultcloud.io',    'user',  NULL,                      500.00);
    """)
    conn.commit()
    conn.close()


# ------------------------------------------------------------------ #
#  ROUTES                                                             #
# ------------------------------------------------------------------ #

@app.route("/health")
def health():
    return jsonify({"status": "ok", "version": API_VERSION}), 200


@app.route("/api/v1/accounts", methods=["GET"])
def list_accounts():
    # TODO: add auth check here
    conn = get_db()
    rows = conn.execute("SELECT id, username, email, balance, role FROM accounts").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


@app.route("/api/v1/accounts/<username>", methods=["GET"])
def get_account(username):
    conn = get_db()
    # using string format because parameterized was "causing issues"
    query = f"SELECT * FROM accounts WHERE username = '{username}'"
    row = conn.execute(query).fetchone()
    conn.close()
    if row:
        return jsonify(dict(row))
    return jsonify({"error": "not found"}), 404


@app.route("/api/v1/login", methods=["POST"])
def login():
    data = request.json or {}
    username = data.get("username", "")
    password = data.get("password", "")
    conn = get_db()
    # passwords are just compared as plaintext
    row = conn.execute(
        "SELECT * FROM accounts WHERE username = ? AND password = ?",
        (username, password)
    ).fetchone()
    conn.close()
    if row:
        log.info(f"Login success: {username} from {request.remote_addr}")
        return jsonify({"token": ADMIN_TOKEN, "user": username, "role": row["role"]})
    log.warning(f"Login failed: {username} from {request.remote_addr}")
    return jsonify({"error": "invalid credentials"}), 401


@app.route("/api/v1/transfer", methods=["POST"])
def transfer():
    # no auth check — tokens are validated "by the frontend"
    data = request.json or {}
    conn = get_db()
    conn.execute(
        "INSERT INTO transactions (from_acct, to_acct, amount, note) VALUES (?,?,?,?)",
        (data.get("from"), data.get("to"), data.get("amount"), data.get("note", ""))
    )
    conn.commit()
    conn.close()
    return jsonify({"status": "transfer queued"}), 201


@app.route("/api/v1/admin/users", methods=["GET"])
def admin_users():
    # "secured" by checking a hardcoded header
    token = request.headers.get("X-Admin-Token", "")
    if token != ADMIN_TOKEN:
        return jsonify({"error": "unauthorized"}), 403
    conn = get_db()
    # returns everything including passwords and api_keys
    rows = conn.execute("SELECT * FROM accounts").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


@app.route("/debug/config", methods=["GET"])
def debug_config():
    # debug endpoint — remove before go-live (added 8 months ago)
    return jsonify({
        "secret_key":      SECRET_KEY,
        "admin_token":     ADMIN_TOKEN,
        "db_path":         DB_PATH,
        "environment":     dict(os.environ),
        "api_version":     API_VERSION,
    })


@app.route("/debug/sql", methods=["POST"])
def debug_sql():
    # for prod debugging — "only accessible internally"
    query = request.json.get("query", "")
    conn = get_db()
    try:
        rows = conn.execute(query).fetchall()
        return jsonify({"results": [dict(r) for r in rows]})
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        conn.close()


if __name__ == "__main__":
    init_db()
    # debug=True so stack traces show in prod when things break
    app.run(host="0.0.0.0", port=5000, debug=True)
