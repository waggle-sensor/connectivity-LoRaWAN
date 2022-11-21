import argparse
import base64
import json
import logging
import os

import paho.mqtt.client as mqtt
from waggle.plugin import Plugin

# TODO: look into this, does this mean we only publish locally ?
os.environ["PYWAGGLE_LOG_DIR"] = "/var/log/pywaggle"

# TODO: how do we want to define this protocol?  is this final??
types = {
    "t": "env.temperature",
    "h": "env.humidity",
    "p": "env.pressure",
    "c": "env.coverage.cloud",
    "1": "env.count.bird",
    "2": "env.count.person",
    "3": "env.count.airplane",
    "4": "env.coount.car",
    "5": "env.raingauge.totalacc",
    "6": "env.raingauge.eventacc",
    "7": "env.raingauge.rint",
    "s": "env.smoke.tileprobs",
    "d": "env.detection.sound",
    "m": "message",
}


def mess(client, userdata, message):
    data = (
        "Message received: " + message.payload.decode("utf-8") + " with topic " + str(message.topic)
    )
    logging.info(data)
    tmp_dict = json.loads(message.payload.decode("utf-8"))
    try:
        bytes_b64 = tmp_dict["data"].encode("utf-8")
    except:
        logging.error("Message did not contain data.")
        return
    bytes = base64.b64decode(bytes_b64)
    val = bytes.decode("utf-8")
    type = val[0]

    with Plugin() as plugin:
        try:
            key = types[type]
        except KeyError:
            logging.error("invalid type")
            return
        if type == "m":
            msg = val[1:]
        else:
            try:
                msg = int(val[1:])
            except:
                logging.error("value should be integer:", val)
                msg = val[1:]

        try:
            # plugin.publish(key,msg,meta={"devName":tmp_dict["deviceName"], "devEUI":tmp_dict["devEUI"], "deviceProfile":tmp_dict["deviceProfileName"]})
            # plugin.publish(
            #     key, msg, meta={"devName": tmp_dict["deviceName"], "devEUI": tmp_dict["devEUI"]}
            # )
            # TODO: get the dry-run in here to conditional publish or not
            logging.info(
                "publish: %s, %s, meta={'devName': %s, 'devEUI': %s}",
                key,
                msg,
                tmp_dict["deviceName"],
                tmp_dict["devEUI"],
            )
        except:
            logging.error("something went wrong")
    logging.info(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--debug", action="store_true", help="enable debug logs")
    parser.add_argument(
        "--dry",
        action="store_true",
        default=False,
        help="enable dry-run mode where no messages will be broadcast to Beehive",
    )
    parser.add_argument(
        "--mqtt-server-ip",
        default=os.getenv("MQTT_SERVER_HOST", "127.0.0.1"),
        help="MQTT server IP address",
    )
    parser.add_argument(
        "--mqtt-server-port",
        default=os.getenv("MQTT_SERVER_PORT", "1883"),
        help="MQTT server port",
        type=int,
    )
    parser.add_argument(
        "--mqtt-subscribe-topic",
        default=os.getenv("MQTT_SUBSCRIBE_TOPIC", "application/2/device/#"),
        help="MQTT subscribe topic",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s %(message)s",
        datefmt="%Y/%m/%d %H:%M:%S",
    )

    client = mqtt.Client("lorawan-test")
    logging.info(f"connecting [{args.mqtt_server_ip}:{args.mqtt_server_port}]...")
    client.connect(host=args.mqtt_server_ip, port=args.mqtt_server_port, bind_address="0.0.0.0")
    logging.info(f"subscribing [{args.mqtt_subscribe_topic}]...")
    client.subscribe(args.mqtt_subscribe_topic)
    logging.info("waiting for callback...")
    client.on_message = mess
    client.loop_forever()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
