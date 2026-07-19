import http from "k6/http";
import { check, sleep } from "k6";

// Usage:
//   k6 run load-test/k6-script.js -e TARGET_URL=http://$(terraform output -raw alb_dns_name)
const TARGET_URL = __ENV.TARGET_URL;

export const options = {
  stages: [
    { duration: "1m", target: 50 }, // ramp up: drives ALBRequestCountPerTarget past its target(50), triggering scale-out
    { duration: "3m", target: 50 }, // hold, long enough to watch the fleet scale out and new instances go InService
    { duration: "1m", target: 0 },  // ramp down, then watch it scale back in
  ],
};

export default function () {
  if (!TARGET_URL) {
    throw new Error("Set -e TARGET_URL=http://<alb_dns_name>");
  }

  const res = http.get(`${TARGET_URL}/`);
  check(res, { "status is 200": (r) => r.status === 200 });
  sleep(1);
}
