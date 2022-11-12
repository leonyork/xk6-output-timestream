import { sleep } from "k6";
import http from "k6/http";

export default function () {
  http.get("https://test.k6.io");
  sleep(0.5);
}
