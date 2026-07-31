# AGENTS.md

Instructions for coding agents working in this repo. Every rule below is stated
as "do Y" with a concrete example, not "don't do X". A prohibition with nothing
to aim at burns tokens without telling the model what correct looks like.

## Code Style

We write functional-first Python. Prefer small pure functions over classes.
Example of the pattern we want:

```python title="orders.py"
def apply_discount(order: Order, pct: float) -> Order:
    """Return a new Order with pct% knocked off the total. Pure, no mutation."""
    return replace(order, total=order.total * (1 - pct))
```

Not this:

```python
class OrderProcessor:
    def __init__(self, order):
        self.order = order
    def apply_discount(self, pct):
        self.order.total *= (1 - pct)  # mutates in place, no
```

Match the first pattern for new business logic. Classes are fine for stateful
things like DB connections, not for a discount calculation.

## Type Hints

Annotate every function signature, including the return type. Use the builtin
generics, not the `typing` aliases:

```python
def load_orders(path: Path) -> list[Order]:      # yes
def load_orders(path) -> List[Order]:            # no, and path is unannotated
```

## Error Handling

Catch the specific exception you can actually handle, and let everything else
propagate. A bare `except Exception` that logs and continues turns a loud bug
into a silent one:

```python
try:
    cfg = json.loads(path.read_text())
except FileNotFoundError:
    cfg = DEFAULT_CONFIG          # a real, handled case
except json.JSONDecodeError as e:
    raise ConfigError(f"{path} is not valid JSON") from e   # add context, re-raise
```

## Tests

One behaviour per test, named for the behaviour. A test must fail if the logic
breaks, which means asserting on the outcome and not on the implementation:

```python
def test_discount_reduces_total():
    order = Order(total=100.0)
    assert apply_discount(order, 0.10).total == 90.0

def test_discount_does_not_mutate_input():
    order = Order(total=100.0)
    apply_discount(order, 0.10)
    assert order.total == 100.0
```

## Scope

Change only what the current task requires. If you spot unrelated problems,
list them at the end of your response instead of fixing them. Drive-by
refactors make the diff unreviewable, and an unreviewable diff gets committed
unread.

## Style Targets

When you need more context on our conventions than this file gives you, read a
real file rather than asking for more rules. `orders.py` is the reference for
business logic, `tests/test_orders.py` for test structure.
