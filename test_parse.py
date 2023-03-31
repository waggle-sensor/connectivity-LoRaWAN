import unittest
from parse import parse_message_payload


class TestParse(unittest.TestCase):

    def test_parse_message_payload(self):
        payload_data = '{"deduplicationId":"862f4204-6d00-4555-beb8-6757fd508f38","time":"2023-03-30T21:39:20.506230989+00:00","deviceInfo":{"tenantId":"52f14cd4-c6f1-4fbd-8f87-4025e1d49242","tenantName":"ChirpStack","applicationId":"5b06bc92-0510-47c1-8f24-a807f48b94a9","applicationName":"wes-application","deviceProfileId":"d0c4ec0e-51cc-4654-ab0d-b1b614dd95c5","deviceProfileName":"Wio-E5 Dev Kit for Long Range Application","deviceName":"Lozano LoRA E5 Mini","devEui":"5a3f18b97a97247d"},"devAddr":"00362614","adr":true,"fCnt":301,"fPort":8,"data":"bWhp","object":{"Text":"mhi"},"rxInfo":[{"gatewayId":"d2ce19fffec9d449","uplinkId":14823,"rssi":-19,"snr":12.2,"channel":4,"rfChain":1,"location":{},"context":"NZLjjA==","metadata":{"region_common_name":"US915","region_name":"us915"}}],"txInfo":{"frequency":904700000,"modulation":{"lora":{"bandwidth":125000,"spreadingFactor":10,"codeRate":"CR_4_5"}}}}'
        r = parse_message_payload(payload_data)
        self.assertEqual(r["deviceInfo"]["devEui"], "5a3f18b97a97247d")


if __name__ == "__main__":
    unittest.main()
