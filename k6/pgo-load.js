import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  stages: [
    { duration: '10s', target: 5 },
    { duration: '20s', target: 10 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  // Test 1: Get all products
  let res = http.get(`${BASE_URL}/products`);
  check(res, { 'status is 200': (r) => r.status === 200 });

  // Test 2: Create a product
  const payload = JSON.stringify({
    name: `Product-${Math.random()}`,
    price: Math.floor(Math.random() * 1000)
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  res = http.post(`${BASE_URL}/products`, payload, params);
  check(res, { 'status is 200': (r) => r.status === 200 });

  sleep(1);
}
