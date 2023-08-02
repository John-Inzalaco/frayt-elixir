import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL;
const baseApiUrl = __ENV.BASE_API_URL;

const checkResponse = (response) => check(response, {
  'success': (r) => r.status >= 200 && r.status <= 299,
});

let driverToken;

const loginAsDriver = () => {
  const headers = {
    'Content-Type': 'application/json'
  };
  const driverLoginParams = {
    email: __ENV.DRIVER_EMAIL,
    password: __ENV.DRIVER_PASSWORD
  };
  let response = http.post(`${baseUrl}/sessions/drivers`, JSON.stringify(driverLoginParams), { headers });
  checkResponse(response);
  var token = JSON.parse(response.body).response.token;
  return token;
};

const loginAsApiAccount = () => {
  const headers = {
    'Content-Type': 'application/json'
  };
  var api_account = {
    clientId: __ENV.CLIENT_ID,
    secret: __ENV.CLIENT_SECRET
  }
  let response = http.post(`${baseApiUrl}/oauth/token`, JSON.stringify(api_account), { headers });
  var token = JSON.parse(response.body).response.token;
  console.log(`Token: ${token}`);
  sleep(1)
  return token;
};

export const options = {
  scenarios: {
    // drivers: {
    //   executor: 'constant-arrival-rate',
    //   rate: 10,
    //   timeUnit: '1s',
    //   duration: '6m',
    //   preAllocatedVUs: 20,
    //   maxVUs: 40,
    //   exec: 'driverUpdateLocation'
    // },
    api_callers: {
      executor: 'shared-iterations',
      vus: 6,
      iterations: 50,
      maxDuration: '10m',
      exec: 'createMatchFromApi'
    }
  }
}

export const driverUpdateLocation = () => {
  if (!driverToken) {
    driverToken = loginAsDriver();
  }
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${driverToken}`
  };
  const locationParams = {
    longitude: -84.5360534,
    latitude: 39.21988
  }
  let response = http.post(`${baseUrl}/driver/locations`, JSON.stringify(locationParams), { headers });
  checkResponse(response);
};

export const createMatchFromApi = () => {
  const token = loginAsApiAccount();
  var createEstimateParams = {
    origin_address: '641 Evangeline Rd, Cincinnati OH 45240',
    destination_address: '708 Walnut St, Cincinnati OH 45202',
    vehicle_class: 1,
    service_level: 1,
    weight: 23
  }
  const headers = {
    'Content-Type': 'application/json'
  };

  let response = http.post(`${baseApiUrl}/estimates`, JSON.stringify(createEstimateParams), { headers });
  checkResponse(response);
  sleep(1);

  var matchId = JSON.parse(response.body).response.id;

  var createMatchParams = {
    estimate: matchId,
    dimensionsLength: 48,
    dimensionsWidth: 40,
    dimensionsHeight: 40,
    pieces: 1,
    weight: 100,
    loadUnload: false
  }
  headers["Authorization"] = `Bearer ${token}`;

  response = http.post(`${baseApiUrl}/matches`, JSON.stringify(createMatchParams), { headers });
  checkResponse(response);
  sleep(1);

}

export default createMatchFromApi;