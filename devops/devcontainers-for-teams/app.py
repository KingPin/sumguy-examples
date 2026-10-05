import os

import psycopg

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://dev:dev@db:5432/app")


def connect():
    return psycopg.connect(DATABASE_URL, autocommit=True)


def init(conn):
    conn.execute("CREATE TABLE IF NOT EXISTS notes (id serial PRIMARY KEY, body text NOT NULL)")


def add_note(conn, body):
    return conn.execute("INSERT INTO notes (body) VALUES (%s) RETURNING id", (body,)).fetchone()[0]


def list_notes(conn):
    return [r[0] for r in conn.execute("SELECT body FROM notes ORDER BY id")]


if __name__ == "__main__":
    with connect() as conn:
        init(conn)
        add_note(conn, "hello from the devcontainer")
        print(list_notes(conn))
