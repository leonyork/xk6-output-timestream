import { sleep } from "k6";
import http from "k6/http";

export const options = {
  discardResponseBodies: true,
  systemTags: ["status", "method", "url", "error", "error_code", "vu", "iter"],
  tags: {
    test_type: "integration-test",
  },
};

export default function () {
  http.get("https://test.k6.io");
  sleep(0.5);
}
