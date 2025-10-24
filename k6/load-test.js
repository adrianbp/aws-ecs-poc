import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080/api/info';
const JVM_OPTS = __ENV.JAVA_TOOL_OPTIONS || '-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC';

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '2m', target: 25 },
    { duration: '1m', target: 25 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
  summaryTrendStats: ['avg', 'p(95)', 'p(99)', 'min', 'max'],
};

const latencyTrend = new Trend('http_req_latency_ms');

export default function () {
  const response = http.get(BASE_URL, {
    headers: {
      'X-Java-Tool-Options': JVM_OPTS,
    },
  });

  check(response, {
    'status is 200': (res) => res.status === 200,
  });

  latencyTrend.add(response.timings.duration);
  sleep(1);
}
