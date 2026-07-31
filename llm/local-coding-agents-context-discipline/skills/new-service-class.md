# Skill: adding a new service class

An example of a **small, focused skill file**. Load only the one relevant to the
current subtask instead of shipping every convention you own to every agent on
every call. Three of these beat one 2,000-line instruction dump, because the
agent reads the one that applies.

## When to use

The task needs a new long-lived object that owns external state: a database
handle, an HTTP client with retry policy, a message queue consumer. Plain
functions are the default everywhere else (see AGENTS.md).

## The pattern

```python title="services/orders_service.py"
class OrdersService:
    """Owns the DB handle. Business logic stays in pure functions."""

    def __init__(self, conn: Connection) -> None:
        self._conn = conn

    def fetch(self, order_id: str) -> Order | None:
        row = self._conn.execute(
            "SELECT * FROM orders WHERE id = ?", (order_id,)
        ).fetchone()
        return Order(**dict(row)) if row else None

    def save(self, order: Order) -> None:
        self._conn.execute(
            "UPDATE orders SET total = ? WHERE id = ?", (order.total, order.id)
        )
```

## Rules

1. **Constructor takes the dependency, never builds it.** `__init__` receives an
   open connection. It does not call `connect()`. That is what makes it testable
   without a live database. The caller is responsible for setting
   `conn.row_factory = sqlite3.Row` before handing it over: a bare
   `sqlite3.Connection` yields plain tuples, and `dict(row)` then raises
   `ValueError`.
2. **No business logic in the class.** `apply_discount` is a pure function that
   takes an `Order` and returns one. The service fetches and saves; it does not
   calculate.
3. **Return `None` for "not found", raise for "broken".** A missing row is a
   normal outcome. A malformed row is not.
4. **One service per table or external system.** When a service grows a second
   unrelated responsibility, split it.

## Checklist before you call it done

- [ ] Type hints on every method including the return
- [ ] Dependency injected, not constructed internally
- [ ] No calculation logic in any method body
- [ ] A test that constructs it with an in-memory connection
