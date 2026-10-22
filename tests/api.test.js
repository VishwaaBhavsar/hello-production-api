const request = require("supertest");
const app = require("../app");

describe("API health endpoint", () => {
  test("GET /health returns 200 and status ok", async () => {
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ok" });
  });
});

test("GET /health returns the wrong status (demo)", async () => {
  const response = await request(app).get("/health");

  expect(response.status).toBe(201);
});
