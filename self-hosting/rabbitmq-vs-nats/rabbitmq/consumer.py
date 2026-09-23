import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host="localhost",
        credentials=pika.PlainCredentials("appuser", "change-me"),
    )
)
channel = connection.channel()
channel.queue_declare(queue="receipts", durable=True)
channel.basic_qos(prefetch_count=1)

def callback(ch, method, properties, body):
    print(f"sending receipt: {body}")
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue="receipts", on_message_callback=callback)
channel.start_consuming()
