import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host="localhost",
        credentials=pika.PlainCredentials("appuser", "change-me"),
    )
)
channel = connection.channel()
channel.queue_declare(queue="receipts", durable=True)

channel.basic_publish(
    exchange="",
    routing_key="receipts",
    body=b'{"order_id": 4821, "email": "customer@example.com"}',
    properties=pika.BasicProperties(delivery_mode=2),  # persistent
)
connection.close()
