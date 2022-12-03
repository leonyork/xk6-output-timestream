import { sleep } from "k6";
import http from "k6/http";

export const options = {
  discardResponseBodies: true,
  systemTags: ["status", "method", "url", "error", "error_code", "vu", "iter"],
  tags: {
    test_type: __ENV.TEST_ID || "integration-test",
    instance_id: "1",
  },
};

export default function () {
  http.get(__ENV.TARGET_URL || "https://test.k6.io");
  sleep(0.5);
}
