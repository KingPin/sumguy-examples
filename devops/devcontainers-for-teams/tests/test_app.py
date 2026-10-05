import app


def test_round_trip():
    with app.connect() as conn:
        app.init(conn)
        conn.execute("TRUNCATE notes")
        app.add_note(conn, "first")
        app.add_note(conn, "second")
        assert app.list_notes(conn) == ["first", "second"]
